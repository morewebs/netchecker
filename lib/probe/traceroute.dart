import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'models.dart';

/// Only measured operating-system hops are returned. Android has no bundled
/// traceroute capability; there is intentionally no fabricated fallback route.
class TracerouteEngine {
  TracerouteEngine._();
  static final instance = TracerouteEngine._();
  bool get supported => Platform.isWindows || Platform.isLinux;
  Stream<TracerouteResult> trace(
    String target, {
    int maxHops = 30,
    Duration timeout = const Duration(seconds: 2),
  }) {
    Process? process;
    Timer? deadline;
    var cancelled = false;
    final hops = <TracerouteHop>[];
    late StreamController<TracerouteResult> controller;
    void emit({bool done = false, String? error}) {
      if (!cancelled && !controller.isClosed) {
        controller.add(
          TracerouteResult(
            target: target,
            hops: List.unmodifiable(hops),
            timestamp: DateTime.now(),
            isComplete: done,
            error: error,
          ),
        );
      }
    }

    Future<void> run() async {
      emit();
      if (!supported) {
        emit(
          done: true,
          error: 'Route tracing is unavailable on this platform.',
        );
        await controller.close();
        return;
      }
      // Reject arguments; Process.start does not use a shell, but tools parse options.
      if (!RegExp(r'^[a-zA-Z0-9.:_%\-]+$').hasMatch(target) ||
          target.startsWith('-')) {
        emit(done: true, error: 'Invalid route target');
        await controller.close();
        return;
      }
      var timedOut = false;
      try {
        process = await Process.start(
          Platform.isWindows ? 'tracert' : 'traceroute',
          Platform.isWindows
              ? [
                  '-d',
                  '-w',
                  '${timeout.inMilliseconds}',
                  '-h',
                  '$maxHops',
                  target,
                ]
              : [
                  '-n',
                  '-w',
                  '${timeout.inMilliseconds / 1000}',
                  '-m',
                  '$maxHops',
                  '--',
                  target,
                ],
        );
        if (cancelled) {
          process!.kill();
          return;
        }
        deadline = Timer(
          Duration(milliseconds: maxHops * 3 * timeout.inMilliseconds + 5000),
          () {
            timedOut = true;
            process?.kill();
          },
        );
        // Always consume stderr so a full OS pipe cannot block the process.
        final errors = process!.stderr
            .transform(const Utf8Decoder(allowMalformed: true))
            .join();
        await for (final line
            in process!.stdout
                .transform(const Utf8Decoder(allowMalformed: true))
                .transform(const LineSplitter())) {
          if (cancelled) break;
          final hop = parseLine(line);
          if (hop != null) {
            hops.removeWhere((h) => h.ttl == hop.ttl);
            hops.add(hop);
            hops.sort((a, b) => a.ttl.compareTo(b.ttl));
            emit();
          }
        }
        final code = await process!.exitCode;
        await errors;
        emit(
          done: true,
          error: timedOut
              ? 'Route trace reached its time limit. Partial hops are shown.'
              : code != 0
              ? 'The route command failed (exit $code). Partial results may be available.'
              : hops.isEmpty
              ? 'No measurable hops were returned.'
              : null,
        );
      } on ProcessException {
        emit(
          done: true,
          error:
              'The system traceroute command is unavailable. Install traceroute on Linux to enable it.',
        );
      } catch (_) {
        emit(
          done: true,
          error:
              'Route tracing failed. Try again after checking the connection.',
        );
      } finally {
        deadline?.cancel();
        process?.kill();
        if (!controller.isClosed) await controller.close();
      }
    }

    controller = StreamController<TracerouteResult>(
      onListen: () {
        unawaited(run());
      },
      onCancel: () {
        cancelled = true;
        deadline?.cancel();
        process?.kill();
      },
    );
    return controller.stream;
  }

  static TracerouteHop? parseLine(String line) {
    final match = RegExp(r'^\s*(\d+)\s+(.+)$').firstMatch(line);
    if (match == null) return null;
    final ttl = int.parse(match[1]!);
    if (ttl < 1 || ttl > 255) return null;
    final rest = match[2]!;
    String? ip;
    for (final token in rest.split(RegExp(r'\s+'))) {
      final cleaned = token.replaceAll(RegExp(r'[\[\]()]'), '');
      if (InternetAddress.tryParse(cleaned) != null) {
        ip = cleaned;
        break;
      }
    }
    final rtts = RegExp(r'(<)?\s*(\d+(?:[.,]\d+)?)\s*ms')
        .allMatches(rest)
        .map(
          (m) => m[1] == '<' ? 0.5 : double.parse(m[2]!.replaceAll(',', '.')),
        )
        .toList();
    final recv = rtts.length.clamp(0, 3);
    final avg = rtts.isEmpty
        ? null
        : rtts.reduce((a, b) => a + b) / rtts.length;
    return TracerouteHop(
      ttl: ttl,
      ip: ip,
      rttMs: avg?.round(),
      avgMs: avg,
      bestMs: rtts.isEmpty
          ? null
          : rtts.reduce((a, b) => a < b ? a : b).round(),
      worstMs: rtts.isEmpty
          ? null
          : rtts.reduce((a, b) => a > b ? a : b).round(),
      sent: 3,
      recv: recv,
      lossPercent: (3 - recv) / 3 * 100,
      status: ip == null ? HitStatus.timeout : HitStatus.ok,
    );
  }
}
