import 'package:flutter/material.dart';
import '../probe/engine.dart';
import '../theme.dart';
import 'presentation.dart';

class SessionPage extends StatelessWidget {
  const SessionPage({super.key, required this.engine});
  final ProbeEngine engine;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Session & comparison')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: engine,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'See what changed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Capture a baseline before changing your VPN, Wi-Fi or DNS. Open any target to compare its current result. Everything here is cleared when NetChecker closes.',
              style: TextStyle(color: kMute),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: engine.results.values.any((h) => h.completed)
                      ? engine.captureBaseline
                      : null,
                  icon: const Icon(Icons.add_chart, size: 18),
                  label: Text(
                    engine.baseline == null
                        ? 'Capture baseline'
                        : 'Replace baseline',
                  ),
                ),
                if (engine.baseline != null)
                  OutlinedButton(
                    onPressed: engine.clearBaseline,
                    child: const Text('Clear baseline'),
                  ),
              ],
            ),
            if (engine.baseline != null) ...[
              const SectionLabel('Captured baseline'),
              Text(
                '${clockTime(engine.baseline!.at)} · ${engine.settings.privacyMode ? 'Adapter hidden' : engine.baseline!.context}',
                style: mono,
              ),
              Text(
                '${engine.baseline!.results.values.where((h) => h.completed).length} completed target results',
                style: const TextStyle(color: kMute),
              ),
              const SectionLabel('Comparison'),
              for (final target in engine.targets.where(
                (t) => engine.baseline!.results.containsKey(t.key),
              ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetName(engine, target),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${engine.baseline!.results[target.key]!.label} → ${engine.hitFor(target.key).label}',
                        style: const TextStyle(color: kMute),
                      ),
                    ],
                  ),
                ),
            ],
            const SectionLabel('Changes this session'),
            if (engine.events.isEmpty)
              const Text(
                'Changes in completed results will appear here. No history is saved to disk.',
                style: TextStyle(color: kMute),
              ),
            for (final event in engine.events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clockTime(event.at),
                      style: mono.copyWith(color: kMute),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (event.key != null)
                            Text(
                              engine.targets
                                      .where((t) => t.key == event.key)
                                      .isEmpty
                                  ? 'Previous target'
                                  : targetName(
                                      engine,
                                      engine.targets.firstWhere(
                                        (t) => t.key == event.key,
                                      ),
                                    ),
                            ),
                          Text(
                            event.message,
                            style: const TextStyle(color: kMute),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
