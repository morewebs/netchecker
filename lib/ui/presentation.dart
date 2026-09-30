import 'dart:async';
import 'package:flutter/material.dart';
import '../probe/engine.dart';
import '../probe/models.dart';
import '../theme.dart';

String targetName(ProbeEngine engine, ProbeTarget target) =>
    engine.settings.privacyMode
    ? 'Target ${engine.targets.indexWhere((t) => t.key == target.key) + 1}'
    : target.title;
String targetAddress(ProbeEngine engine, ProbeTarget target) =>
    engine.settings.privacyMode
    ? 'Address hidden'
    : target.uri?.toString() ?? target.address;
String contextName(ProbeEngine engine) => engine.settings.privacyMode
    ? 'Context ${engine.contextNumber} · adapter hidden'
    : engine.contextLabel;
String age(DateTime? time, DateTime now) {
  if (time == null) return 'Not checked';
  final seconds = now.difference(time).inSeconds.clamp(0, 1 << 31);
  if (seconds < 2) return 'Just now';
  if (seconds < 60) return '${seconds}s ago';
  if (seconds < 3600) return '${seconds ~/ 60}m ago';
  return '${seconds ~/ 3600}h ago';
}

String clockTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')}';

class Freshness extends StatefulWidget {
  const Freshness({super.key, required this.at, this.prefix = ''});
  final DateTime? at;
  final String prefix;
  @override
  State<Freshness> createState() => _FreshnessState();
}

class _FreshnessState extends State<Freshness> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    '${widget.prefix}${age(widget.at, DateTime.now())}',
    style: Theme.of(context).textTheme.bodySmall,
  );
}

class StatusMark extends StatelessWidget {
  const StatusMark({super.key, required this.hit, this.checking = false});
  final Hit hit;
  final bool checking;
  @override
  Widget build(BuildContext context) {
    if (checking) {
      return Semantics(
        label: 'Checking again',
        child: MediaQuery.disableAnimationsOf(context)
            ? const Icon(Icons.sync, size: 17, color: kMute)
            : const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: kMute,
                ),
              ),
      );
    }
    return Icon(
      switch (hit.status) {
        HitStatus.ok =>
          hit.warning == null ? Icons.check_circle_outline : Icons.info_outline,
        HitStatus.fail => Icons.error_outline,
        HitStatus.timeout => Icons.schedule,
        HitStatus.unsupported => Icons.do_not_disturb_on_outlined,
        _ => Icons.remove,
      },
      size: 18,
      color: hit.warning != null ? kTo : statusColor(hit.status),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    ),
  );
}
