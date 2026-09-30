import 'dart:io';
import 'package:flutter/material.dart';
import 'probe/engine.dart';
import 'theme.dart';
import 'ui/android_home.dart';
import 'ui/desktop_home.dart';

class NetCheckerApp extends StatefulWidget {
  const NetCheckerApp({super.key, required this.engine, this.forceDesktop});
  final ProbeEngine engine;
  final bool? forceDesktop;
  @override
  State<NetCheckerApp> createState() => _NetCheckerAppState();
}

class _NetCheckerAppState extends State<NetCheckerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isAndroid) {
      if (state == AppLifecycleState.resumed) widget.engine.setForeground(true);
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        widget.engine.setForeground(false);
      }
    } else if (state == AppLifecycleState.resumed) {
      widget.engine.refreshNics();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NetChecker',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    themeMode: ThemeMode.dark,
    home: (widget.forceDesktop ?? (Platform.isWindows || Platform.isLinux))
        ? DesktopHome(engine: widget.engine)
        : AndroidHome(engine: widget.engine),
  );
}
