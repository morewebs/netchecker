import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../probe/engine.dart';
import '../../probe/models.dart';
import '../../probe/traceroute.dart';
import '../../theme.dart';
import '../presentation.dart';
import '../strings.dart';
import 'route_map_page.dart';

class ItemProfilePage extends StatelessWidget {
  const ItemProfilePage({
    super.key,
    required this.engine,
    required this.target,
  });
  final ProbeEngine engine;
  final ProbeTarget target;
  static Future<void> open(
    BuildContext context, {
    required ProbeEngine engine,
    required ProbeTarget target,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ItemProfilePage(engine: engine, target: target),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(target.categoryLabel)),
    body: SafeArea(
      child: TargetInspector(engine: engine, target: target),
    ),
  );
}

class TargetInspector extends StatelessWidget {
  const TargetInspector({
    super.key,
    required this.engine,
    required this.target,
    this.onClose,
  });
  final ProbeEngine engine;
  final ProbeTarget target;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final hit = engine.hitFor(target.key),
          metrics = engine.metricsFor(target.key),
          counter = engine.counterFor(target.key);
      final checking =
          engine.executionFor(target.key) == ProbeExecution.checking;
      final history = engine.historyFor(target.key), phase = hit.phase;
      final before = engine.baseline?.results[target.key];
      final privacy = engine.settings.privacyMode;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetName(engine, target),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      targetAddress(engine, target),
                      style: mono.copyWith(color: kMute),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: 'Close details',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusMark(hit: hit, checking: checking),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: statusColor(hit.status),
                      ),
                    ),
                    if (hit.detail != null && hit.detail != hit.label)
                      Text(
                        hit.detail!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Freshness(
                      at: hit.at,
                      prefix: checking ? 'Checking again · ' : '',
                    ),
                  ],
                ),
              ),
              if (hit.ms != null)
                Text('${hit.ms} ms', style: mono.copyWith(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: checking || !engine.adapterAvailable
                    ? null
                    : () => engine.runNow(target),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(checking ? 'Checking' : AppStrings.checkNow),
              ),
              OutlinedButton.icon(
                onPressed: TracerouteEngine.instance.supported
                    ? () => RouteMapPage.open(
                        context,
                        target: target.address,
                        title: targetName(engine, target),
                        privacyMode: privacy,
                      )
                    : null,
                icon: const Icon(Icons.route_outlined, size: 18),
                label: const Text('Trace route'),
              ),
            ],
          ),
          if (!TracerouteEngine.instance.supported)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Route tracing is available on Windows and Linux.',
                style: TextStyle(color: kMute, fontSize: 12),
              ),
            ),
          if (hit.warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(hit.warning!, style: const TextStyle(color: kTo)),
            ),
          const SectionLabel('What this checks'),
          Text(
            privacy
                ? '${target.categoryLabel}. Target details are hidden by privacy mode.'
                : target.description,
          ),
          if (engine.settings.nicId != 'any' && target.uri != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Sockets use the selected adapter. Hostname resolution uses system DNS.',
                style: TextStyle(color: kMute, fontSize: 12),
              ),
            ),
          const SectionLabel('This network context'),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _Metric('Checks', '${counter.completed}'),
              _Metric(
                'Success',
                counter.successRate == null
                    ? '—'
                    : '${counter.successRate!.toStringAsFixed(0)}%',
              ),
              _Metric(
                'Average',
                metrics.okCount == 0 ? '—' : '${metrics.avgMs.round()} ms',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Success counts completed checks. Latency statistics use successful results in the recent history.',
            style: TextStyle(color: kMute, fontSize: 12),
          ),
          SectionLabel(
            'Recent checks',
            trailing: Text(
              '${history.length} / ${ProbeEngine.historyLimit}',
              style: mono.copyWith(color: kMute),
            ),
          ),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Completed checks will appear here.',
                style: TextStyle(color: kMute),
              ),
            )
          else ...[
            Semantics(
              label:
                  'Recent response times. ${metrics.okCount} successful checks, ${metrics.failCount} failed checks.',
              child: SizedBox(
                height: 92,
                child: CustomPaint(painter: HistoryPainter(history)),
              ),
            ),
            const SizedBox(height: 12),
            for (final sample in history.reversed.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      clockTime(sample.timestamp),
                      style: mono.copyWith(color: kMute),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sample.detail ?? sample.status.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor(sample.status),
                        ),
                      ),
                    ),
                    if (sample.ms != null) Text('${sample.ms} ms', style: mono),
                  ],
                ),
              ),
          ],
          if (phase != null) ...[
            const SectionLabel('Connection details'),
            if (phase.dnsMs != null) _Detail('DNS lookup', '${phase.dnsMs} ms'),
            if (phase.tcpMs != null)
              _Detail('TCP connection', '${phase.tcpMs} ms'),
            if (phase.tlsMs != null)
              _Detail('TLS handshake', '${phase.tlsMs} ms'),
            if (phase.httpMs != null)
              _Detail('HTTP response', '${phase.httpMs} ms'),
            if (phase.httpStatusCode != null)
              _Detail('HTTP status', '${phase.httpStatusCode}'),
            if (phase.dnsResponseCode != null)
              _Detail('DNS response code', '${phase.dnsResponseCode}'),
            if (phase.method != null) _Detail('Request', phase.method!),
            if (phase.certificateVerified != null)
              _Detail(
                'Certificate',
                phase.certificateVerified! ? 'Verified' : 'Not verified',
              ),
            if (phase.resolvedIps?.isNotEmpty == true)
              _Detail(
                'Addresses',
                privacy ? 'Hidden' : phase.resolvedIps!.join('\n'),
              ),
          ],
          if (engine.baseline != null) ...[
            const SectionLabel('Compared with baseline'),
            Text(
              '${clockTime(engine.baseline!.at)} · ${privacy ? 'Adapter hidden' : engine.baseline!.context}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            _Detail('Then', before?.label ?? 'No result captured'),
            _Detail('Now', hit.label),
            if (before?.status == HitStatus.ok &&
                hit.status == HitStatus.ok &&
                before?.ms != null &&
                hit.ms != null)
              _Detail(
                'Response time',
                '${hit.ms! - before!.ms! > 0 ? '+' : ''}${hit.ms! - before.ms!} ms',
              ),
          ],
          const SectionLabel('Monitoring'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include in monitoring'),
            value: engine.enabled(target.key),
            onChanged: (v) => engine.setEnabled(target.key, v),
          ),
          TextButton.icon(
            onPressed: () => engine.resetStats(target.key),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Clear this target’s results'),
          ),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: mono.copyWith(fontSize: 19)),
      const SizedBox(height: 3),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: kMute, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(value, style: mono, textAlign: TextAlign.end),
        ),
      ],
    ),
  );
}

class HistoryPainter extends CustomPainter {
  HistoryPainter(this.samples);
  final List<ProbeSample> samples;
  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final maxMs = math.max(
      1,
      samples
          .where((s) => s.status == HitStatus.ok)
          .map((s) => s.ms ?? 0)
          .fold(0, math.max),
    );
    final duration = math.max(
      1,
      samples.last.timestamp.difference(samples.first.timestamp).inMilliseconds,
    );
    final grid = Paint()
      ..color = kLine
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 6),
      Offset(size.width, size.height - 6),
      grid,
    );
    Offset? previous;
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      final x = samples.length == 1
          ? size.width / 2
          : (s.timestamp.difference(samples.first.timestamp).inMilliseconds /
                        duration) *
                    (size.width - 8) +
                4;
      final successful = s.status == HitStatus.ok && s.ms != null;
      final y = successful
          ? size.height - 10 - (s.ms! / maxMs) * (size.height - 20)
          : size.height - 6;
      final point = Offset(x, y),
          ink = Paint()
            ..color = statusColor(s.status)
            ..strokeWidth = 1.5;
      if (successful && previous != null) canvas.drawLine(previous, point, ink);
      canvas.drawCircle(point, 2.5, ink);
      previous = successful ? point : null;
    }
  }

  @override
  bool shouldRepaint(HistoryPainter oldDelegate) =>
      oldDelegate.samples != samples;
}
