import 'package:flutter_test/flutter_test.dart';
import 'package:netchecker/probe/traceroute.dart';
import 'package:netchecker/probe/models.dart';

void main() {
  test('parses Windows IPv4 and IPv6 measured hops', () {
    final v4 = TracerouteEngine.parseLine(
      '  1    <1 ms    2 ms    3 ms  192.168.1.1',
    )!;
    expect(v4.ip, '192.168.1.1');
    expect(v4.recv, 3);
    final v6 = TracerouteEngine.parseLine(
      '  2    12 ms   14 ms   13 ms  2606:4700::1111',
    )!;
    expect(v6.ip, '2606:4700::1111');
    expect(v6.rttMs, 13);
  });
  test(
    'parses Linux decimal timings and partial replies without invented hops',
    () {
      final hop = TracerouteEngine.parseLine(
        ' 3  192.0.2.1  1.234 ms * 2.345 ms',
      )!;
      expect(hop.ip, '192.0.2.1');
      expect(hop.recv, 2);
      expect(
        TracerouteEngine.parseLine(' 4  * * *')!.status,
        HitStatus.timeout,
      );
      expect(TracerouteEngine.parseLine('traceroute to example.com'), isNull);
    },
  );
}
