import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

Uri parseWebsite(String input) {
  var raw = input.trim();
  if (raw.isEmpty || RegExp(r'\s').hasMatch(raw)) {
    throw const FormatException(
      'Enter a hostname or HTTPS URL without spaces.',
    );
  }
  if (!raw.contains('://')) {
    final ip = InternetAddress.tryParse(raw);
    raw = 'https://${ip?.type == InternetAddressType.IPv6 ? '[$raw]' : raw}';
  }
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
      'Use a hostname, IP address or HTTPS URL without credentials.',
    );
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (InternetAddress.tryParse(host) == null &&
      (!RegExp(r'^[a-z0-9.-]+$').hasMatch(host) ||
          host
              .split('.')
              .any(
                (s) =>
                    s.isEmpty ||
                    s.length > 63 ||
                    s.startsWith('-') ||
                    s.endsWith('-'),
              ))) {
    throw const FormatException(
      'Enter a valid hostname (use punycode for international names).',
    );
  }
  if (uri.port < 1 || uri.port > 65535 || host.length > 253) {
    throw const FormatException('Invalid host or port.');
  }
  return uri
      .replace(
        host: host,
        path: uri.path.isEmpty ? '/' : uri.path,
        fragment: '',
      )
      .removeFragment();
}

String parseDnsName(String input) {
  final uri = parseWebsite(input);
  if (InternetAddress.tryParse(uri.host) != null) {
    throw const FormatException(
      'DNS comparison needs a hostname, not an IP address.',
    );
  }
  return uri.host;
}

class AppSettings {
  const AppSettings({
    this.httpTimeoutMs = 3000,
    this.itemDelayMs = 400,
    this.dnsTimeoutMs = 2000,
    this.dnsDelayMs = 600,
    this.huntName = 'youtube.com',
    this.extraDomains = const [],
    this.useDefaultDomains = true,
    this.alwaysOnTop = false,
    this.compactMode = false,
    this.nicId = 'any',
    this.running = true,
    this.privacyMode = false,
    this.exportFormat = 'markdown',
    this.autoCheckUpdates = true,
    this.favorites = const [],
    this.disabledTargets = const [],
  });
  final int httpTimeoutMs, itemDelayMs, dnsTimeoutMs, dnsDelayMs;
  final String huntName, nicId, exportFormat;
  final List<String> extraDomains, favorites, disabledTargets;
  final bool useDefaultDomains,
      alwaysOnTop,
      compactMode,
      running,
      privacyMode,
      autoCheckUpdates;
  Duration get httpTimeout => Duration(milliseconds: httpTimeoutMs);
  Duration get itemDelay => Duration(milliseconds: itemDelayMs);
  Duration get dnsTimeout => Duration(milliseconds: dnsTimeoutMs);
  Duration get dnsDelay => Duration(milliseconds: dnsDelayMs);
  AppSettings copyWith({
    int? httpTimeoutMs,
    int? itemDelayMs,
    int? dnsTimeoutMs,
    int? dnsDelayMs,
    String? huntName,
    List<String>? extraDomains,
    bool? useDefaultDomains,
    bool? alwaysOnTop,
    bool? compactMode,
    String? nicId,
    bool? running,
    bool? privacyMode,
    String? exportFormat,
    bool? autoCheckUpdates,
    List<String>? favorites,
    List<String>? disabledTargets,
  }) => AppSettings(
    httpTimeoutMs: httpTimeoutMs ?? this.httpTimeoutMs,
    itemDelayMs: itemDelayMs ?? this.itemDelayMs,
    dnsTimeoutMs: dnsTimeoutMs ?? this.dnsTimeoutMs,
    dnsDelayMs: dnsDelayMs ?? this.dnsDelayMs,
    huntName: huntName ?? this.huntName,
    extraDomains: List.unmodifiable(extraDomains ?? this.extraDomains),
    useDefaultDomains: useDefaultDomains ?? this.useDefaultDomains,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    compactMode: compactMode ?? this.compactMode,
    nicId: nicId ?? this.nicId,
    running: running ?? this.running,
    privacyMode: privacyMode ?? this.privacyMode,
    exportFormat: exportFormat ?? this.exportFormat,
    autoCheckUpdates: autoCheckUpdates ?? this.autoCheckUpdates,
    favorites: List.unmodifiable(favorites ?? this.favorites),
    disabledTargets: List.unmodifiable(disabledTargets ?? this.disabledTargets),
  );

  factory AppSettings.fromPrefs(SharedPreferences p) {
    T read<T>(String key, T fallback) {
      try {
        final value = p.get(key);
        return value is T ? value : fallback;
      } catch (_) {
        return fallback;
      }
    }

    final rawHunt = read('huntName', 'youtube.com');
    String hunt;
    try {
      hunt = parseDnsName(rawHunt);
    } catch (_) {
      hunt = 'youtube.com';
    }
    final extras = <String>{};
    for (final entry in read<List<String>>('extraDomains', [])) {
      try {
        extras.add(parseWebsite(entry).toString());
      } catch (_) {
        /* Invalid legacy entries are excluded. */
      }
    }
    final format = read('exportFormat', 'markdown');
    return AppSettings(
      httpTimeoutMs: read('httpTimeoutMs', 3000).clamp(500, 15000),
      itemDelayMs: read('itemDelayMs', 400).clamp(0, 5000),
      dnsTimeoutMs: read('dnsTimeoutMs', 2000).clamp(300, 8000),
      dnsDelayMs: read('dnsDelayMs', 600).clamp(0, 5000),
      huntName: hunt,
      extraDomains: extras.toList(),
      useDefaultDomains: read('useDefaultDomains', true),
      alwaysOnTop: read('alwaysOnTop', false),
      compactMode: read('compactMode', read('alwaysOnTop', false)),
      nicId: read('nicId', 'any'),
      running: read('running', true),
      privacyMode: read('privacyMode', false),
      exportFormat: ['markdown', 'plaintext', 'json', 'csv'].contains(format)
          ? format
          : 'markdown',
      autoCheckUpdates: read('autoCheckUpdates', true),
      favorites: read<List<String>>('favorites', []),
      disabledTargets: read<List<String>>('disabledTargets', []),
    );
  }
  Future<void> save(SharedPreferences p) async {
    await Future.wait([
      p.setInt('settingsVersion', 2),
      p.remove('maxRounds'),
      p.setInt('httpTimeoutMs', httpTimeoutMs),
      p.setInt('itemDelayMs', itemDelayMs),
      p.setInt('dnsTimeoutMs', dnsTimeoutMs),
      p.setInt('dnsDelayMs', dnsDelayMs),
      p.setString('huntName', huntName),
      p.setStringList('extraDomains', extraDomains),
      p.setBool('useDefaultDomains', useDefaultDomains),
      p.setBool('alwaysOnTop', alwaysOnTop),
      p.setBool('compactMode', compactMode),
      p.setString('nicId', nicId),
      p.setBool('running', running),
      p.setBool('privacyMode', privacyMode),
      p.setString('exportFormat', exportFormat),
      p.setBool('autoCheckUpdates', autoCheckUpdates),
      p.setStringList('favorites', favorites),
      p.setStringList('disabledTargets', disabledTargets),
    ]);
  }
}
