import 'package:flutter/material.dart';

import '../probe/engine.dart';
import '../theme.dart';
import 'board.dart';
import 'desk_window.dart';
import 'keyboard/shortcuts.dart';
import 'keyboard/shortcuts_dialog.dart';
import 'settings_form.dart';
import 'title_bar.dart';

class DesktopHome extends StatelessWidget {
  const DesktopHome({super.key, required this.engine});

  final ProbeEngine engine;

  Future<void> _pin(bool on) async {
    await engine.setAlwaysOnTop(on);
    await DeskWindow.setAlwaysOnTop(on);
    await DeskWindow.setCompact(on);
  }

  void _showHelp(BuildContext context) {
    ShortcutsCheatsheetDialog.show(context);
  }

  Future<void> _settings(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      pageBuilder: (ctx, a, b) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: colorScheme.surfaceContainerLow,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
              side: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
            child: Container(
              width: 400,
              height: MediaQuery.sizeOf(ctx).height,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: const Icon(Icons.tune_rounded, size: 18, color: kPaper),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settings',
                                style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Configure probe timers, targeting, and exports',
                                style: theme.textTheme.bodySmall?.copyWith(
                                      color: kMute,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: colorScheme.outlineVariant),
                            ),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  Expanded(
                    child: SettingsForm(
                      engine: engine,
                      showWindowControls: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final compact = engine.settings.alwaysOnTop;
        return Builder(
          builder: (bCtx) {
            return AppShortcutsWrapper(
              onToggleRun: () => engine.setRunning(!engine.settings.running),
              onOpenSettings: () => _settings(bCtx),
              onCopyReport: () => copyReport(bCtx, engine),
              onTogglePin: () => _pin(!compact),
              onShowHelp: () => _showHelp(bCtx),
              child: Material(
                color: kInk,
                child: Column(
                  children: [
                    DesktopToolbar(
                      title:
                          'NetChecker  ${engine.okCount} ok  ${engine.failCount} down  ${engine.checkedCount}/${engine.domains.length}',
                      alwaysOnTop: compact,
                      running: engine.settings.running,
                      nics: [for (final n in engine.nics) (n.id, n.label)],
                      nicId: engine.settings.nicId,
                      onToggleRun: () => engine.setRunning(!engine.settings.running),
                      onTogglePin: () => _pin(!compact),
                      onCopy: () => copyReport(bCtx, engine),
                      onSettings: () => _settings(bCtx),
                      onHelp: () => _showHelp(bCtx),
                      onNic: engine.setNic,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ProbeBoard(engine: engine, compact: compact),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
