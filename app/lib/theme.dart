import 'package:flutter/material.dart';

/// SAPPAN SAREES couture theme (owner 25-Oct-2026: "super premium, luxury
/// from every angle"; redesign 27-Oct with the ui-ux-pro-max "luxury fashion"
/// system): warm ivory paper, deep wine-maroon as the house colour, champagne
/// gold used sparingly as hairlines and eyebrows, Cormorant Garamond display
/// over a quiet Jost body, sharp couture corners. The saree photos stay the hero.
const Color kInk = Color(0xFF221A17); // espresso ink (body text)
const Color kInkSoft = Color(0xFF6E625B); // secondary text (4.9:1 on paper)
const Color kMaroon = Color(0xFF5E0B1F); // house colour — deep wine
const Color kMaroonDeep = Color(0xFF3F0614);
const Color kGold = Color(0xFFB08A45); // champagne gold accent
const Color kGoldSoft = Color(0xFFE9D9B4);
const Color kPaper = Color(0xFFFFFCF7); // warm ivory paper
const Color kHairline = Color(0xFFEADFCB); // soft champagne hairline
const Color kLinen = Color(0xFFF6EFE3); // champagne linen fill

/// Display serif (headings, wordmark) and body sans.
const String kSerif = 'Cormorant';
const String kSans = 'Jost';

/// Tracked uppercase eyebrow label in gold (section kickers).
const TextStyle kEyebrow =
    TextStyle(fontFamily: kSans, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 3.8, color: kGold);

/// Prices: quiet sans with tabular lining figures.
const TextStyle kPriceStyle = TextStyle(
    fontFamily: kSans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    color: kInk,
    fontFeatures: [FontFeature.tabularFigures()]);

const _sharp = RoundedRectangleBorder(); // couture: square corners

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kMaroon,
    brightness: Brightness.light,
  ).copyWith(
    primary: kMaroon,
    onPrimary: kPaper,
    secondary: kGold,
    onSecondary: Colors.white,
    surface: kPaper,
    onSurface: kInk,
    onSurfaceVariant: kInkSoft,
    surfaceContainerLowest: const Color(0xFFFFFDF9),
    surfaceContainerLow: kLinen,
    surfaceContainerHighest: const Color(0xFFF1E6D2),
    outline: const Color(0xFFB89A66),
    outlineVariant: kHairline,
    tertiary: kGold,
    primaryContainer: kMaroon, // selected chips read as wine labels
    onPrimaryContainer: kPaper,
  );

  // Chip text flips to ivory when the chip is selected (wine label).
  final chipLabelColor = WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected) ? kPaper : kInk);

  const lining = [FontFeature.liningFigures()];

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kSans,
    scaffoldBackgroundColor: kPaper,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: kPaper,
      foregroundColor: kMaroon,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      shape: Border(bottom: BorderSide(color: kHairline, width: 1)),
      // Serif masthead; all copy renders uppercase (UText).
      titleTextStyle: TextStyle(
        fontFamily: kSerif,
        color: kMaroon,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.4,
        fontFeatures: lining,
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
          fontFamily: kSerif, fontWeight: FontWeight.w600, color: kMaroon, height: 1.1, fontFeatures: lining),
      titleLarge: TextStyle(
          fontFamily: kSerif,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: kMaroon,
          fontFeatures: lining),
      titleMedium: TextStyle(
          fontFamily: kSerif,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: kInk,
          fontFeatures: lining),
      // Eyebrow labels (section headers like CATEGORY / PRICE RANGE) stay in
      // tracked-out sans — the classic pairing under a serif display face.
      titleSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.8, color: kInk),
      bodyLarge: TextStyle(fontSize: 15.5, height: 1.55, color: kInk),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: kInk),
      bodySmall: TextStyle(fontSize: 12.5, letterSpacing: 0.4, color: kInkSoft),
      labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 2),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: kPaper,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(side: BorderSide(color: kHairline, width: 1)),
      clipBehavior: Clip.antiAlias,
    ),
    chipTheme: ChipThemeData(
      side: const BorderSide(color: kHairline, width: 1),
      backgroundColor: kPaper,
      selectedColor: kMaroon,
      checkmarkColor: kPaper,
      showCheckmark: false,
      shape: _sharp,
      labelStyle: TextStyle(
        color: chipLabelColor,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.6,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Color(0xFFFFFDF9),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: kInkSoft, letterSpacing: 0.6),
      floatingLabelStyle: TextStyle(color: kMaroon, letterSpacing: 1.2),
      border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: kHairline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: kHairline)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: kMaroon, width: 1.2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kMaroon,
        foregroundColor: kPaper,
        disabledBackgroundColor: const Color(0xFFE3D8C6),
        disabledForegroundColor: kInkSoft,
        elevation: 0,
        shape: _sharp,
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontFamily: kSans, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 3),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kMaroon,
        shape: _sharp,
        textStyle: const TextStyle(fontFamily: kSans, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kMaroon,
        side: const BorderSide(color: kMaroon, width: 1),
        shape: _sharp,
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontFamily: kSans, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 2.4),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kMaroon, linearTrackColor: kLinen),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kMaroonDeep,
      contentTextStyle: TextStyle(fontFamily: kSans, color: kPaper, letterSpacing: 0.4),
      behavior: SnackBarBehavior.floating,
      shape: _sharp,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: kPaper,
      surfaceTintColor: kPaper,
      shape: _sharp,
      titleTextStyle: TextStyle(
          fontFamily: kSerif,
          fontSize: 25,
          fontWeight: FontWeight.w600,
          color: kMaroon,
          letterSpacing: 0.4,
          fontFeatures: lining),
    ),
    badgeTheme: const BadgeThemeData(
        backgroundColor: kMaroon, textColor: kPaper, textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kMaroon,
      foregroundColor: kPaper,
      elevation: 2,
      shape: _sharp,
      extendedTextStyle: TextStyle(fontFamily: kSans, fontWeight: FontWeight.w600, letterSpacing: 2.4),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      dragHandleColor: kHairline,
      backgroundColor: kPaper,
      surfaceTintColor: kPaper,
      shape: _sharp,
    ),
    dividerTheme: const DividerThemeData(color: kHairline, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(iconColor: kMaroon),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(),
      side: const BorderSide(color: kGold, width: 1.2),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kMaroon : null),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kPaper,
      surfaceTintColor: kPaper,
      elevation: 0,
      height: 66,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? kMaroon : const Color(0xFF9A8C82), size: 22)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontFamily: kSans,
          fontSize: 9.5,
          letterSpacing: 1.8,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? kMaroon : const Color(0xFF9A8C82))),
    ),
    iconTheme: const IconThemeData(color: kMaroon),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
