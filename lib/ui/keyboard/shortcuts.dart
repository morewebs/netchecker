import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _Command extends Intent {
  const _Command(this.name);
  final String name;
}

class _TextSafeAction extends Action<_Command> {
  _TextSafeAction(this.callbacks);
  final Map<String, VoidCallback?> callbacks;
  @override
  bool isEnabled(_Command intent) {
    final focus = FocusManager.instance.primaryFocus?.context;
    final editing =
        focus?.widget is EditableText ||
        focus?.findAncestorStateOfType<EditableTextState>() != null;
    return !editing && callbacks[intent.name] != null;
  }

  @override
  Object? invoke(_Command intent) {
    callbacks[intent.name]?.call();
    return null;
  }
}

class AppShortcutsWrapper extends StatelessWidget {
  const AppShortcutsWrapper({
    super.key,
    required this.child,
    required this.onToggleRun,
    required this.onOpenSettings,
    required this.onCopyReport,
    required this.onShowHelp,
    this.onTogglePin,
    this.onEscape,
  });
  final Widget child;
  final VoidCallback onToggleRun, onOpenSettings, onCopyReport, onShowHelp;
  final VoidCallback? onTogglePin, onEscape;
  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.space): _Command('run'),
      SingleActivator(LogicalKeyboardKey.keyR): _Command('run'),
      SingleActivator(LogicalKeyboardKey.comma, control: true): _Command(
        'settings',
      ),
      SingleActivator(LogicalKeyboardKey.keyS): _Command('settings'),
      SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true):
          _Command('report'),
      SingleActivator(LogicalKeyboardKey.keyP): _Command('pin'),
      SingleActivator(LogicalKeyboardKey.f1): _Command('help'),
      SingleActivator(LogicalKeyboardKey.gameButtonX): _Command('run'),
      SingleActivator(LogicalKeyboardKey.gameButtonY): _Command('settings'),
      SingleActivator(LogicalKeyboardKey.gameButtonSelect): _Command('help'),
      SingleActivator(LogicalKeyboardKey.escape): _Command('escape'),
    },
    child: Actions(
      actions: {
        _Command: _TextSafeAction({
          'run': onToggleRun,
          'settings': onOpenSettings,
          'report': onCopyReport,
          'pin': onTogglePin,
          'help': onShowHelp,
          'escape': onEscape,
        }),
      },
      child: Focus(autofocus: true, child: child),
    ),
  );
}
