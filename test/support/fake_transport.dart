import 'dart:async';
import 'dart:io';
import 'package:netchecker/probe/cancellation.dart';
import 'package:netchecker/probe/models.dart';
import 'package:netchecker/probe/transport.dart';
import 'package:netchecker/settings/app_settings.dart';

class FakeTransport implements ProbeTransport {
  int calls = 0, active = 0, maxActive = 0;
  Hit result = const Hit(status: HitStatus.ok, ms: 24, detail: 'HTTP 200');
  bool hold = false;
  final List<Completer<Hit>> pending = [];
  final List<CancellationToken> tokens = [];
  @override
  Future<Hit> probe(
    ProbeTarget target,
    AppSettings settings,
    CancellationToken token,
    InternetAddress? bind,
  ) async {
    calls++;
    active++;
    if (active > maxActive) maxActive = active;
    tokens.add(token);
    try {
      if (!hold) return result;
      final completer = Completer<Hit>();
      pending.add(completer);
      return await token.bind(completer.future);
    } finally {
      active--;
    }
  }
}
