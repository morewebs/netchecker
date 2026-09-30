import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'cancellation.dart';
import 'models.dart';
import 'tcp.dart' show failure;

Uint8List buildDnsQuery(String qname, {required int id, int type = 1}) {
  final name = qname.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  final labels = name.split('.');
  if (name.length > 253 ||
      labels.any(
        (l) =>
            l.isEmpty || l.length > 63 || !RegExp(r'^[a-z0-9_-]+$').hasMatch(l),
      )) {
    throw const FormatException('Invalid DNS name');
  }
  final bytes = BytesBuilder()
    ..add([id >> 8, id & 255, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
  for (final label in labels) {
    bytes.addByte(label.length);
    bytes.add(ascii.encode(label));
  }
  bytes.add([0, type >> 8, type & 255, 0, 1]);
  return bytes.toBytes();
}

class DnsResponse {
  const DnsResponse({
    required this.id,
    required this.rcode,
    required this.truncated,
    required this.addresses,
  });
  final int id, rcode;
  final bool truncated;
  final List<String> addresses;
}

DnsResponse parseDnsResponse(
  Uint8List bytes, {
  int? expectedId,
  String? question,
  int type = 1,
}) {
  int word(int pos) {
    if (pos < 0 || pos + 2 > bytes.length) {
      throw const FormatException('Truncated DNS packet');
    }
    return (bytes[pos] << 8) | bytes[pos + 1];
  }

  (String, int) name(int start) {
    var pos = start, end = -1, length = 0;
    final seen = <int>{}, labels = <String>[];
    while (true) {
      if (pos >= bytes.length || !seen.add(pos) || seen.length > 128) {
        throw const FormatException('Invalid DNS name pointer');
      }
      final size = bytes[pos];
      if (size == 0) {
        return (labels.join('.').toLowerCase(), end < 0 ? pos + 1 : end);
      }
      if ((size & 0xc0) == 0xc0) {
        final pointer = word(pos) & 0x3fff;
        if (pointer >= pos) {
          throw const FormatException('Invalid forward DNS pointer');
        }
        if (end < 0) end = pos + 2;
        pos = pointer;
      } else {
        if (size > 63 ||
            pos + 1 + size > bytes.length ||
            (length += size + 1) > 254) {
          throw const FormatException('Invalid DNS label');
        }
        labels.add(ascii.decode(bytes.sublist(pos + 1, pos + 1 + size)));
        pos += size + 1;
      }
    }
  }

  if (bytes.length < 12) throw const FormatException('Short DNS response');
  final id = word(0), flags = word(2);
  if ((flags & 0x8000) == 0 ||
      (flags & 0x7800) != 0 ||
      word(4) != 1 ||
      (expectedId != null && id != expectedId)) {
    throw const FormatException('Unexpected DNS response');
  }
  final (q, end) = name(12);
  if (word(end) != type ||
      word(end + 2) != 1 ||
      (question != null &&
          q != question.toLowerCase().replaceFirst(RegExp(r'\.$'), ''))) {
    throw const FormatException('DNS question mismatch');
  }
  final truncated = (flags & 0x0200) != 0;
  if (truncated) {
    return DnsResponse(
      id: id,
      rcode: flags & 15,
      truncated: true,
      addresses: const [],
    );
  }
  var pos = end + 4;
  final addresses = <String>[];
  final answers = word(6), records = word(6) + word(8) + word(10);
  if (records > 4096) throw const FormatException('Excessive DNS records');
  for (var i = 0; i < records; i++) {
    final (_, next) = name(pos);
    pos = next;
    final recordType = word(pos),
        recordClass = word(pos + 2),
        size = word(pos + 8);
    pos += 10;
    if (pos + size > bytes.length) {
      throw const FormatException('Truncated DNS record');
    }
    if (i < answers && recordClass == 1) {
      if (recordType == 1 && size == 4) {
        addresses.add(bytes.sublist(pos, pos + 4).join('.'));
      }
      if (recordType == 28 && size == 16) {
        addresses.add(
          InternetAddress.fromRawAddress(bytes.sublist(pos, pos + 16)).address,
        );
      }
    }
    pos += size;
  }
  return DnsResponse(
    id: id,
    rcode: flags & 15,
    truncated: false,
    addresses: List.unmodifiable(addresses.toSet()),
  );
}

List<String> parseDnsARecords(Uint8List bytes) =>
    parseDnsResponse(bytes).addresses;

class DnsProbe {
  DnsProbe({this.sourceAddress});
  final InternetAddress? sourceAddress;
  Future<Hit> latency(
    String resolver,
    String name, {
    required Duration timeout,
    CancellationToken? token,
    int port = 53,
  }) => query(
    resolver,
    name,
    timeout: timeout,
    token: token,
    port: port,
    requireAnswer: false,
  );
  Future<Hit> hunt(
    String resolver,
    String name, {
    required Duration timeout,
    CancellationToken? token,
    int port = 53,
  }) => query(resolver, name, timeout: timeout, token: token, port: port);

  Future<Hit> query(
    String resolver,
    String name, {
    required Duration timeout,
    CancellationToken? token,
    int port = 53,
    bool requireAnswer = true,
  }) async {
    final cancel = CancellationToken();
    final unlink = token?.onCancel(cancel.cancel);
    final watch = Stopwatch()..start();
    RawDatagramSocket? udp;
    Socket? tcp;
    StreamSubscription<RawSocketEvent>? sub;
    try {
      cancel.check();
      final ip = InternetAddress(resolver), id = Random.secure().nextInt(65536);
      if (sourceAddress != null && sourceAddress!.type != ip.type) {
        return const Hit(
          status: HitStatus.unsupported,
          detail: 'Address family unavailable on the selected adapter',
        );
      }
      final packet = buildDnsQuery(name, id: id);
      Duration remaining() {
        cancel.check();
        final d = timeout - watch.elapsed;
        if (d <= Duration.zero) throw TimeoutException('DNS');
        return d;
      }

      Future<T> bounded<T>(Future<T> work) =>
          cancel.bind(work).timeout(remaining());
      final bind =
          sourceAddress ??
          (ip.type == InternetAddressType.IPv6
              ? InternetAddress.anyIPv6
              : InternetAddress.anyIPv4);
      final binding = RawDatagramSocket.bind(bind, 0);
      binding.then((socket) {
        if (cancel.isCancelled) {
          socket.close();
        }
      }, onError: (Object _) {});
      udp = await bounded(binding);
      cancel.onCancel(udp!.close);
      final response = Completer<DnsResponse>();
      sub = udp.listen(
        (event) {
          if (event != RawSocketEvent.read || response.isCompleted) return;
          Datagram? dg;
          while ((dg = udp!.receive()) != null) {
            if (dg!.address.address != ip.address ||
                dg.port != port ||
                dg.data.length < 2 ||
                ((dg.data[0] << 8) | dg.data[1]) != id) {
              continue;
            }
            try {
              response.complete(
                parseDnsResponse(dg.data, expectedId: id, question: name),
              );
            } on FormatException {
              /* Ignore malformed/spoofed datagrams until deadline. */
            }
            if (response.isCompleted) break;
          }
        },
        onError: (Object e) {
          if (!response.isCompleted) response.completeError(e);
        },
      );
      udp.send(packet, ip, port);
      var parsed = await bounded(response.future);
      if (parsed.truncated) {
        final task = await bounded(
          Socket.startConnect(ip, port, sourceAddress: sourceAddress),
        );
        cancel.onCancel(task.cancel);
        task.socket.then((s) {
          if (cancel.isCancelled) s.destroy();
        }, onError: (Object _) {});
        tcp = await bounded(task.socket);
        cancel.onCancel(tcp!.destroy);
        tcp.add([packet.length >> 8, packet.length & 255, ...packet]);
        await bounded(tcp.flush());
        final received = BytesBuilder();
        final answer = Completer<Uint8List>();
        final subscription = tcp.listen(
          (part) {
            if (answer.isCompleted) return;
            received.add(part);
            final bytes = received.toBytes();
            if (bytes.length >= 2) {
              final size = (bytes[0] << 8) | bytes[1];
              if (size < 12) {
                answer.completeError(
                  const FormatException('Invalid DNS TCP length'),
                );
              } else if (bytes.length >= size + 2) {
                answer.complete(bytes.sublist(2, size + 2));
              }
            }
          },
          onError: (Object e) {
            if (!answer.isCompleted) answer.completeError(e);
          },
          onDone: () {
            if (!answer.isCompleted) {
              answer.completeError(
                const FormatException('Incomplete DNS TCP response'),
              );
            }
          },
        );
        try {
          parsed = parseDnsResponse(
            await bounded(answer.future),
            expectedId: id,
            question: name,
          );
        } finally {
          await subscription.cancel();
        }
      }
      final responseText = switch (parsed.rcode) {
        0 =>
          parsed.addresses.isEmpty
              ? 'No address records'
              : 'DNS answer received',
        1 => 'Malformed DNS query',
        2 => 'DNS server failure',
        3 => 'Name does not exist',
        5 => 'DNS query refused',
        _ => 'DNS response code ${parsed.rcode}',
      };
      final success =
          !requireAnswer ||
          (parsed.rcode == 0 &&
              parsed.addresses.isNotEmpty &&
              !parsed.truncated);
      return Hit(
        status: success ? HitStatus.ok : HitStatus.fail,
        ms: watch.elapsedMilliseconds,
        at: DateTime.now(),
        detail: responseText,
        warning: parsed.addresses.any(isNonPublicAddress)
            ? 'Private or synthetic DNS answer; this can be expected on a VPN or local network.'
            : !requireAnswer && parsed.rcode != 0
            ? 'Resolver responded, but did not resolve the question successfully.'
            : null,
        phase: PhaseBreakdown(
          dnsMs: watch.elapsedMilliseconds,
          resolvedIps: parsed.addresses,
          dnsResponseCode: parsed.rcode,
        ),
      );
    } catch (e) {
      return failure(e, watch.elapsedMilliseconds, phase: 'DNS');
    } finally {
      await sub?.cancel();
      udp?.close();
      tcp?.destroy();
      unlink?.call();
      cancel.cancel();
    }
  }
}
