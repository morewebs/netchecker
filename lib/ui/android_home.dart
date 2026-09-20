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
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: kInk,
                      border: Border(
                        bottom: BorderSide(
                          color: kLine,
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            // Brand & Live Status Dot (Flat Precision, No Glow)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isRunning ? kOk : kTo,
                                    borderRadius: BorderRadius.circular(1),
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

                            // Inline Telemetry Readout (Space Mono Tabular Figures)
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${engine.okCount} ok',
                                      style: const TextStyle(
                                        fontFamily: 'Space Mono',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: kOk,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 5),
                                      child: Text(
                                        '·',
                                        style: TextStyle(
                                          color: kLine,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${engine.failCount} down',
                                      style: TextStyle(
                                        fontFamily: 'Space Mono',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: engine.failCount > 0 ? kFail : kSubtle,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 5),
                                      child: Text(
                                        '·',
                                        style: TextStyle(
                                          color: kLine,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${engine.checkedCount}/$totalDomains',
                                      style: const TextStyle(
                                        fontFamily: 'Space Mono',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w400,
                                        color: kMute,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Instrument Action Buttons
                            _InstrumentAction(
                              label: isRunning ? 'pause' : 'run',
                              icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: isRunning ? kOk : kTo,
                              isActive: isRunning,
                              onTap: () => engine.setRunning(!isRunning),
                            ),
                            const SizedBox(width: 4),
                            _InstrumentAction(
                              label: 'copy',
                              icon: Icons.copy_rounded,
                              color: kPaper,
                              onTap: () => copyReport(bCtx, engine),
                            ),
                            const SizedBox(width: 4),
                            _InstrumentAction(
                              label: 'set',
                              icon: Icons.tune_rounded,
                              color: kPaper,
                              onTap: () => _openSettings(bCtx),
                            ),
                            const SizedBox(width: 4),
                            _InstrumentAction(
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF101014),
      barrierColor: const Color(0x99000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: kLine, width: 1),
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
                      icon: const Icon(Icons.close_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF18181B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: const BorderSide(color: kLine),
                        ),
                        padding: const EdgeInsets.all(6),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: SettingsForm(engine: engine)),
            ],
          ),
        );
      },
    );
  }
}

class _InstrumentAction extends StatelessWidget {
  const _InstrumentAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 32, minHeight: 48),
      child: Center(
        child: Material(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: BorderSide(
              color: isActive ? color.withValues(alpha: 0.45) : kLine,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(2),
            splashColor: color.withValues(alpha: 0.15),
            hoverColor: kPaper.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
