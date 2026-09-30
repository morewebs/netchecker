import 'dart:io';
import 'dart:math' as math;

enum HitStatus { idle, checking, ok, timeout, fail, unsupported, cancelled }

enum ItemCategory { domain, dns, edge, proto, hunt }

enum ProbeExecution { idle, checking, paused }

bool isObservation(HitStatus s) =>
    s == HitStatus.ok || s == HitStatus.fail || s == HitStatus.timeout;

class ProbeKey {
  const ProbeKey(
    this.kind,
    this.endpoint, {
    this.port = 0,
    this.query = '',
    this.variant = '',
  });
  final ItemCategory kind;
  final String endpoint, query, variant;
  final int port;
  String get value => [
    kind.name,
    endpoint,
    '$port',
    query,
    variant,
  ].map(Uri.encodeComponent).join('|');
  @override
  bool operator ==(Object other) => other is ProbeKey && value == other.value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

class ProbeTarget {
  const ProbeTarget({
    required this.key,
    required this.title,
    required this.address,
    required this.description,
    this.uri,
    this.sni,
    this.port = 443,
    this.regional = false,
    this.handshakeOnly = false,
  });
  final ProbeKey key;
  final String title, address, description;
  final Uri? uri;
  final String? sni;
  final int port;
  final bool regional, handshakeOnly;
  ItemCategory get category => key.kind;
  String get categoryLabel => switch (category) {
    ItemCategory.domain => 'Website',
    ItemCategory.dns => 'DNS response',
    ItemCategory.hunt => 'DNS comparison',
    ItemCategory.edge => 'Edge handshake',
    ItemCategory.proto => 'Connection test',
  };
}

class PhaseBreakdown {
  const PhaseBreakdown({
    this.dnsMs,
    this.resolvedIps,
    this.tcpMs,
    this.tlsMs,
    this.httpMs,
    this.httpStatusCode,
    this.anomaly,
    this.dnsResponseCode,
    this.certificateVerified,
    this.method,
  });
  final int? dnsMs, tcpMs, tlsMs, httpMs, httpStatusCode, dnsResponseCode;
  final List<String>? resolvedIps;
  final String? anomaly, method;
  final bool? certificateVerified;
  int get totalMs => (dnsMs ?? 0) + (tcpMs ?? 0) + (tlsMs ?? 0) + (httpMs ?? 0);
}

class Hit {
  const Hit({
    this.status = HitStatus.idle,
    this.ms,
    this.detail,
    this.at,
    this.phase,
    this.warning,
  });
  final HitStatus status;
  final int? ms;
  final String? detail, warning;
  final DateTime? at;
  final PhaseBreakdown? phase;
  static const idle = Hit();
  static const checking = Hit(status: HitStatus.checking);
  static const cancelled = Hit(status: HitStatus.cancelled);
  bool get completed => isObservation(status);
  String get readout => switch (status) {
    HitStatus.idle => 'No result yet',
    HitStatus.checking => 'Checking',
    HitStatus.ok => ms == null ? 'Reachable' : '${ms}ms',
    HitStatus.timeout => 'Timed out',
    HitStatus.fail => detail ?? 'Failed',
    HitStatus.unsupported => 'Unavailable',
    HitStatus.cancelled => 'Cancelled',
  };
  String get label => switch (status) {
    HitStatus.ok => warning == null ? 'Reachable' : 'Responded',
    HitStatus.fail => detail ?? 'Check failed',
    _ => readout,
  };
}

class ProbeSample {
  const ProbeSample({
    required this.timestamp,
    required this.status,
    this.ms,
    this.detail,
    this.phase,
    this.warning,
  });
  final DateTime timestamp;
  final HitStatus status;
  final int? ms;
  final String? detail, warning;
  final PhaseBreakdown? phase;
  factory ProbeSample.fromHit(Hit hit, {DateTime? at, PhaseBreakdown? phase}) =>
      ProbeSample(
        timestamp: at ?? hit.at ?? DateTime.now(),
        status: hit.status,
        ms: hit.ms,
        detail: hit.detail,
        phase: phase ?? hit.phase,
        warning: hit.warning,
      );
}

class ItemMetrics {
  const ItemMetrics({
    this.avgMs = 0,
    this.minMs = 0,
    this.maxMs = 0,
    this.jitterMs = 0,
    this.stdDevMs = 0,
    this.uptimePercent = 0,
    this.totalChecks = 0,
    this.okCount = 0,
    this.failCount = 0,
    this.filterStatus = 'No result yet',
    this.isClean = true,
  });
  final double avgMs, jitterMs, stdDevMs, uptimePercent;
  final int minMs, maxMs, totalChecks, okCount, failCount;
  final String filterStatus;
  final bool isClean;
  double get lossPercent =>
      totalChecks == 0 ? 0 : failCount / totalChecks * 100;
  static const empty = ItemMetrics();
  factory ItemMetrics.fromSamples(
    List<ProbeSample> samples, {
    Hit? currentHit,
  }) {
    final complete = samples.where((s) => isObservation(s.status)).toList();
    if (complete.isEmpty && currentHit?.completed == true) {
      complete.add(ProbeSample.fromHit(currentHit!));
    }
    if (complete.isEmpty) return empty;
    final oks = complete.where((s) => s.status == HitStatus.ok).toList();
    final times = oks.map((s) => s.ms).whereType<int>().toList();
    final avg = times.isEmpty
        ? 0.0
        : times.reduce((a, b) => a + b) / times.length;
    double variance = 0, jitter = 0;
    for (var i = 0; i < times.length; i++) {
      variance += math.pow(times[i] - avg, 2);
      if (i > 0) jitter += (times[i] - times[i - 1]).abs();
    }
    final last = complete.last;
    return ItemMetrics(
      avgMs: avg,
      minMs: times.isEmpty ? 0 : times.reduce(math.min),
      maxMs: times.isEmpty ? 0 : times.reduce(math.max),
      jitterMs: times.length < 2 ? 0 : jitter / (times.length - 1),
      stdDevMs: times.isEmpty ? 0 : math.sqrt(variance / times.length),
      uptimePercent: oks.length / complete.length * 100,
      totalChecks: complete.length,
      okCount: oks.length,
      failCount: complete.length - oks.length,
      filterStatus:
          last.detail ??
          (last.status == HitStatus.ok ? 'Reachable' : 'Check failed'),
      isClean: last.status == HitStatus.ok,
    );
  }
}

class SessionCounter {
  int completed = 0, successful = 0;
  void add(Hit hit) {
    if (hit.completed) {
      completed++;
      if (hit.status == HitStatus.ok) successful++;
    }
  }

  double? get successRate =>
      completed == 0 ? null : successful / completed * 100;
}

class SessionEvent {
  const SessionEvent(this.at, this.key, this.message);
  final DateTime at;
  final ProbeKey? key;
  final String message;
}

class SessionBaseline {
  SessionBaseline({
    required this.at,
    required this.context,
    required Map<ProbeKey, Hit> results,
  }) : results = Map.unmodifiable(results);
  final DateTime at;
  final String context;
  final Map<ProbeKey, Hit> results;
}

class NicChoice {
  const NicChoice({required this.id, required this.label, this.address});
  final String id, label;
  final String? address;
  static const any = NicChoice(id: 'any', label: 'System default');
}

/// Address scope is context, not proof of tampering. Parse bytes, not prefixes
/// of arbitrary text (a hostname beginning with "fc" is not an IPv6 address).
bool isNonPublicAddress(String raw) {
  final address = InternetAddress.tryParse(raw);
  if (address == null) return false;
  final b = address.rawAddress;
  if (b.length == 4) {
    return b[0] == 0 ||
        b[0] == 10 ||
        b[0] == 127 ||
        b[0] >= 224 ||
        (b[0] == 100 && b[1] >= 64 && b[1] <= 127) ||
        (b[0] == 169 && b[1] == 254) ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168) ||
        (b[0] == 198 && (b[1] == 18 || b[1] == 19));
  }
  if (b.take(10).every((x) => x == 0) && b[10] == 255 && b[11] == 255) {
    return isNonPublicAddress(b.skip(12).join('.'));
  }
  return address.isLoopback ||
      b.every((x) => x == 0) ||
      (b[0] & 0xfe) == 0xfc ||
      (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) ||
      b[0] == 0xff;
}

class GeoInfo {
  const GeoInfo({
    this.country,
    this.countryCode,
    this.city,
    this.lat,
    this.lon,
    this.isp,
  });
  final String? country, countryCode, city, isp;
  final double? lat, lon;
  String get locationString =>
      [city, country].whereType<String>().where((x) => x.isNotEmpty).join(', ');
}

class AsnInfo {
  const AsnInfo({this.asn, this.holder, this.prefix, this.country});
  final int? asn;
  final String? holder, prefix, country;
  String get label => asn == null
      ? holder ?? 'Unknown network'
      : 'AS$asn${holder == null ? '' : ' · $holder'}';
}

class TracerouteHop {
  const TracerouteHop({
    required this.ttl,
    this.ip,
    this.hostname,
    this.rttMs,
    this.lossPercent = 0,
    this.sent = 3,
    this.recv = 0,
    this.bestMs,
    this.worstMs,
    this.avgMs,
    this.stdDevMs,
    this.asn,
    this.geo,
    this.status = HitStatus.ok,
    this.detail,
  });
  final int ttl, sent, recv;
  final String? ip, hostname, detail;
  final int? rttMs, bestMs, worstMs;
  final double lossPercent;
  final double? avgMs, stdDevMs;
  final AsnInfo? asn;
  final GeoInfo? geo;
  final HitStatus status;
  String get displayHost => hostname ?? ip ?? 'No response';
  bool get hasResponse => ip != null;
}

class TracerouteResult {
  const TracerouteResult({
    required this.target,
    required this.hops,
    required this.timestamp,
    this.isComplete = false,
    this.error,
  });
  final String target;
  final List<TracerouteHop> hops;
  final DateTime timestamp;
  final bool isComplete;
  final String? error;
}
