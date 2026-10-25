import 'package:flutter/material.dart';

/// SAPPAN SAREES couture theme (owner 25-Oct-2026: "super premium, luxury
/// from every angle"): warm ivory paper, deep wine-maroon as the house colour
/// (buttons, selected states, wordmark), champagne-gold hairlines and accents,
/// serif display type with generous tracking. The saree photos stay the hero.
const Color kInk = Color(0xFF221A17); // espresso ink (body text)
const Color kMaroon = Color(0xFF5E0B1F); // house colour — deep wine
const Color kMaroonDeep = Color(0xFF3F0614);
const Color kGold = Color(0xFFC6A15B); // champagne gold accent
const Color kGoldSoft = Color(0xFFE9D9B4);
const Color kPaper = Color(0xFFFFFCF7); // warm ivory paper
const Color kHairline = Color(0xFFE6D6B8); // gold-tinted hairline border
const Color kLinen = Color(0xFFF8F1E4); // champagne linen fill

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kMaroon,
    brightness: Brightness.light,
  ).copyWith(
    primary: kMaroon,
    onPrimary: Colors.white,
    secondary: kGold,
    onSecondary: Colors.white,
    surface: kPaper,
    onSurface: kInk,
    surfaceContainerLowest: const Color(0xFFFFFDF9),
    surfaceContainerLow: kLinen,
    surfaceContainerHighest: const Color(0xFFF1E6D2),
    outline: const Color(0xFFB89A66),
    outlineVariant: kHairline,
    tertiary: kGold,
    primaryContainer: kMaroon, // selected chips read as wine labels
    onPrimaryContainer: Colors.white,
  );

  // Chip text flips to white when the chip is selected (black pill).
  final chipLabelColor = WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected) ? Colors.white : kInk);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kPaper,
    appBarTheme: const AppBarTheme(
      backgroundColor: kPaper,
      foregroundColor: kMaroon,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // A single champagne-gold hairline under every header.
      shape: Border(bottom: BorderSide(color: kGold, width: 0.8)),
      // Serif display type — the fashion-editorial wordmark look. All copy
      // renders uppercase (UText), so this reads like a magazine masthead.
      // liningFigures: Playfair's default digits are old-style (small, low-
      // hanging) which misalign next to capitals — force full-height digits.
      titleTextStyle: TextStyle(
        fontFamily: 'Playfair',
        color: kMaroon,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        fontFeatures: [FontFeature.liningFigures()],
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
          fontFamily: 'Playfair',
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: kMaroon,
          fontFeatures: [FontFeature.liningFigures()]),
      titleMedium: TextStyle(
          fontFamily: 'Playfair',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: kInk,
          fontFeatures: [FontFeature.liningFigures()]),
      // Eyebrow labels (section headers like CATEGORY / PRICE RANGE) stay in
      // tracked-out sans — the classic pairing under a serif display face.
      titleSmall: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.6,
          color: kInk),
      bodySmall: TextStyle(letterSpacing: 0.6),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: kPaper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: kHairline, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    chipTheme: ChipThemeData(
      side: const BorderSide(color: kGold, width: 0.8),
      backgroundColor: kPaper,
      selectedColor: kMaroon,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      labelStyle: TextStyle(
        color: chipLabelColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFFFFDF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: kHairline, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: kHairline, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: kMaroon, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kMaroon,
        foregroundColor: kGoldSoft,
        disabledBackgroundColor: const Color(0xFFD9CBB3),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: kGold, width: 0.8)),
        textStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2.2),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kMaroon,
        textStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kMaroon,
        side: const BorderSide(color: kGold, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.6),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kMaroon),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kMaroonDeep,
      contentTextStyle: TextStyle(color: kGoldSoft, letterSpacing: 0.4),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kPaper,
      surfaceTintColor: kPaper,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kGold, width: 0.8)),
      titleTextStyle: const TextStyle(
          fontFamily: 'Playfair',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: kMaroon,
          letterSpacing: 0.6),
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: kGold, textColor: kMaroonDeep),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kMaroon,
      foregroundColor: kGoldSoft,
      extendedTextStyle:
          TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.6),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: kPaper,
      surfaceTintColor: kPaper,
    ),
    dividerTheme: const DividerThemeData(color: kHairline, thickness: 0.8),
    listTileTheme: const ListTileThemeData(iconColor: kMaroon),
    iconTheme: const IconThemeData(color: kMaroon),
  );
}
