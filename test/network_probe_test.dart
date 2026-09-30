import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:netchecker/probe/cancellation.dart';
import 'package:netchecker/probe/dns.dart';
import 'package:netchecker/probe/models.dart';
import 'package:netchecker/probe/tcp.dart';

void main() {
  SecurityContext serverContext() => SecurityContext()
    ..useCertificateChain('test/fixtures/localhost-cert.pem')
    ..usePrivateKey('test/fixtures/localhost-key.pem');
  SecurityContext clientContext() =>
      SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates('test/fixtures/localhost-cert.pem');
  Future<HttpServer> serve(void Function(HttpRequest) handler) async {
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext(),
    );
    server.listen(handler, onError: (Object _) {});
    addTearDown(() => server.close(force: true));
    return server;
  }

  test(
    'verified bound HTTPS records observed stages on the actual request',
    () async {
      var requests = 0;
      final server = await serve((r) {
        requests++;
        r.response.statusCode = 200;
        r.response.close();
      });
      final token = CancellationToken();
      final hit = await token.bind(
        TcpTlsProbe(
          sourceAddress: InternetAddress.loopbackIPv4,
          securityContext: clientContext(),
        ).https(
          'https://localhost:${server.port}/',
          timeout: const Duration(seconds: 2),
          token: token,
        ),
      );
      expect(
        token.isCancelled,
        isFalse,
        reason: 'Transport cleanup must not cancel its caller',
      );
      expect(hit.status, HitStatus.ok);
      expect(requests, 1);
      expect(hit.phase!.certificateVerified, isTrue);
      expect(hit.phase!.httpStatusCode, 200);
      expect(hit.phase!.tcpMs, isNotNull);
      expect(hit.phase!.tlsMs, isNotNull);
      expect(
        hit.warning,
        contains('private'),
      ); // Evidence does not force a failure.
    },
  );
  test('untrusted certificate is rejected by normal HTTPS', () async {
    final server = await serve((r) {
      r.response.close();
    });
    final hit = await TcpTlsProbe().https(
      'https://localhost:${server.port}/',
      timeout: const Duration(seconds: 2),
    );
    expect(hit.status, HitStatus.fail);
    expect(hit.detail, contains('TLS'));
    expect(hit.phase?.httpStatusCode, isNull);
  });
  test('HTTP exception never fabricates status 200', () async {
    final server = await serve((r) {
      r.response.detachSocket(writeHeaders: false).then((s) => s.destroy());
    });
    final hit = await TcpTlsProbe(securityContext: clientContext()).https(
      'https://localhost:${server.port}/',
      timeout: const Duration(seconds: 2),
    );
    expect(hit.status, HitStatus.fail);
    expect(hit.phase!.httpStatusCode, isNull);
  });
  test('HEAD fallback to bounded GET retains the real status', () async {
    final methods = <String>[];
    final server = await serve((r) {
      methods.add(r.method);
      r.response.statusCode = r.method == 'HEAD' ? 405 : 403;
      r.response.close();
    });
    final hit = await TcpTlsProbe(securityContext: clientContext()).https(
      'https://localhost:${server.port}/',
      timeout: const Duration(seconds: 2),
    );
    expect(methods, ['HEAD', 'GET']);
    expect(hit.status, HitStatus.ok);
    expect(hit.phase!.httpStatusCode, 403);
    expect(hit.warning, contains('does not establish'));
    expect(hit.phase!.method, 'HEAD → GET');
  });
  test(
    'slow response meets a total deadline and cancellation is distinct',
    () async {
      final server = await serve((_) {});
      final probe = TcpTlsProbe(securityContext: clientContext());
      final watch = Stopwatch()..start();
      final hit = await probe.https(
        'https://localhost:${server.port}/',
        timeout: const Duration(milliseconds: 180),
      );
      expect(hit.status, HitStatus.timeout);
      expect(watch.elapsedMilliseconds, lessThan(1500));
      final token = CancellationToken();
      final pending = probe.https(
        'https://localhost:${server.port}/',
        timeout: const Duration(seconds: 2),
        token: token,
      );
      token.cancel();
      expect((await pending).status, HitStatus.cancelled);
    },
  );
  test('handshake-only result is explicitly unverified', () async {
    final server = await serve((r) {
      r.response.close();
    });
    final token = CancellationToken();
    final hit = await token.bind(
      TcpTlsProbe().tls(
        '127.0.0.1',
        'unrelated.example',
        port: server.port,
        timeout: const Duration(seconds: 2),
        token: token,
      ),
    );
    expect(token.isCancelled, isFalse);
    expect(hit.status, HitStatus.ok);
    expect(hit.phase!.certificateVerified, isFalse);
    expect(hit.warning, contains('not verified'));
  });

  Uint8List answer(Uint8List query, {int rcode = 0, bool truncated = false}) {
    final packet = Uint8List.fromList([
      ...query,
      if (rcode == 0 && !truncated) ...[
        0xc0,
        12,
        0,
        1,
        0,
        1,
        0,
        0,
        0,
        60,
        0,
        4,
        1,
        2,
        3,
        4,
        0xc0,
        12,
        0,
        1,
        0,
        1,
        0,
        0,
        0,
        60,
        0,
        4,
        5,
        6,
        7,
        8,
      ],
    ]);
    packet[2] = truncated ? 0x83 : 0x81;
    packet[3] = 0x80 | rcode;
    packet[7] = rcode == 0 && !truncated ? 2 : 0;
    return packet;
  }

  test(
    'DNS validates question/header/bounds and preserves multiple answers',
    () {
      final q = buildDnsQuery('example.com', id: 42),
          packet = answer(buildDnsQuery('example.com', id: 42));
      expect(
        parseDnsResponse(
          packet,
          expectedId: 42,
          question: 'example.com',
        ).addresses,
        ['1.2.3.4', '5.6.7.8'],
      );
      expect(() => parseDnsResponse(q), throwsFormatException);
      expect(
        () => parseDnsResponse(packet, expectedId: 43),
        throwsFormatException,
      );
      expect(
        () => parseDnsResponse(packet, question: 'wrong.example'),
        throwsFormatException,
      );
      expect(
        () => parseDnsResponse(packet.sublist(0, packet.length - 1)),
        throwsFormatException,
      );
      final malformed = Uint8List.fromList(packet);
      malformed[12] = 0xc0;
      malformed[13] = 12;
      expect(() => parseDnsResponse(malformed), throwsFormatException);
      expect(parseDnsResponse(answer(q, rcode: 3)).rcode, 3);
    },
  );
  test(
    'responding DNS server and successful lookup are separate facts',
    () async {
      final server = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(server.close);
      final sub = server.listen((e) {
        if (e == RawSocketEvent.read) {
          final d = server.receive();
          if (d != null) {
            server.send(answer(d.data, rcode: 3), d.address, d.port);
          }
        }
      });
      addTearDown(sub.cancel);
      final probe = DnsProbe();
      final token = CancellationToken();
      final response = await token.bind(
        probe.latency(
          '127.0.0.1',
          'example.com',
          port: server.port,
          timeout: const Duration(seconds: 1),
          token: token,
        ),
      );
      expect(token.isCancelled, isFalse);
      final lookup = await probe.hunt(
        '127.0.0.1',
        'example.com',
        port: server.port,
        timeout: const Duration(seconds: 1),
      );
      expect(response.status, HitStatus.ok);
      expect(response.phase!.dnsResponseCode, 3);
      expect(lookup.status, HitStatus.fail);
      expect(lookup.detail, 'Name does not exist');
    },
  );
  test('DNS ignores replies from the wrong source port', () async {
    final server = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        ),
        spoof = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    addTearDown(spoof.close);
    final sub = server.listen((e) {
      if (e == RawSocketEvent.read) {
        final d = server.receive();
        if (d != null) spoof.send(answer(d.data), d.address, d.port);
      }
    });
    addTearDown(sub.cancel);
    final hit = await DnsProbe().hunt(
      '127.0.0.1',
      'example.com',
      port: server.port,
      timeout: const Duration(milliseconds: 100),
    );
    expect(hit.status, HitStatus.timeout);
  });
  test('truncated UDP responses fall back to framed TCP DNS', () async {
    final tcp = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final udp = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      tcp.port,
    );
    addTearDown(udp.close);
    addTearDown(tcp.close);
    final udpSub = udp.listen((e) {
      if (e == RawSocketEvent.read) {
        final d = udp.receive();
        if (d != null) {
          udp.send(answer(d.data, truncated: true), d.address, d.port);
        }
      }
    });
    addTearDown(udpSub.cancel);
    final tcpSub = tcp.listen((socket) {
      addTearDown(socket.destroy);
      final buf = BytesBuilder();
      var sent = false;
      socket.listen((part) {
        if (sent) return;
        buf.add(part);
        final b = buf.toBytes();
        if (b.length >= 2 && b.length >= 2 + ((b[0] << 8) | b[1])) {
          sent = true;
          final response = answer(b.sublist(2));
          socket.add([
            response.length >> 8,
            response.length & 255,
            ...response,
          ]);
        }
      });
    });
    addTearDown(tcpSub.cancel);
    final hit = await DnsProbe().hunt(
      '127.0.0.1',
      'example.com',
      port: udp.port,
      timeout: const Duration(seconds: 1),
    );
    expect(hit.status, HitStatus.ok);
    expect(hit.phase!.resolvedIps, ['1.2.3.4', '5.6.7.8']);
  });
}
