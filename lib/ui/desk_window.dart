import 'package:flutter/services.dart';

class DeskWindow {
  static const _ch = MethodChannel('netchecker/window');

  static Future<bool> setAlwaysOnTop(bool on) async {
    try {
      await _ch.invokeMethod<void>('setAlwaysOnTop', on);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setCompact(bool on) async {
    try {
      await _ch.invokeMethod<void>('setCompact', on);
      return true;
    } catch (_) {
      return false;
    }
  }
}
