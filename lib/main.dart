import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'probe/engine.dart';
import 'theme.dart';
import 'ui/desk_window.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: kInk,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final engine = ProbeEngine();
  runApp(NetCheckerApp(engine: engine));
  unawaited(
    engine.start().then((_) async {
      if (Platform.isWindows || Platform.isLinux) {
        await DeskWindow.setAlwaysOnTop(engine.settings.alwaysOnTop);
        await DeskWindow.setCompact(engine.settings.compactMode);
      }
    }),
  );
}
