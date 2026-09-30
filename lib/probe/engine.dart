import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/catalog.dart';
import '../settings/app_settings.dart';
import 'cancellation.dart';
import 'models.dart';
import 'nics.dart';
import 'transport.dart';

class _Attempt {
  _Attempt(this.token, this.future);
  final CancellationToken token;
  final Future<Hit> future;
}

class ProbeEngine extends ChangeNotifier {
  ProbeEngine({
    ProbeTransport? transport,
    ProbeClock? clock,
    Future<List<NicChoice>> Function()? nicLoader,
  }) : _transport = transport ?? SocketProbeTransport(),
       clock = clock ?? ProbeClock(),
       _nicLoader = nicLoader ?? listNics;
  final ProbeTransport _transport;
  final ProbeClock clock;
  final Future<List<NicChoice>> Function() _nicLoader;
  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;
  SharedPreferences? _prefs;
  List<ProbeTarget> _targets = [];
  List<ProbeTarget> get targets => List.unmodifiable(_targets);
  final Map<ProbeKey, Hit> _results = {};
  final Map<ProbeKey, List<ProbeSample>> _history = {};
  final Map<ProbeKey, SessionCounter> _counts = {};
  final Map<ProbeKey, _Attempt> _attempts = {};
  final List<SessionEvent> _events = [];
  Map<ProbeKey, Hit> get results => Map.unmodifiable(_results);
  List<SessionEvent> get events => List.unmodifiable(_events.reversed);
  SessionBaseline? baseline;
  List<NicChoice> nics = const [NicChoice.any];
  bool _disposed = false,
      _started = false,
      _loops = false,
      _foreground = true,
      _refreshingNics = false;
  int _epoch = 0, contextNumber = 1;
  CancellationToken _wake = CancellationToken();
  Timer? _nicTimer;
  Future<void> _saveTail = Future.value();
  String? persistenceError;
  late DateTime sessionStarted;
  static const historyLimit = 120, eventLimit = 200;

  bool get isRunning => settings.running;
  bool get foreground => _foreground;
  bool get adapterAvailable =>
      settings.nicId == 'any' || nics.any((n) => n.id == settings.nicId);
  NicChoice get nic => nics.firstWhere(
    (n) => n.id == settings.nicId,
    orElse: () =>
        const NicChoice(id: 'missing', label: 'Selected adapter unavailable'),
  );
  String get contextLabel => 'Context $contextNumber · ${nic.label}';
  String get runLabel => !_foreground
      ? 'Paused in background'
      : !adapterAvailable
      ? 'Adapter unavailable'
      : settings.running
      ? 'Monitoring live'
      : 'Monitoring paused';
  DateTime? get latestAt => _results.values
      .map((h) => h.at)
      .whereType<DateTime>()
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
  Hit hitFor(ProbeKey key) => _results[key] ?? Hit.idle;
  List<ProbeSample> historyFor(ProbeKey key) =>
      List.unmodifiable(_history[key] ?? []);
  ItemMetrics metricsFor(ProbeKey key) =>
      ItemMetrics.fromSamples(historyFor(key));
  SessionCounter counterFor(ProbeKey key) => _counts[key] ?? SessionCounter();
  bool enabled(ProbeKey key) => !settings.disabledTargets.contains(key.value);
  bool favorite(ProbeKey key) => settings.favorites.contains(key.value);
  ProbeExecution executionFor(ProbeKey key) => _attempts.containsKey(key)
      ? ProbeExecution.checking
      : !settings.running || !_foreground
      ? ProbeExecution.paused
      : ProbeExecution.idle;

  Future<void> start({bool loops = true, bool loadNics = true}) async {
    if (_started || _disposed) return;
    _started = true;
    sessionStarted = clock.now();
    try {
      _prefs = await SharedPreferences.getInstance();
      _settings = AppSettings.fromPrefs(_prefs!);
    } catch (_) {
      persistenceError =
          'Settings could not be loaded. Using defaults for this session.';
    }
    if (_disposed) return;
    _rebuildTargets();
    if (loadNics) await refreshNics(initial: true);
    if (_disposed) return;
    _notify();
    _loops = loops;
    if (loops) {
      for (var lane = 0; lane < 3; lane++) {
        unawaited(_loop(lane));
      }
      if (loadNics) {
        _nicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
          if (_foreground) unawaited(refreshNics());
        });
      }
    }
  }

  void _rebuildTargets() {
    final next = <ProbeTarget>[];
    final domains = <String, String>{};
    if (settings.useDefaultDomains) {
      for (final domain in kDefaultDomains) {
        domains[parseWebsite(domain.host).toString()] =
            domain.label ?? domain.host;
      }
    }
    for (final value in settings.extraDomains) {
      final uri = parseWebsite(value);
      domains.putIfAbsent(uri.toString(), () => uri.host);
    }
    for (final entry in domains.entries) {
      final uri = Uri.parse(entry.key);
      next.add(
        ProbeTarget(
          key: ProbeKey(ItemCategory.domain, uri.toString(), port: uri.port),
          title: entry.value,
          address: uri.host,
          uri: uri,
          port: uri.port,
          description:
              'Checks HTTPS reachability with certificate validation. An HTTP response means the server was reached; it does not guarantee every part of the website works.',
        ),
      );
    }
    for (final resolver in kDefaultResolvers) {
      next.add(
        ProbeTarget(
          key: ProbeKey(
            ItemCategory.dns,
            resolver.address,
            port: 53,
            query: 'google.com',
          ),
          title: resolver.name,
          address: resolver.address,
          port: 53,
          regional: resolver.isIranian,
          description:
              'Measures a DNS response to google.com. A responding server can still return a lookup error.${resolver.isIranian ? ' This regional service may be unavailable outside its intended network.' : ''}',
        ),
      );
      next.add(
        ProbeTarget(
          key: ProbeKey(
            ItemCategory.hunt,
            resolver.address,
            port: 53,
            query: settings.huntName,
          ),
          title: '${resolver.name} comparison',
          address: resolver.address,
          port: 53,
          regional: resolver.isIranian,
          description:
              'Asks this resolver for ${settings.huntName}. Different answers can result from caching, routing or a VPN; differences alone do not prove tampering.',
        ),
      );
    }
    next.addAll([
      const ProbeTarget(
        key: ProbeKey(ItemCategory.proto, 'v4'),
        title: 'IPv4 connection',
        address: '1.1.1.1',
        description:
            'Opens a TCP connection on port 443. This is not an ICMP ping.',
      ),
      const ProbeTarget(
        key: ProbeKey(ItemCategory.proto, 'v6'),
        title: 'IPv6 connection',
        address: '2606:4700:4700::1111',
        description:
            'Tests an IPv6 TCP connection. An IPv4-only network can still have working internet.',
      ),
      ProbeTarget(
        key: const ProbeKey(ItemCategory.proto, 'https'),
        title: 'Secure web connection',
        address: 'cloudflare.com',
        uri: Uri.parse('https://cloudflare.com/'),
        description:
            'Verifies an HTTPS connection to cloudflare.com, including its certificate.',
      ),
      const ProbeTarget(
        key: ProbeKey(ItemCategory.proto, 'sni', variant: 'youtube.com'),
        title: 'SNI handshake',
        address: '1.1.1.1',
        sni: 'youtube.com',
        handshakeOnly: true,
        description:
            'Sends the youtube.com TLS server name to 1.1.1.1. Certificate identity is deliberately not verified. A failure is not proof of filtering.',
      ),
    ]);
    for (final edge in kDefaultEdges) {
      next.add(
        ProbeTarget(
          key: ProbeKey(
            ItemCategory.edge,
            edge.ip,
            port: 443,
            variant: edge.sni,
          ),
          title: 'Edge ${edge.short}',
          address: edge.ip,
          sni: edge.sni,
          handshakeOnly: true,
          description:
              'Tests a TLS handshake to this edge IP using ${edge.sni}. Certificate identity is not verified; this is not a full HTTPS check.',
        ),
      );
    }
    _targets = next;
    final keys = next.map((t) => t.key).toSet();
    _results.removeWhere((k, _) => !keys.contains(k));
    _history.removeWhere((k, _) => !keys.contains(k));
    _counts.removeWhere((k, _) => !keys.contains(k));
  }

  String _measurementFingerprint(AppSettings s) => [
    s.nicId,
    s.huntName,
    s.useDefaultDomains,
    s.extraDomains.join(','),
    s.disabledTargets.join(','),
    s.httpTimeoutMs,
    s.dnsTimeoutMs,
    s.itemDelayMs,
    s.dnsDelayMs,
  ].join('|');

  Future<void> apply(AppSettings next) async {
    if (_disposed) return;
    // Validate before changing the running engine, including non-UI callers.
    parseDnsName(next.huntName);
    for (final value in next.extraDomains) {
      parseWebsite(value);
    }
    final contextChanged =
        _measurementFingerprint(settings) != _measurementFingerprint(next);
    final runChanged = settings.running != next.running;
    _settings = next;
    if (contextChanged) {
      _newContext('Monitoring configuration changed');
    } else if (runChanged) {
      _cancelAttempts();
      _event(null, next.running ? 'Monitoring resumed' : 'Monitoring paused');
    }
    _rebuildTargets();
    _signal();
    _notify();
    if (_prefs != null) {
      _saveTail = _saveTail.then((_) => next.save(_prefs!)).catchError((
        Object _,
      ) {
        persistenceError =
            'Settings could not be saved. Changes apply to this session.';
        _notify();
      });
      await _saveTail;
    }
  }

  Future<void> setRunning(bool value) =>
      apply(settings.copyWith(running: value));
  Future<void> setNic(String value) => apply(settings.copyWith(nicId: value));
  Future<void> setAlwaysOnTop(bool value) =>
      apply(settings.copyWith(alwaysOnTop: value));
  Future<void> setCompact(bool value) =>
      apply(settings.copyWith(compactMode: value));
  Future<void> toggleFavorite(ProbeKey key) async {
    final values = settings.favorites.toSet();
    if (!values.remove(key.value)) values.add(key.value);
    await apply(settings.copyWith(favorites: values.toList()));
  }

  Future<void> setEnabled(ProbeKey key, bool value) async {
    final values = settings.disabledTargets.toSet();
    if (value) {
      values.remove(key.value);
    } else {
      values.add(key.value);
    }
    await apply(settings.copyWith(disabledTargets: values.toList()));
  }

  void setForeground(bool value) {
    if (_disposed || value == _foreground) return;
    _foreground = value;
    _cancelAttempts();
    if (value) {
      _newContext('App resumed; a new measurement context started');
      unawaited(refreshNics());
    }
    _signal();
    _notify();
  }

  Future<void> refreshNics({bool initial = false}) async {
    if (_refreshingNics || _disposed) return;
    _refreshingNics = true;
    try {
      final next = List<NicChoice>.of(
        await _nicLoader().timeout(const Duration(seconds: 2)),
      )..sort((a, b) => a.id.compareTo(b.id));
      if (_disposed) return;
      final changed =
          nics.map((n) => n.id).join('|') != next.map((n) => n.id).join('|');
      nics = next;
      if (changed && !initial) {
        _newContext(
          adapterAvailable
              ? 'Network adapters changed'
              : 'Selected adapter is no longer available',
        );
      }
      _signal();
      _notify();
    } catch (_) {
      /* Retain the last adapter inventory; never silently rebind. */
    } finally {
      _refreshingNics = false;
    }
  }

  Future<Hit> runNow(ProbeTarget target) {
    if (_disposed || !_foreground) return Future.value(Hit.cancelled);
    if (!adapterAvailable) {
      return Future.value(
        const Hit(
          status: HitStatus.unsupported,
          detail: 'Selected adapter unavailable',
        ),
      );
    }
    if (!_targets.any((t) => t.key == target.key)) {
      return Future.value(Hit.cancelled);
    }
    final existing = _attempts[target.key];
    if (existing != null) return existing.future;
    final token = CancellationToken(), epoch = _epoch;
    final completer = Completer<Hit>();
    _attempts[target.key] = _Attempt(token, completer.future);
    _notify();
    Future<void> perform() async {
      Hit result;
      try {
        final limit =
            target.category == ItemCategory.dns ||
                target.category == ItemCategory.hunt
            ? settings.dnsTimeout
            : settings.httpTimeout;
        result = await token
            .bind(
              _transport.probe(target, settings, token, parseBind(nic.address)),
            )
            .timeout(limit + const Duration(milliseconds: 100));
      } on ProbeCancelled {
        result = Hit.cancelled;
      } on TimeoutException {
        result = Hit(
          status: HitStatus.timeout,
          detail: 'Timed out',
          at: clock.now(),
        );
      } catch (_) {
        result = Hit(
          status: HitStatus.fail,
          detail: 'Check failed',
          at: clock.now(),
        );
      }
      token.cancel();
      if (!_disposed &&
          epoch == _epoch &&
          _attempts[target.key]?.token == token) {
        _attempts.remove(target.key);
        if (result.status != HitStatus.cancelled) _record(target.key, result);
        _notify();
      }
      if (!completer.isCompleted) {
        completer.complete(
          epoch == _epoch && !_disposed ? result : Hit.cancelled,
        );
      }
    }

    unawaited(perform());
    return completer.future;
  }

  void _record(ProbeKey key, Hit result) {
    final previous = _results[key];
    final stamped = Hit(
      status: result.status,
      ms: result.ms,
      detail: result.detail,
      phase: result.phase,
      warning: result.warning,
      at: clock.now(),
    );
    _results[key] = stamped;
    if (!stamped.completed) return;
    final history = _history.putIfAbsent(key, () => []);
    history.add(ProbeSample.fromHit(stamped));
    if (history.length > historyLimit) {
      history.removeRange(0, history.length - historyLimit);
    }
    _counts.putIfAbsent(key, SessionCounter.new).add(stamped);
    if (previous?.completed == true && previous!.status != stamped.status) {
      _event(key, stamped.label);
    }
  }

  void captureBaseline() {
    baseline = SessionBaseline(
      at: clock.now(),
      context: contextLabel,
      results: _results,
    );
    _event(null, 'Comparison baseline captured');
    _notify();
  }

  void clearBaseline() {
    baseline = null;
    _notify();
  }

  void resetStats(ProbeKey key) {
    _attempts.remove(key)?.token.cancel();
    _results.remove(key);
    _history.remove(key);
    _counts.remove(key);
    _notify();
  }

  void resetAllStats() {
    _newContext('Session observations cleared');
    baseline = null;
    _events.clear();
    _signal();
    _notify();
  }

  void _newContext(String reason) {
    _cancelAttempts();
    contextNumber++;
    _results.clear();
    _history.clear();
    _counts.clear();
    _event(null, reason);
  }

  void _cancelAttempts() {
    _epoch++;
    for (final attempt in _attempts.values) {
      attempt.token.cancel();
    }
    _attempts.clear();
  }

  void _event(ProbeKey? key, String message) {
    _events.add(SessionEvent(clock.now(), key, message));
    if (_events.length > eventLimit) {
      _events.removeRange(0, _events.length - eventLimit);
    }
  }

  void _signal() {
    _wake.cancel();
    _wake = CancellationToken();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loop(int lane) async {
    var index = 0;
    while (!_disposed && _loops) {
      final available = _targets
          .where(
            (t) =>
                enabled(t.key) &&
                (lane == 0
                    ? t.category == ItemCategory.domain
                    : lane == 1
                    ? t.category == ItemCategory.dns
                    : t.category != ItemCategory.domain &&
                          t.category != ItemCategory.dns),
          )
          .toList();
      if (!settings.running ||
          !_foreground ||
          !adapterAvailable ||
          available.isEmpty) {
        await clock.wait(const Duration(days: 1), _wake);
        continue;
      }
      final target = available[index % available.length];
      await runNow(target);
      if (_disposed) return;
      index++;
      // A zero configured gap still yields to the event loop and avoids a hot loop.
      final delay = lane == 1 || target.category == ItemCategory.hunt
          ? settings.dnsDelay
          : settings.itemDelay;
      await clock.wait(
        delay == Duration.zero ? const Duration(milliseconds: 16) : delay,
        _wake,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loops = false;
    _nicTimer?.cancel();
    _cancelAttempts();
    _wake.cancel();
    super.dispose();
  }
}
