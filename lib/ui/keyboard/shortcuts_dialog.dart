import 'package:flutter/material.dart';
import '../../theme.dart';

class ShortcutsCheatsheetDialog extends StatelessWidget {
  const ShortcutsCheatsheetDialog({super.key});
  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const ShortcutsCheatsheetDialog(),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Keyboard shortcuts'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in const {
            'Space / R': 'Pause or resume',
            'Ctrl + , / S': 'Open settings',
            'Ctrl + Shift + C': 'Preview a report',
            'P': 'Pin window (desktop)',
            'F1': 'Open this help',
            'Tab / Shift + Tab': 'Move between controls',
            'Enter': 'Activate a focused control',
          }.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key, style: mono)),
                  const SizedBox(width: 20),
                  Expanded(child: Text(entry.value)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Single-key commands stay inactive while typing. Controller X pauses/resumes; Y opens settings.',
            style: TextStyle(color: kMute),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
