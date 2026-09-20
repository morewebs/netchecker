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

    return Container(
      height: compact ? 28 : 32,
      decoration: const BoxDecoration(
        color: kInk,
        border: Border(
          bottom: BorderSide(
            color: kLine,
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
      child: Row(
        children: [
          // Flat Precision Status Indicator (No Neon Glow)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: running ? kOk : kTo,
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          // Title & Live Metrics (Poppins + Space Mono Tabular Figures)
          Expanded(
            child: _buildTitle(compact),
          ),
          const SizedBox(width: 8),

          // Instrument NIC Dropdown (if multiple NICs)
          if (nics.length > 1)
            Container(
              height: compact ? 20 : 22,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: kInk,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: kLine),
              ),
              child: PopupMenuButton<String>(
                tooltip: 'Select Network Interface',
                color: const Color(0xFF141418),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                  side: const BorderSide(color: kLine),
                ),
                initialValue: nics.any((n) => n.$1 == nicId) ? nicId : 'any',
                onSelected: onNic,
                itemBuilder: (ctx) => [
                  for (final n in nics)
                    PopupMenuItem<String>(
                      value: n.$1,
                      height: 30,
                      child: Row(
                        children: [
                          Icon(
                            n.$1 == nicId ? Icons.check_rounded : Icons.lan_outlined,
                            size: 13,
                            color: n.$1 == nicId ? kOk : kMute,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              n.$2,
                              style: TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 10.5,
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
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lan_outlined, size: 11, color: kMute),
                      const SizedBox(width: 5),
                      Text(
                        nics.firstWhere((n) => n.$1 == nicId, orElse: () => nics.first).$2,
                        style: const TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: kPaper,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_drop_down_rounded, size: 14, color: kMute),
                    ],
                  ),
                ),
              ),
            ),

          // Instrument Action Buttons
          _InstrumentToolbarButton(
            label: running ? 'pause' : 'run',
            icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
            tooltip: running ? 'Pause Probing (Space, R)' : 'Start Probing (Space, R)',
            activeColor: running ? kOk : kTo,
            isTonalActive: running,
            compact: compact,
            onTap: onToggleRun,
          ),
          const SizedBox(width: 4),
          _InstrumentToolbarButton(
            label: alwaysOnTop ? 'unpin' : 'pin',
            icon: alwaysOnTop ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            tooltip: alwaysOnTop ? 'Unpin Window (P)' : 'Pin Always on Top (P)',
            isTonalActive: alwaysOnTop,
            compact: compact,
            onTap: onTogglePin,
          ),
          const SizedBox(width: 4),
          _InstrumentToolbarButton(
            label: 'copy',
            icon: Icons.copy_rounded,
            tooltip: 'Copy Diagnostic Report (C)',
            compact: compact,
            onTap: onCopy,
          ),
          const SizedBox(width: 4),
          _InstrumentToolbarButton(
            label: 'set',
            icon: Icons.tune_rounded,
            tooltip: 'Settings (S)',
            compact: compact,
            onTap: onSettings,
          ),
          if (onHelp != null) ...[
            const SizedBox(width: 4),
            _InstrumentToolbarButton(
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

  Widget _buildTitle(bool compact) {
    final parts = title.split('  ');
    if (parts.length >= 4 && parts[0] == 'NetChecker') {
      final okPart = parts[1];
      final downPart = parts[2];
      final countPart = parts[3];
      final isDown = !downPart.startsWith('0 ');

      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'NetChecker',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: compact ? 11 : 12,
                letterSpacing: -0.2,
                color: kPaper,
              ),
            ),
            const TextSpan(text: '   '),
            TextSpan(
              text: okPart,
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w500,
                color: kOk,
              ),
            ),
            const TextSpan(text: '  '),
            TextSpan(
              text: downPart,
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w500,
                color: isDown ? kFail : kSubtle,
              ),
            ),
            const TextSpan(text: '  '),
            TextSpan(
              text: countPart,
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w400,
                color: kMute,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: compact ? 11 : 12,
        letterSpacing: -0.2,
        color: kPaper,
      ),
    );
  }
}

class _InstrumentToolbarButton extends StatelessWidget {
  const _InstrumentToolbarButton({
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
    final fg = activeColor ?? kPaper;

    final bgColor = isTonalActive
        ? (activeColor?.withValues(alpha: 0.12) ?? Colors.white.withValues(alpha: 0.05))
        : Colors.transparent;

    final borderColor = isTonalActive
        ? (activeColor?.withValues(alpha: 0.45) ?? kLine)
        : kLine;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          hoverColor: kPaper.withValues(alpha: 0.08),
          splashColor: fg.withValues(alpha: 0.15),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 2 : 3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 11.5 : 12.5, color: fg),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: compact ? 9.5 : 10.5,
                    fontWeight: FontWeight.w500,
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
