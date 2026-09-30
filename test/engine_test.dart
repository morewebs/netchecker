import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:netchecker/probe/engine.dart';
import 'package:netchecker/probe/models.dart';
import 'package:netchecker/export/report_export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_transport.dart';

void main() {
  late ProbeEngine engine;
  late FakeTransport transport;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'autoCheckUpdates': false});
    transport = FakeTransport();
    engine = ProbeEngine(transport: transport);
    await engine.start(loops: false, loadNics: false);
  });
  tearDown(() => engine.dispose());
  test(
    'DNS, comparison and edge at same IP have independent observations',
    () async {
      final targets = engine.targets
          .where(
            (t) =>
                t.address == '1.1.1.1' &&
                [
                  ItemCategory.dns,
                  ItemCategory.hunt,
                  ItemCategory.edge,
                ].contains(t.category),
          )
          .toList();
      expect(targets.length, 3);
      for (var i = 0; i < targets.length; i++) {
        transport.result = Hit(status: HitStatus.ok, ms: 10 + i);
        await engine.runNow(targets[i]);
      }
      expect(targets.map((t) => engine.historyFor(t.key).single.ms), [
        10,
        11,
        12,
      ]);
      engine.resetStats(targets.first.key);
      expect(engine.historyFor(targets[1].key).length, 1);
    },
  );
  test(
    'manual and automatic callers share one attempt and keep last result',
    () async {
      final target = engine.targets.first;
      await engine.runNow(target);
      transport.hold = true;
      final first = engine.runNow(target), second = engine.runNow(target);
      expect(identical(first, second), isTrue);
      expect(transport.calls, 2);
      expect(engine.hitFor(target.key).ms, 24);
      expect(engine.executionFor(target.key), ProbeExecution.checking);
      transport.pending.single.complete(
        const Hit(status: HitStatus.ok, ms: 31),
      );
      await first;
      expect(engine.historyFor(target.key).length, 2);
    },
  );
  test('pause cancels and ignores late work without failure counts', () async {
    transport.hold = true;
    final target = engine.targets.first;
    final request = engine.runNow(target);
    await engine.setRunning(false);
    transport.pending.single.complete(const Hit(status: HitStatus.ok, ms: 2));
    expect((await request).status, HitStatus.cancelled);
    expect(engine.historyFor(target.key), isEmpty);
    expect(engine.executionFor(target.key), ProbeExecution.paused);
    expect(transport.tokens.single.isCancelled, isTrue);
  });
  test('display changes preserve observations and in-flight work', () async {
    final target = engine.targets.first;
    await engine.runNow(target);
    transport.hold = true;
    final future = engine.runNow(target);
    await engine.apply(
      engine.settings.copyWith(privacyMode: true, compactMode: true),
    );
    expect(transport.tokens.last.isCancelled, isFalse);
    expect(engine.historyFor(target.key).length, 1);
    transport.pending.single.complete(const Hit(status: HitStatus.ok, ms: 26));
    await future;
    expect(engine.counterFor(target.key).completed, 2);
  });
  test(
    'context change cancels stale work and keeps captured baseline',
    () async {
      final target = engine.targets.first;
      await engine.runNow(target);
      engine.captureBaseline();
      transport.hold = true;
      final future = engine.runNow(target);
      await engine.apply(engine.settings.copyWith(huntName: 'example.com'));
      transport.pending.single.complete(const Hit(status: HitStatus.fail));
      await future;
      expect(engine.results, isEmpty);
      expect(engine.baseline!.results[target.key]!.ms, 24);
      expect(engine.contextNumber, 2);
    },
  );
  test('reset target cannot be repopulated by an old attempt', () async {
    transport.hold = true;
    final target = engine.targets.first;
    final future = engine.runNow(target);
    engine.resetStats(target.key);
    transport.pending.single.complete(const Hit(status: HitStatus.ok));
    await future;
    expect(engine.results, isEmpty);
  });
  test(
    'histories and events are bounded but counters retain the session',
    () async {
      final target = engine.targets.first;
      for (var i = 0; i < 250; i++) {
        transport.result = Hit(
          status: i.isEven ? HitStatus.ok : HitStatus.fail,
          ms: i,
        );
        await engine.runNow(target);
      }
      expect(engine.historyFor(target.key).length, ProbeEngine.historyLimit);
      expect(engine.counterFor(target.key).completed, 250);
      expect(engine.events.length, ProbeEngine.eventLimit);
    },
  );
  test('exports include every category and redact identifiers', () async {
    for (final target in engine.targets) {
      await engine.runNow(target);
    }
    final raw = ReportExport.generate(
      engine,
      format: ExportFormat.json,
      redact: false,
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    expect(json['schemaVersion'], 2);
    for (final category in ['domains', 'dns', 'hunt', 'edges', 'proto']) {
      expect((json[category] as Map).isNotEmpty, isTrue);
    }
    final safe = ReportExport.generate(engine, format: ExportFormat.json);
    expect(safe, isNot(contains('youtube.com')));
    expect(safe, isNot(contains('1.1.1.1')));
    for (final format in ExportFormat.values) {
      expect(
        ReportExport.generate(engine, format: format),
        isNot(contains('youtube.com')),
      );
    }
    expect(ReportExport.csvCell('=evil,"quoted"'), '"\'=evil,""quoted"""');
    expect(ReportExport.markdownCell('a|b\nc'), r'a\|b c');
  });
  test('results do not survive engine restart', () async {
    await engine.runNow(engine.targets.first);
    engine.captureBaseline();
    await engine.setRunning(false);
    final restarted = ProbeEngine(transport: transport);
    await restarted.start(loops: false, loadNics: false);
    addTearDown(restarted.dispose);
    expect(restarted.results, isEmpty);
    expect(restarted.events, isEmpty);
    expect(restarted.baseline, isNull);
    expect(restarted.isRunning, isFalse);
  });
  test(
    'removed targets leave totals and disappearance never silently rebinds',
    () async {
      await engine.runNow(engine.targets.first);
      await engine.apply(
        engine.settings.copyWith(
          useDefaultDomains: false,
          extraDomains: ['example.com'],
          nicId: 'missing|192.0.2.1',
        ),
      );
      expect(engine.results, isEmpty);
      expect(engine.adapterAvailable, isFalse);
      expect(
        (await engine.runNow(engine.targets.first)).status,
        HitStatus.unsupported,
      );
      expect(engine.nic.id, 'missing');
    },
  );
  test('dispose invalidates outstanding completions', () async {
    final other = ProbeEngine(transport: transport);
    await other.start(loops: false, loadNics: false);
    transport.hold = true;
    final pending = other.runNow(other.targets.first);
    other.dispose();
    transport.pending.single.complete(const Hit(status: HitStatus.ok));
    expect((await pending).status, HitStatus.cancelled);
  });
  test(
    'three sequential lanes run with bounded concurrency and stop on pause',
    () async {
      transport.hold = true;
      final live = ProbeEngine(transport: transport);
      await live.start(loadNics: false);
      addTearDown(live.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(transport.calls, 3);
      expect(transport.maxActive, 3);
      await live.setRunning(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(transport.active, 0);
      for (final p in transport.pending) {
        if (!p.isCompleted) p.complete(const Hit(status: HitStatus.ok));
      }
    },
  );
}
