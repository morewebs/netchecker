import 'package:flutter/material.dart';

import '../probe/engine.dart';
import '../theme.dart';
import 'board.dart';
import 'keyboard/shortcuts.dart';
import 'keyboard/shortcuts_dialog.dart';
import 'settings_form.dart';

class AndroidHome extends StatelessWidget {
  const AndroidHome({super.key, required this.engine});

  final ProbeEngine engine;

  void _showHelp(BuildContext context) {
    ShortcutsCheatsheetDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final isRunning = engine.settings.running;
        final totalDomains = engine.domains.length;

        return Builder(
          builder: (bCtx) {
            return AppShortcutsWrapper(
              onToggleRun: () => engine.setRunning(!isRunning),
              onOpenSettings: () => _openSettings(bCtx),
              onCopyReport: () => copyReport(bCtx, engine),
              onShowHelp: () => _showHelp(bCtx),
              child: Scaffold(
                backgroundColor: kInk,
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(bCtx).colorScheme.surfaceContainerLow,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(bCtx).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            // Brand & Live Pulse (M3 Badge)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Theme.of(bCtx).colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Theme.of(bCtx).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isRunning ? kOk : kTo,
                                      shape: BoxShape.circle,
                                      boxShadow: isRunning
                                          ? [
                                              BoxShadow(
                                                color: kOk.withValues(alpha: 0.5),
                                                blurRadius: 6,
                                                spreadRadius: 1.5,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'NetChecker',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      letterSpacing: -0.2,
                                      color: kPaper,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Material 3 Stat Badges
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _MetricPill(
                                      label: '${engine.okCount} ok',
                                      color: kOk,
                                    ),
                                    const SizedBox(width: 5),
                                    _MetricPill(
                                      label: '${engine.failCount} down',
                                      color: engine.failCount > 0 ? kFail : kSubtle,
                                    ),
                                    const SizedBox(width: 5),
                                    _MetricPill(
                                      label: '${engine.checkedCount}/$totalDomains',
                                      color: kMute,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Material 3 Action Pills
                            _ActionPill(
                              label: isRunning ? 'pause' : 'run',
                              icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: isRunning ? kOk : kTo,
                              isTonalActive: isRunning,
                              onTap: () => engine.setRunning(!isRunning),
                            ),
                            const SizedBox(width: 5),
                            _ActionPill(
                              label: 'copy',
                              icon: Icons.copy_rounded,
                              color: kPaper,
                              onTap: () => copyReport(bCtx, engine),
                            ),
                            const SizedBox(width: 5),
                            _ActionPill(
                              label: 'set',
                              icon: Icons.tune_rounded,
                              color: kPaper,
                              onTap: () => _openSettings(bCtx),
                            ),
                            const SizedBox(width: 5),
                            _ActionPill(
                              label: '?',
                              icon: Icons.keyboard_outlined,
                              color: kMute,
                              onTap: () => _showHelp(bCtx),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                body: SafeArea(
                  child: ProbeBoard(engine: engine),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSettings(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surfaceContainerLow,
      barrierColor: const Color(0x99000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure probe timers, targeting, and exports',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: kMute,
                                fontSize: 11.5,
                              ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              Expanded(child: SettingsForm(engine: engine)),
            ],
          ),
        );
      },
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Space Mono',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isTonalActive = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isTonalActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bgColor = isTonalActive
        ? color.withValues(alpha: 0.16)
        : colorScheme.surfaceContainerHigh;

    final borderColor = isTonalActive
        ? color.withValues(alpha: 0.4)
        : colorScheme.outlineVariant;

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withValues(alpha: 0.15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.5, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
