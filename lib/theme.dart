import 'package:flutter/material.dart';

import 'probe/models.dart';

/// THESIS: A running step-row instrument. The live cell is the chase light;
/// everything else is last-known truth. Not a card dashboard.
/// OWN-WORLD: moreweb.ir Poppins + Space Mono on rgb(3,0,5). Hairline grid,
/// no neon, no glow, no gradient type. Status is type, not decoration.
/// STORY: An engineer glances and knows what the tunnel is doing right now.
/// FIRST VIEWPORT: DNS row, proto/edge/hunt strips, then the site grid.
/// FORM: bench step-row (seed 7261d2de) raised with chase-light discipline.
/// FINISH: unreviewed and undocumented is unfinished; this build ends with
/// the finish review, the verdict, DESIGN.md, and every shipping raster
/// carrying its provenance.

const Color kInk = Color(0xFF09090B); // zinc-950 background
const Color kCard = Color(0xFF121215); // zinc-900 card surface
const Color kCardMuted = Color(0xFF18181B); // zinc-900 border/hover surface
const Color kPaper = Color(0xFFF4F4F5); // zinc-100 primary text
const Color kMute = Color(0xFFA1A1AA); // zinc-400 muted text
const Color kSubtle = Color(0xFF71717A); // zinc-500 subtle metadata
const Color kLine = Color(0xFF27272A); // zinc-800 border
const Color kOk = Color(0xFF10B981); // emerald-500
const Color kTo = Color(0xFFF59E0B); // amber-500
const Color kFail = Color(0xFFF43F5E); // rose-500
const Color kLive = Color(0xFFFAFAFA); // zinc-50
const Color kPoison = Color(0xFFFFD600); // electric yellow

ThemeData buildTheme({required bool compact}) {
  const family = 'Poppins';
  final scheme = const ColorScheme.dark(
    primary: kPaper,
    onPrimary: kInk,
    primaryContainer: Color(0xFF272730),
    onPrimaryContainer: Color(0xFFF4F4F5),
    secondary: kMute,
    onSecondary: kInk,
    secondaryContainer: Color(0xFF1E1E24),
    onSecondaryContainer: Color(0xFFE4E4E7),
    surface: kInk,
    onSurface: kPaper,
    error: kFail,
    onError: kPaper,
    errorContainer: Color(0xFF381219),
    onErrorContainer: Color(0xFFFECDD3),
    outline: kLine,
    outlineVariant: Color(0xFF1F1F24),
    surfaceContainerLowest: Color(0xFF070509),
    surfaceContainerLow: Color(0xFF0F0F12),
    surfaceContainer: Color(0xFF141418),
    surfaceContainerHigh: Color(0xFF1A1A20),
    surfaceContainerHighest: Color(0xFF24242B),
  );

  final text = TextTheme(
    displayLarge: TextStyle(
      fontFamily: family,
      fontWeight: FontWeight.w700,
      fontSize: compact ? 22 : 28,
      height: 1.15,
      letterSpacing: -0.5,
      color: kPaper,
    ),
    titleLarge: TextStyle(
      fontFamily: family,
      fontWeight: FontWeight.w600,
      fontSize: compact ? 16 : 18,
      height: 1.25,
      letterSpacing: -0.3,
      color: kPaper,
    ),
    titleMedium: TextStyle(
      fontFamily: family,
      fontWeight: FontWeight.w600,
      fontSize: compact ? 13 : 14,
      height: 1.25,
      letterSpacing: -0.2,
      color: kPaper,
    ),
    titleSmall: TextStyle(
      fontFamily: family,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1.25,
      letterSpacing: -0.1,
      color: kPaper,
    ),
    bodyLarge: TextStyle(
      fontFamily: family,
      fontWeight: FontWeight.w400,
      fontSize: compact ? 13 : 14,
      height: 1.4,
      color: kPaper,
    ),
    bodyMedium: TextStyle(
      fontFamily: family,
      fontWeight: FontWeight.w400,
      fontSize: compact ? 12 : 13,
      height: 1.4,
      color: kPaper,
    ),
    bodySmall: TextStyle(
      fontFamily: family,
      fontWeight: FontWeight.w400,
      fontSize: 11,
      height: 1.35,
      color: kMute,
    ),
    labelLarge: TextStyle(
      fontFamily: family,
      fontWeight: FontWeight.w500,
      fontSize: 13,
      height: 1.2,
      letterSpacing: 0.1,
      color: kPaper,
    ),
    labelMedium: TextStyle(
      fontFamily: family,
      fontWeight: FontWeight.w500,
      fontSize: 11,
      letterSpacing: 0.3,
      height: 1.2,
      color: kMute,
    ),
    labelSmall: const TextStyle(
      fontFamily: 'Space Mono',
      fontWeight: FontWeight.w400,
      fontSize: 11,
      height: 1.2,
      color: kPaper,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: kInk,
    canvasColor: kInk,
    cardColor: const Color(0xFF141418),
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: kInk,
      foregroundColor: kPaper,
      elevation: 0,
      scrolledUnderElevation: 1.5,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: compact ? 44 : 52,
      titleTextStyle: text.titleMedium,
    ),
    dividerColor: const Color(0xFF1F1F24),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF1F1F24),
      space: 1,
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: kPaper, size: 18),
    cardTheme: CardThemeData(
      color: const Color(0xFF141418),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF222228), width: 1),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1B1B22),
      contentTextStyle: text.bodyMedium?.copyWith(color: kPaper),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF272730)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF101014),
      modalBackgroundColor: Color(0xFF101014),
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      showDragHandle: true,
      dragHandleColor: Color(0xFF52525B),
      dragHandleSize: Size(36, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF141418),
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFF222228), width: 1),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xFF1A1A20),
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF272730)),
      ),
      textStyle: text.bodySmall?.copyWith(color: kPaper, fontWeight: FontWeight.w500),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xFF1A1A20)),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(4),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF272730)),
          ),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF24242B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF383842)),
      ),
      textStyle: text.bodySmall?.copyWith(color: kPaper, fontSize: 11),
      waitDuration: const Duration(milliseconds: 350),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF18181E),
      surfaceTintColor: Colors.transparent,
      side: const BorderSide(color: Color(0xFF26262D)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: text.labelSmall?.copyWith(color: kPaper),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF121216),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF272730)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF272730)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPaper, width: 1.5),
      ),
      labelStyle: text.bodySmall?.copyWith(color: kMute),
      hintStyle: text.bodySmall?.copyWith(color: kSubtle),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        return s.contains(WidgetState.selected) ? kInk : kMute;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        return s.contains(WidgetState.selected) ? kPaper : const Color(0xFF272730);
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: kPaper,
      inactiveTrackColor: const Color(0xFF272730),
      thumbColor: kPaper,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      trackHeight: 4,
      overlayColor: const Color(0x22FFFFFF),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPaper,
        minimumSize: const Size(44, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPaper,
        foregroundColor: kInk,
        minimumSize: const Size(48, 40),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: kInk),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPaper,
        minimumSize: const Size(48, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        side: const BorderSide(color: Color(0xFF272730), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
    ),
  );
}

Color statusColor(HitStatus status) {
  switch (status) {
    case HitStatus.ok:
      return kOk;
    case HitStatus.timeout:
      return kTo;
    case HitStatus.fail:
      return kFail;
    case HitStatus.checking:
      return kLive;
    case HitStatus.idle:
      return kMute;
  }
}
