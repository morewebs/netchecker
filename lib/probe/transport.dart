import 'dart:async';
import 'dart:io';
import '../settings/app_settings.dart';
import 'cancellation.dart';
import 'dns.dart';
import 'models.dart';
import 'tcp.dart';

abstract class ProbeTransport {
  Future<Hit> probe(
    ProbeTarget target,
    AppSettings settings,
    CancellationToken token,
    InternetAddress? bind,
  );
}

class SocketProbeTransport implements ProbeTransport {
  @override
  Future<Hit> probe(
    ProbeTarget target,
    AppSettings settings,
    CancellationToken token,
    InternetAddress? bind,
  ) {
    final tcp = TcpTlsProbe(sourceAddress: bind);
    if (target.category == ItemCategory.dns ||
        target.category == ItemCategory.hunt) {
      return DnsProbe(sourceAddress: bind).query(
        target.address,
        target.key.query,
        timeout: settings.dnsTimeout,
        token: token,
        requireAnswer: target.category == ItemCategory.hunt,
      );
    }
    final address = InternetAddress.tryParse(target.address);
    if (address != null && bind != null && address.type != bind.type) {
      return Future.value(
        const Hit(
          status: HitStatus.unsupported,
          detail: 'Address family unavailable on the selected adapter',
        ),
      );
    }
    if (target.uri != null) {
      return tcp.request(
        target.uri!,
        timeout: settings.httpTimeout,
        token: token,
      );
    }
    if (target.handshakeOnly) {
      return tcp.tls(
        target.address,
        target.sni!,
        timeout: settings.httpTimeout,
        token: token,
        port: target.port,
      );
    }
    return tcp.connect(
      target.address,
      target.port,
      timeout: settings.httpTimeout,
      token: token,
    );
  }
}

class ProbeClock {
  DateTime now() => DateTime.now();
  Future<void> wait(Duration duration, CancellationToken token) {
    final done = Completer<void>();
    void Function()? unregister;
    final timer = Timer(duration, () {
      unregister?.call();
      if (!done.isCompleted) done.complete();
    });
    unregister = token.onCancel(() {
      timer.cancel();
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }
}
