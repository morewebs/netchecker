import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:netchecker/probe/dns.dart';

void main() {
  test('buildDnsQuery writes id and labels', () {
    final q = buildDnsQuery('google.com', id: 0xabcd);
    expect(q[0], 0xab);
    expect(q[1], 0xcd);
    expect(q[2], 0x01);
    expect(q[5], 0x01);
    expect(q[12], 6);
    expect(String.fromCharCodes(q.sublist(13, 19)), 'google');
    expect(q[19], 3);
    expect(String.fromCharCodes(q.sublist(20, 23)), 'com');
  });

  test('parseDnsARecords reads A answers', () {
    final q = buildDnsQuery('a.co', id: 0x0001);
    final msg = BytesBuilder()
      ..add(q)
      ..add([
        0xc0, 0x0c, // pointer to name
        0x00, 0x01, // A
        0x00, 0x01, // IN
        0x00, 0x00, 0x00, 0x3c, // TTL
        0x00, 0x04,
        1, 2, 3, 4,
      ]);
    // QDCOUNT/ANCOUNT are in the header copied from the query (ANCOUNT=0).
    final bytes = Uint8List.fromList(msg.toBytes());
    bytes[2] = 0x81; // QR=response, RD=query recursion requested
    bytes[7] = 1; // ANCOUNT
    expect(parseDnsARecords(bytes), ['1.2.3.4']);
  });
}
