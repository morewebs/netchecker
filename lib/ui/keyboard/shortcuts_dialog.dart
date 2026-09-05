import 'package:flutter/material.dart';

import '../../theme.dart';

class ShortcutsCheatsheetDialog extends StatelessWidget {
  const ShortcutsCheatsheetDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x99000000),
      builder: (ctx) => const ShortcutsCheatsheetDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surfaceContainerHigh,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Material 3 Dialog Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: const Icon(
                    Icons.keyboard_outlined,
                    size: 22,
                    color: kPaper,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keyboard & Controller Shortcuts',
                        style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.5,
                              color: kPaper,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Navigate and control NetChecker via keyboard or gamepad',
                        style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              color: kMute,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 14),

            // Scrollable Sections
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    _SectionHeader(title: 'GLOBAL CONTROLS'),
                    _ShortcutRow(
                      action: 'Start / Pause Probe Loops',
                      keyboard: ['Space', 'R'],
                      controller: 'X / Play-Pause',
                    ),
                    _ShortcutRow(
                      action: 'Open Settings',
                      keyboard: ['S', 'Ctrl+,'],
                      controller: 'Y / Menu',
                    ),
                    _ShortcutRow(
                      action: 'Copy Reachability Report',
                      keyboard: ['C', 'Ctrl+C'],
                      controller: 'L-Stick Click',
                    ),
                    _ShortcutRow(
                      action: 'Toggle Always-on-Top Pin',
                      keyboard: ['P'],
                      controller: '—',
                    ),
                    _ShortcutRow(
                      action: 'Dismiss / Go Back / Clear Focus',
                      keyboard: ['Esc', 'Backspace'],
                      controller: 'B / Back',
                    ),
                    _ShortcutRow(
                      action: 'Open this Cheatsheet',
                      keyboard: ['?', 'F1'],
                      controller: 'Select / Guide',
                    ),
                    SizedBox(height: 16),

                    _SectionHeader(title: 'GRID 2D NAVIGATION'),
                    _ShortcutRow(
                      action: 'Traverse Cells & Toolbar',
                      keyboard: ['↑ ↓ ← →', 'H J K L'],
                      controller: 'D-Pad / L-Stick',
                    ),
                    _ShortcutRow(
                      action: 'Open Item Telemetry Profile',
                      keyboard: ['Enter', 'Space'],
                      controller: 'A / Select',
                    ),
                    _ShortcutRow(
                      action: 'Run Traceroute on Cell',
                      keyboard: ['T'],
                      controller: 'R-Stick Click',
                    ),
                    _ShortcutRow(
                      action: 'Copy Focused Cell Readout',
                      keyboard: ['C'],
                      controller: 'L-Stick Click',
                    ),
                    SizedBox(height: 16),

                    _SectionHeader(title: 'ITEM PROFILE PAGE'),
                    _ShortcutRow(
                      action: 'Immediate Ping Now (Deep Probe)',
                      keyboard: ['R', 'Enter'],
                      controller: 'A / X',
                    ),
                    _ShortcutRow(
                      action: 'Launch Route Map Traceroute',
                      keyboard: ['T'],
                      controller: 'Y',
                    ),
                    _ShortcutRow(
                      action: 'Toggle Auto Live Monitor',
                      keyboard: ['A'],
                      controller: '—',
                    ),
                    _ShortcutRow(
                      action: 'Switch History / Histogram Tabs',
                      keyboard: ['1', '2', '[ ]'],
                      controller: 'LB / RB (L1/R1)',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Space Mono',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: kPaper,
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.action,
    required this.keyboard,
    required this.controller,
  });

  final String action;
  final List<String> keyboard;
  final String controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              action,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: kPaper,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Controller Badge
          if (controller != '—') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kOk.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kOk.withValues(alpha: 0.3)),
              ),
              child: Text(
                '🎮 $controller',
                style: const TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: kOk,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Keyboard Badges
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final k in keyboard)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kPaper.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      k,
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: kPaper,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
