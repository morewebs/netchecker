import 'dart:async';
import 'dart:io';
import 'cancellation.dart';
import 'models.dart';
import '../settings/app_settings.dart';

class TcpTlsProbe {
  TcpTlsProbe({this.sourceAddress, this.securityContext});
  final InternetAddress? sourceAddress;

  /// Injectable trust store for deterministic local TLS fixtures.
  final SecurityContext? securityContext;

  Future<Hit> connect(
    String host,
    int port, {
    required Duration timeout,
    CancellationToken? token,
  }) async {
    final cancel = CancellationToken();
    final unlink = token?.onCancel(cancel.cancel);
    final watch = Stopwatch()..start();
    Socket? socket;
    try {
      cancel.check();
      final task = await Socket.startConnect(
        host,
        port,
        sourceAddress: sourceAddress,
      );
      cancel.onCancel(task.cancel);
      task.socket.then((s) {
        if (cancel.isCancelled) s.destroy();
      }, onError: (Object _) {});
      socket = await cancel.bind(task.socket).timeout(timeout);
      return Hit(
        status: HitStatus.ok,
        ms: watch.elapsedMilliseconds,
        at: DateTime.now(),
        detail: 'TCP connection established',
        phase: PhaseBreakdown(tcpMs: watch.elapsedMilliseconds),
      );
    } catch (e) {
      return failure(e, watch.elapsedMilliseconds);
    } finally {
      socket?.destroy();
      unlink?.call();
      cancel.cancel();
    }
  }

  Future<Hit> tls(
    String ip,
    String sni, {
    required Duration timeout,
    int port = 443,
    bool verifyCertificate = false,
    CancellationToken? token,
  }) async {
    final cancel = CancellationToken();
    final unlink = token?.onCancel(cancel.cancel);
    final watch = Stopwatch()..start();
    Socket? raw;
    SecureSocket? secure;
    int? tcpMs;
    try {
      cancel.check();
      final task = await Socket.startConnect(
        ip,
        port,
        sourceAddress: sourceAddress,
      );
      cancel.onCancel(task.cancel);
      task.socket.then((s) {
        if (cancel.isCancelled) s.destroy();
      }, onError: (Object _) {});
      raw = await cancel.bind(task.socket).timeout(timeout);
      cancel.onCancel(raw.destroy);
      tcpMs = watch.elapsedMilliseconds;
      final remaining = timeout - watch.elapsed;
      if (remaining <= Duration.zero) throw TimeoutException('TLS deadline');
      secure = await cancel
          .bind(
            SecureSocket.secure(
              raw,
              host: sni,
              context: securityContext,
              onBadCertificate: verifyCertificate ? null : (_) => true,
            ),
          )
          .timeout(remaining);
      cancel.onCancel(secure.destroy);
      return Hit(
        status: HitStatus.ok,
        ms: watch.elapsedMilliseconds,
        at: DateTime.now(),
        detail: 'TLS handshake completed',
        warning: verifyCertificate
            ? null
            : 'Handshake only. Certificate identity was not verified.',
        phase: PhaseBreakdown(
          tcpMs: tcpMs,
          tlsMs: watch.elapsedMilliseconds - tcpMs,
          certificateVerified: verifyCertificate,
        ),
      );
    } catch (e) {
      return failure(e, watch.elapsedMilliseconds);
    } finally {
      secure?.destroy();
      raw?.destroy();
      unlink?.call();
      cancel.cancel();
    }
  }

  Future<Hit> https(
    String host, {
    required Duration timeout,
    CancellationToken? token,
  }) => request(parseWebsite(host), timeout: timeout, token: token);

  /// HttpClient's factory owns DNS, TCP and TLS. Returning a raw Socket for an
  /// https URI bypasses TLS: the factory must return the secured connection.
  Future<Hit> request(
    Uri uri, {
    required Duration timeout,
    CancellationToken? token,
  }) async {
    final cancel = CancellationToken();
    final unlink = token?.onCancel(cancel.cancel);
    final watch = Stopwatch()..start();
    final client = HttpClient(context: securityContext);
    cancel.onCancel(() => client.close(force: true));
    int? dnsMs, tcpMs, tlsMs;
    int? code;
    var method = 'HEAD';
    var phaseName = 'DNS';
    final addresses = <String>{};
    Duration remaining() {
      cancel.check();
      final left = timeout - watch.elapsed;
      if (left <= Duration.zero) throw TimeoutException('Probe deadline');
      return left;
    }

    Future<T> bounded<T>(Future<T> work) =>
        cancel.bind(work).timeout(remaining());
    client.findProxy = (_) => 'DIRECT';
    client.userAgent = 'NetChecker';
    client.connectionFactory = (url, proxyHost, proxyPort) async {
      Future<Socket> open() async {
        phaseName = 'DNS';
        final phase = Stopwatch()..start();
        final literal = InternetAddress.tryParse(url.host);
        final resolved = literal == null
            ? await bounded(
                InternetAddress.lookup(
                  url.host,
                  type: sourceAddress?.type ?? InternetAddressType.any,
                ),
              )
            : [literal];
        cancel.check();
        dnsMs = (dnsMs ?? 0) + phase.elapsedMilliseconds;
        addresses.addAll(resolved.map((a) => a.address));
        if (resolved.isEmpty) {
          throw const SocketException('DNS returned no addresses');
        }
        phaseName = 'TCP';
        Socket? raw;
        Object? lastError;
        phase.reset();
        for (final address in resolved) {
          cancel.check();
          try {
            final task = await bounded(
              Socket.startConnect(
                address,
                url.port,
                sourceAddress: sourceAddress,
              ),
            );
            cancel.onCancel(task.cancel);
            task.socket.then((s) {
              if (cancel.isCancelled) s.destroy();
            }, onError: (Object _) {});
            raw = await bounded(task.socket);
            cancel.onCancel(raw!.destroy);
            break;
          } on SocketException catch (e) {
            lastError = e;
          }
        }
        tcpMs = (tcpMs ?? 0) + phase.elapsedMilliseconds;
        if (raw == null) {
          throw lastError ?? const SocketException('Connection failed');
        }
        phaseName = 'TLS';
        phase.reset();
        final handshake = SecureSocket.secure(
          raw,
          host: url.host,
          context: securityContext,
        );
        handshake.then((s) {
          if (cancel.isCancelled) s.destroy();
        }, onError: (Object _) {});
        final secure = await bounded(handshake);
        cancel.onCancel(secure.destroy);
        tlsMs = (tlsMs ?? 0) + phase.elapsedMilliseconds;
        phaseName = 'HTTP';
        return secure;
      }

      return ConnectionTask.fromSocket(open(), cancel.cancel);
    };
    PhaseBreakdown phases({String? error}) => PhaseBreakdown(
      dnsMs: dnsMs,
      resolvedIps: List.unmodifiable(addresses),
      tcpMs: tcpMs,
      tlsMs: tlsMs,
      httpMs: phaseName == 'HTTP'
          ? (watch.elapsedMilliseconds -
                    (dnsMs ?? 0) -
                    (tcpMs ?? 0) -
                    (tlsMs ?? 0))
                .clamp(0, 1 << 31)
          : null,
      httpStatusCode: code,
      certificateVerified: phaseName == 'HTTP' ? true : null,
      anomaly: error,
      method: method,
    );
    try {
      Future<HttpClientResponse> send(String verb) async {
        final request = await bounded(client.openUrl(verb, uri));
        request.followRedirects = false;
        if (verb == 'GET') {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
        }
        return bounded(request.close());
      }

      var response = await send('HEAD');
      if (response.statusCode == 405 || response.statusCode == 501) {
        await bounded(response.drain<void>());
        method = 'HEAD → GET';
        response = await send('GET');
      }
      code = response.statusCode;
      // Headers establish reachability; never download an unbounded GET body.
      await response.listen((_) {}).cancel();
      final warning = code >= 400
          ? 'The server responded with HTTP $code. This alone does not establish network filtering.'
          : addresses.any(isNonPublicAddress)
          ? 'Resolved to a private or synthetic address. This can be expected on local networks and VPNs.'
          : null;
      return Hit(
        status: HitStatus.ok,
        ms: watch.elapsedMilliseconds,
        at: DateTime.now(),
        detail: 'HTTP $code',
        warning: warning,
        phase: phases(),
      );
    } catch (e) {
      final result = failure(e, watch.elapsedMilliseconds, phase: phaseName);
      return Hit(
        status: result.status,
        ms: result.ms,
        detail: result.detail,
        at: result.at,
        phase: phases(error: result.detail),
      );
    } finally {
      client.close(force: true);
      unlink?.call();
      cancel.cancel();
    }
  }
}

Hit failure(Object error, int elapsed, {String? phase}) {
  if (error is ProbeCancelled) return Hit.cancelled;
  String detail;
  var status = HitStatus.fail;
  if (error is TimeoutException) {
    detail = phase == null ? 'Timed out' : '$phase timed out';
    status = HitStatus.timeout;
  } else if (error is HandshakeException) {
    detail = 'Certificate or TLS error';
  } else if (error is SocketException) {
    final message = '${error.message} ${error.osError?.message}'.toLowerCase();
    if (message.contains('timed out') || message.contains('timeout')) {
      detail = 'Timed out';
      status = HitStatus.timeout;
    } else if (phase == 'DNS') {
      detail = 'DNS lookup failed';
    } else if (message.contains('refused')) {
      detail = 'Connection refused';
    } else if (message.contains('reset')) {
      detail = 'Connection reset';
    } else {
      detail = 'Connection failed';
    }
  } else {
    detail = phase == null ? 'Check failed' : '$phase failed';
  }
  return Hit(status: status, ms: elapsed, detail: detail, at: DateTime.now());
}
