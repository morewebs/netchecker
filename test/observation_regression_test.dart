import 'package:flutter_test/flutter_test.dart';
import 'package:netchecker/probe/models.dart';

void main() {
  test('checking is execution state, not a failed observation', () {
    final metrics = ItemMetrics.fromSamples([
      ProbeSample(timestamp: DateTime(2026), status: HitStatus.ok, ms: 24),
      ProbeSample(timestamp: DateTime(2026), status: HitStatus.checking),
    ]);
    expect(metrics.totalChecks, 1);
    expect(metrics.failCount, 0);
    expect(metrics.uptimePercent, 100);
  });

  test('checking without completed samples has no fabricated measurements', () {
    final metrics = ItemMetrics.fromSamples([], currentHit: Hit.checking);
    expect(metrics.totalChecks, 0);
    expect(metrics.failCount, 0);
  });
}
