import 'package:flutter/material.dart';

import '../theme.dart';

class DesktopToolbar extends StatelessWidget {
  const DesktopToolbar({
    super.key,
    required this.title,
    required this.alwaysOnTop,
    required this.running,
    required this.nics,
    required this.nicId,
    required this.onToggleRun,
    required this.onTogglePin,
    required this.onCopy,
    required this.onSettings,
    required this.onNic,
    this.onHelp,
  });

  final String title;
  final bool alwaysOnTop;
  final bool running;
  final List<(String id, String label)> nics;
  final String nicId;
  final VoidCallback onToggleRun;
  final VoidCallback onTogglePin;
  final VoidCallback onCopy;
  final VoidCallback onSettings;
  final ValueChanged<String> onNic;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final compact = alwaysOnTop;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: compact ? 42 : 50,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
      child: Row(
        children: [
          // Live Status Beacon
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: running ? kOk : kTo,
              shape: BoxShape.circle,
              boxShadow: running
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

          // Title & Live Metrics
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: compact ? 11.5 : 13,
                letterSpacing: -0.2,
                color: kPaper,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Material 3 NIC Dropdown Menu (if multiple NICs)
          if (nics.length > 1)
            Container(
              height: compact ? 28 : 32,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: PopupMenuButton<String>(
                tooltip: 'Select Network Interface',
                color: const Color(0xFF1A1A20),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                initialValue: nics.any((n) => n.$1 == nicId) ? nicId : 'any',
                onSelected: onNic,
                itemBuilder: (ctx) => [
                  for (final n in nics)
                    PopupMenuItem<String>(
                      value: n.$1,
                      height: 38,
                      child: Row(
                        children: [
                          Icon(
                            n.$1 == nicId ? Icons.check_rounded : Icons.lan_outlined,
                            size: 14,
                            color: n.$1 == nicId ? kOk : kMute,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              n.$2,
                              style: TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 11,
                                fontWeight: n.$1 == nicId ? FontWeight.w600 : FontWeight.w400,
                                color: n.$1 == nicId ? kPaper : kMute,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lan_outlined, size: 13, color: kMute),
                      const SizedBox(width: 6),
                      Text(
                        nics.firstWhere((n) => n.$1 == nicId, orElse: () => nics.first).$2,
                        style: const TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: kPaper,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, size: 16, color: kMute),
                    ],
                  ),
                ),
              ),
            ),

          // Material 3 Action Buttons
          _M3ToolbarButton(
            label: running ? 'pause' : 'run',
            icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
            tooltip: running ? 'Pause Probing (Space, R)' : 'Start Probing (Space, R)',
            activeColor: running ? kOk : kTo,
            isTonalActive: running,
            compact: compact,
            onTap: onToggleRun,
          ),
          const SizedBox(width: 5),
          _M3ToolbarButton(
            label: alwaysOnTop ? 'unpin' : 'pin',
            icon: alwaysOnTop ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            tooltip: alwaysOnTop ? 'Unpin Window (P)' : 'Pin Always on Top (P)',
            compact: compact,
            onTap: onTogglePin,
          ),
          const SizedBox(width: 5),
          _M3ToolbarButton(
            label: 'copy',
            icon: Icons.copy_rounded,
            tooltip: 'Copy Diagnostic Report (C)',
            compact: compact,
            onTap: onCopy,
          ),
          const SizedBox(width: 5),
          _M3ToolbarButton(
            label: 'set',
            icon: Icons.tune_rounded,
            tooltip: 'Settings (S)',
            compact: compact,
            onTap: onSettings,
          ),
          if (onHelp != null) ...[
            const SizedBox(width: 5),
            _M3ToolbarButton(
              label: '?',
              icon: Icons.keyboard_outlined,
              tooltip: 'Keyboard & Controller Shortcuts (?)',
              compact: compact,
              onTap: onHelp!,
            ),
          ],
        ],
      ),
    );
  }
}

class _M3ToolbarButton extends StatelessWidget {
  const _M3ToolbarButton({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.activeColor,
    this.isTonalActive = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? activeColor;
  final bool isTonalActive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fg = activeColor ?? kPaper;

    final bgColor = isTonalActive
        ? (activeColor?.withValues(alpha: 0.14) ?? colorScheme.surfaceContainerHighest)
        : colorScheme.surfaceContainerHigh;

    final borderColor = isTonalActive
        ? (activeColor?.withValues(alpha: 0.35) ?? colorScheme.outlineVariant)
        : colorScheme.outlineVariant;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          hoverColor: kPaper.withValues(alpha: 0.08),
          splashColor: fg.withValues(alpha: 0.15),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 11,
              vertical: compact ? 5 : 7,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 13 : 15, color: fg),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
