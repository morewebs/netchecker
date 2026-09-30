import 'package:flutter/material.dart';
import '../probe/engine.dart';
import 'monitor_screen.dart';

class AndroidHome extends StatelessWidget {
  const AndroidHome({super.key, required this.engine});
  final ProbeEngine engine;
  @override
  Widget build(BuildContext context) =>
      MonitorScreen(engine: engine, desktop: false);
}
