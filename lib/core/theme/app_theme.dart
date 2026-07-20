import 'package:flutter/material.dart';

/// Design tokens extracted from the Figma file "ShopScroll-UI"
/// (Global Tokens variable collection). Every color used in the app must
/// come from [AppColors] — do not write literal `Color(0x...)` values
/// elsewhere.
class AppColors {
  AppColors._();

  // Primary
  static const Color primary50 = Color(0xFFD9E8FD);
  static const Color primary100 = Color(0xFFBFD9FF);
  static const Color primary200 = Color(0xFF80B3FF);
  static const Color primary300 = Color(0xFF408CFF);
  static const Color primary400 = Color(0xFF0066FF);
  static const Color primary500 = Color(0xFF004FC6);
  static const Color primary600 = Color(0xFF00388C);
  static const Color primaryAlpha10 = Color(0x1A0066FF);
  static const Color primaryAlpha50 = Color(0x800066FF);

  // Secondary
  static const Color secondary100 = Color(0xFFFFDABF);
  static const Color secondary200 = Color(0xFFFFB580);
  static const Color secondary300 = Color(0xFFFF9040);
  static const Color secondary400 = Color(0xFFFF6B00);
  static const Color secondary500 = Color(0xFFC65300);
  static const Color secondary600 = Color(0xFF8C3B00);
  static const Color secondaryAlpha10 = Color(0x1AFF6B00);
  static const Color secondaryAlpha50 = Color(0x80FF6B00);

  // Accent
  static const Color accent100 = Color(0xFFDDBBFF);
  static const Color accent200 = Color(0xFFBB77FF);
  static const Color accent300 = Color(0xFF9933FF);
  static const Color accent400 = Color(0xFF7D00FA);
  static const Color accent500 = Color(0xFF6100C2);
  static const Color accent600 = Color(0xFF45008A);
  static const Color accentAlpha10 = Color(0x1A9933FF);
  static const Color accentAlpha50 = Color(0x809933FF);

  // Neutral
  static const Color neutral100 = Color(0xFFFFFFFF);
  static const Color neutral200 = Color(0xFFE8E8E8);
  static const Color neutral300 = Color(0xFFD2D2D2);
  static const Color neutral400 = Color(0xFFBBBBBB);
  static const Color neutral500 = Color(0xFFA4A4A4);
  static const Color neutral600 = Color(0xFF8E8E8E);
  static const Color neutral700 = Color(0xFF777777);
  static const Color neutral800 = Color(0xFF606060);
  static const Color neutral900 = Color(0xFF4A4A4A);
  static const Color neutral1000 = Color(0xFF333333);
  static const Color neutral1100 = Color(0xFF000000);
  static const Color neutralAlpha10 = Color(0x1A333333);
  static const Color neutralAlpha50 = Color(0x80333333);

  // Error
  static const Color error100 = Color(0xFFFFBBBB);
  static const Color error200 = Color(0xFFFF7777);
  static const Color error300 = Color(0xFFFF3333);
  static const Color error400 = Color(0xFFFA0000);
  static const Color error500 = Color(0xFFC20000);
  static const Color error600 = Color(0xFF8A0000);
  static const Color errorAlpha10 = Color(0x1AFF3333);
  static const Color errorAlpha50 = Color(0x80FF3333);

  // Warning
  static const Color warning100 = Color(0xFFFFEDBF);
  static const Color warning200 = Color(0xFFFFDC80);
  static const Color warning300 = Color(0xFFFFCA40);
  static const Color warning400 = Color(0xFFFFB800);
  static const Color warning500 = Color(0xFFC68F00);
  static const Color warning600 = Color(0xFF8C6500);
  static const Color warningAlpha10 = Color(0x1AFFB800);
  static const Color warningAlpha50 = Color(0x80FFB800);

  // Success
  static const Color success50 = Color(0xFFCDFFE6);
  static const Color success100 = Color(0xFFB3FFD9);
  static const Color success200 = Color(0xFF66FFB3);
  static const Color success300 = Color(0xFF1AFF8C);
  static const Color success400 = Color(0xFF00CC66);
  static const Color success500 = Color(0xFF009F50);
  static const Color success600 = Color(0xFF007339);
  static const Color successAlpha10 = Color(0x1A00CC66);
  static const Color successAlpha50 = Color(0x8000CC66);

  // Local Figma paint styles ("Black / Black 10/20/40") found on components
  // (e.g. Product card's image placeholder) — not part of the Global
  // Tokens variable collection, but real reusable styles from the file.
  static const Color blackAlpha10 = Color(0xFFEAE9EA);
  static const Color blackAlpha20 = Color(0xFFD4D4D5);
  static const Color blackAlpha40 = Color(0xFFABA9AB);

  /// Figma paint style "White / White 100" — used as the tab bar
  /// background, a hair lighter than pure white ([neutral100]).
  static const Color white100 = Color(0xFFFEFEFE);

  // Found in Figma's real variables but with no equivalent token here
  // (confirmed via `get_variable_defs` across Home/Cart/Discover/Reels/
  // Profile, 2026-07-14). Call sites that need muted text or a hairline
  // border likely substituted a solid [neutral600]/[neutral700] instead —
  // worth migrating opportunistically, not changed automatically by this
  // audit since that needs a visual check per call site.

  /// Figma variable `Labels/Secondary` — the iOS system "secondary label"
  /// color (black at 60% alpha), used across most screens for muted text.
  static const Color labelSecondary = Color(0x993C3C43);

  /// Figma variable `Miscellaneous/Bar border` — black at 30% alpha, used
  /// for hairline borders under bars.
  static const Color barBorder = Color(0x4D000000);
}

/// Typography scale cross-checked against the real Figma variables (Figma
/// desktop, "ShopScroll-UI" file, "The design - user" page, `get_variable_defs`
/// run against the Home/Product details/Cart/Discover/Reels/Profile/Log in
/// frames, 2026-07-14). Every body/UI text layer is bound to a variable named
/// `Inter/<size>/<weight>`; every display/heading layer is bound to a
/// variable named `GeneralSans/<size>/<weight>` — but each `GeneralSans`
/// variable actually resolves to the font resource "Plus Jakarta Sans", not
/// a typeface literally called General Sans. That mismatch lives inside the
/// Figma file itself (a variable named after one font, bound to another);
/// this file follows the real bound font rather than the variable's label.
///
/// The previous values here, "SF Pro Text" and "Poppins", matched neither
/// name — most likely sampled from stray, non-token-bound text layers (a
/// few of those do show up with inconsistent fonts, e.g. the tab labels in
/// `SegmentedTabs`' doc comment), rather than the actual design tokens.
/// Fixed to the token-backed fonts by this audit; still open: neither
/// "Inter" nor "Plus Jakarta Sans" is bundled as a font asset in
/// pubspec.yaml, so text keeps rendering in the platform default font until
/// the .ttf files are added under `assets/fonts/` and declared there (see
/// design.md).
///
/// Sizes xs(12) → 4xl(36) — larger sizes in the source file (5xl-9xl) aren't
/// used by any mobile screen so are omitted here).
///
/// [displayLarge]..[labelSmall] map this raw scale onto Flutter's
/// [TextTheme] slots; that mapping (which family/weight/size fills which
/// role) isn't defined in Figma and is this file's own convention — change
/// it here, not at call sites.
class AppTypography {
  AppTypography._();

  /// Figma variables `Inter/*` (body/UI text).
  static const String fontFamilyBody = 'Inter';

  /// Figma variables `GeneralSans/*`, which actually resolve to the font
  /// resource "Plus Jakarta Sans" — see the class doc above.
  static const String fontFamilyDisplay = 'Plus Jakarta Sans';

  // Font sizes
  static const double sizeXs = 12;
  static const double sizeSm = 14;
  static const double sizeBase = 16;
  static const double sizeLg = 18;
  static const double sizeXl = 20;
  static const double size2xl = 24;
  static const double size3xl = 30;
  static const double size4xl = 36;

  // Line heights, as a multiplier of font size (Figma stores these as a
  // percentage of font size, e.g. 150% -> 1.5).
  static const double lineHeightXs = 1.25;
  static const double lineHeightSm = 1.25;
  static const double lineHeightBase = 1.5;
  static const double lineHeightLg = 1.5;
  static const double lineHeightXl = 1.5;
  static const double lineHeight2xl = 1.5;
  static const double lineHeight3xl = 1.25;
  static const double lineHeight4xl = 1.25;

  static TextStyle _style({
    required String family,
    required double size,
    required double height,
    required FontWeight weight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: height,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle get displayLarge => _style(
        family: fontFamilyDisplay,
        size: size4xl,
        height: lineHeight4xl,
        weight: FontWeight.w600,
      );

  static TextStyle get displayMedium => _style(
        family: fontFamilyDisplay,
        size: size3xl,
        height: lineHeight3xl,
        weight: FontWeight.w600,
      );

  static TextStyle get displaySmall => _style(
        family: fontFamilyDisplay,
        size: size2xl,
        height: lineHeight2xl,
        weight: FontWeight.w600,
      );

  static TextStyle get headlineLarge => _style(
        family: fontFamilyDisplay,
        size: sizeXl,
        height: lineHeightXl,
        weight: FontWeight.w600,
      );

  static TextStyle get headlineMedium => _style(
        family: fontFamilyBody,
        size: sizeLg,
        height: lineHeightLg,
        weight: FontWeight.w700,
      );

  static TextStyle get headlineSmall => _style(
        family: fontFamilyBody,
        size: sizeBase,
        height: lineHeightBase,
        weight: FontWeight.w700,
      );

  static TextStyle get titleLarge => _style(
        family: fontFamilyBody,
        size: sizeLg,
        height: lineHeightLg,
        weight: FontWeight.w600,
      );

  static TextStyle get titleMedium => _style(
        family: fontFamilyBody,
        size: sizeBase,
        height: lineHeightBase,
        weight: FontWeight.w600,
      );

  static TextStyle get titleSmall => _style(
        family: fontFamilyBody,
        size: sizeSm,
        height: lineHeightSm,
        weight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => _style(
        family: fontFamilyBody,
        size: sizeBase,
        height: lineHeightBase,
        weight: FontWeight.w400,
      );

  static TextStyle get bodyMedium => _style(
        family: fontFamilyBody,
        size: sizeSm,
        height: lineHeightSm,
        weight: FontWeight.w400,
      );

  static TextStyle get bodySmall => _style(
        family: fontFamilyBody,
        size: sizeXs,
        height: lineHeightXs,
        weight: FontWeight.w400,
      );

  static TextStyle get labelLarge => _style(
        family: fontFamilyBody,
        size: sizeSm,
        height: lineHeightSm,
        weight: FontWeight.w500,
      );

  static TextStyle get labelMedium => _style(
        family: fontFamilyBody,
        size: sizeXs,
        height: lineHeightXs,
        weight: FontWeight.w500,
      );

  static TextStyle get labelSmall => _style(
        family: fontFamilyBody,
        size: sizeXs,
        height: lineHeightXs,
        weight: FontWeight.w500,
      );
}

/// Spacing scale derived from the Figma "Spacing" variable (base unit = 4)
/// and the padding/gap values actually used across components in the
/// "Design System-mobile" page (4, 8, 12, 16, 20, 24 all recur; anything
/// else observed, e.g. 5/6/9/10, was a one-off adjustment, not a token).
class AppSpacing {
  AppSpacing._();

  static const double unit = 4;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
}

/// Corner radius scale sampled from actual `cornerRadius` values on
/// components (Button, Product card, Cell, etc.). Values of 99/100/200
/// in the source file are the designer's way of forcing a full pill/circle
/// regardless of element size — [full] captures that intent with a value
/// large enough to work for any element.
class AppRadius {
  AppRadius._();

  static const double none = 0;
  static const double sm = 4;
  static const double md = 8;
  static const double full = 999;
}

class AppTheme {
  AppTheme._();

  static ColorScheme get _lightColorScheme => ColorScheme.light(
        primary: AppColors.primary400,
        onPrimary: AppColors.neutral100,
        primaryContainer: AppColors.primary100,
        onPrimaryContainer: AppColors.primary600,
        secondary: AppColors.secondary400,
        onSecondary: AppColors.neutral100,
        secondaryContainer: AppColors.secondary100,
        onSecondaryContainer: AppColors.secondary600,
        tertiary: AppColors.accent400,
        onTertiary: AppColors.neutral100,
        tertiaryContainer: AppColors.accent100,
        onTertiaryContainer: AppColors.accent600,
        error: AppColors.error400,
        onError: AppColors.neutral100,
        errorContainer: AppColors.error100,
        onErrorContainer: AppColors.error600,
        surface: AppColors.neutral100,
        onSurface: AppColors.neutral1000,
        outline: AppColors.neutral400,
        outlineVariant: AppColors.neutral300,
      );

  // The Figma file's "Mode" variant of Global Tokens duplicates the light
  // values rather than defining a real dark palette, so dark theme reuses
  // the same brand colors with inverted surfaces.
  static ColorScheme get _darkColorScheme => ColorScheme.dark(
        primary: AppColors.primary300,
        onPrimary: AppColors.primary600,
        primaryContainer: AppColors.primary500,
        onPrimaryContainer: AppColors.primary100,
        secondary: AppColors.secondary300,
        onSecondary: AppColors.secondary600,
        secondaryContainer: AppColors.secondary500,
        onSecondaryContainer: AppColors.secondary100,
        tertiary: AppColors.accent300,
        onTertiary: AppColors.accent600,
        tertiaryContainer: AppColors.accent500,
        onTertiaryContainer: AppColors.accent100,
        error: AppColors.error300,
        onError: AppColors.error600,
        errorContainer: AppColors.error500,
        onErrorContainer: AppColors.error100,
        surface: AppColors.neutral1100,
        onSurface: AppColors.neutral100,
        outline: AppColors.neutral700,
        outlineVariant: AppColors.neutral800,
      );

  static TextTheme get _textTheme => TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall: AppTypography.displaySmall,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.titleSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _lightColorScheme,
        scaffoldBackgroundColor: AppColors.neutral100,
        textTheme: _textTheme.apply(
          bodyColor: AppColors.neutral1000,
          displayColor: AppColors.neutral1000,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary400,
            foregroundColor: AppColors.neutral100,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            textStyle: AppTypography.labelLarge,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.neutral200,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.neutral100,
          surfaceTintColor: AppColors.neutral100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _darkColorScheme,
        scaffoldBackgroundColor: AppColors.neutral1100,
        textTheme: _textTheme.apply(
          bodyColor: AppColors.neutral100,
          displayColor: AppColors.neutral100,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary300,
            foregroundColor: AppColors.primary600,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            textStyle: AppTypography.labelLarge,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.neutral900,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.neutral900,
          surfaceTintColor: AppColors.neutral900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
}
