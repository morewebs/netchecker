import 'package:flutter/material.dart';
import 'probe/models.dart';

// A working monitor beside a terminal or VPN client: quiet surfaces, readable
// labels, tabular measurements, and movement only when a check changes state.
const kInk = Color(0xFF101114);
const kCard = Color(0xFF191B20);
const kCardMuted = Color(0xFF22252B);
const kPaper = Color(0xFFF1F2F4);
const kMute = Color(0xFFA8ADB8);
const kSubtle = Color(0xFF989EAA);
const kLine = Color(0xFF30343C);
const kOk = Color(0xFF99C7AA);
const kTo = Color(0xFFE0BC7A);
const kFail = Color(0xFFEE9A9A);
const kLive = kPaper;

Color statusColor(HitStatus status) => switch (status) {
  HitStatus.ok => kOk,
  HitStatus.timeout => kTo,
  HitStatus.fail => kFail,
  HitStatus.checking => kPaper,
  _ => kMute,
};
const mono = TextStyle(
  fontFamily: 'Space Mono',
  fontSize: 12,
  fontFeatures: [FontFeature.tabularFigures()],
);

ThemeData buildTheme({bool compact = false}) {
  final scheme = const ColorScheme.dark(
    primary: kPaper,
    onPrimary: kInk,
    secondary: kOk,
    onSecondary: kInk,
    surface: kInk,
    onSurface: kPaper,
    surfaceContainerLow: kCard,
    surfaceContainer: kCard,
    surfaceContainerHigh: kCardMuted,
    onSurfaceVariant: kMute,
    outline: kMute,
    outlineVariant: kLine,
    error: kFail,
    onError: kInk,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Poppins',
    colorScheme: scheme,
    scaffoldBackgroundColor: kInk,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -.5,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(fontSize: 14, height: 1.5),
      bodyMedium: TextStyle(fontSize: 13, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, height: 1.45, color: kMute),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    dividerTheme: const DividerThemeData(color: kLine, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: kInk,
      foregroundColor: kPaper,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: kMute,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: kPaper,
        side: const BorderSide(color: kLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPaper),
      ),
      hintStyle: const TextStyle(color: kMute, fontSize: 13),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kCard,
      selectedColor: kCardMuted,
      side: const BorderSide(color: kLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kCardMuted,
      contentTextStyle: TextStyle(color: kPaper),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(kLine),
      radius: const Radius.circular(4),
    ),
  );
}
