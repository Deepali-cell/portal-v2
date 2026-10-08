import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Light-only Material 3 theme. Colours come from [AppColors], which is
/// updated by the app shell whenever the active tenant changes.
///
/// Note: nothing in this file is `const`, because [AppColors] is a mutable
/// runtime palette. Rebuild the theme whenever the tenant changes (the app
/// shell does this by re-issuing `AppTheme.light` to MaterialApp.theme).
class AppTheme {
  AppTheme._();

  static ColorScheme buildScheme() {
    return ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      surfaceTint: AppColors.surfaceTint,
      surfaceBright: AppColors.surfaceBright,
      surfaceDim: AppColors.surfaceDim,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.inverseOnSurface,
      inversePrimary: AppColors.inversePrimary,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
  }

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: buildScheme(),
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
    );
    final hanken = GoogleFonts.hankenGroteskTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: _typeScale(hanken),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceContainerLowest,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.18,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: AppColors.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          side: BorderSide(
            color: AppColors.outline,
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceContainerHigh,
          disabledForegroundColor: AppColors.onSurfaceVariant,
          elevation: 0,
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          side: BorderSide(color: AppColors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondaryFixed,
          foregroundColor: AppColors.onSecondaryFixed,
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.md,
        ),
        hintStyle:
            GoogleFonts.hankenGrotesk(color: AppColors.outline, fontSize: 14),
        labelStyle: GoogleFonts.hankenGrotesk(
            color: AppColors.onSurfaceVariant, fontSize: 14),
        prefixIconColor: AppColors.onSurfaceVariant,
        border: _border(AppColors.outlineVariant),
        enabledBorder: _border(AppColors.outlineVariant),
        focusedBorder: _border(AppColors.secondary, width: 1.4),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error, width: 1.4),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.inverseSurface,
        contentTextStyle: GoogleFonts.hankenGrotesk(
          color: AppColors.inverseOnSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.primary,
        indicatorColor: AppColors.secondaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.hankenGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryFixedDim,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppColors.onSecondaryContainer);
          }
          return IconThemeData(
              color: AppColors.primaryFixedDim.withValues(alpha: 0.85));
        }),
        elevation: 0,
        height: AppDimens.bottomNavHeight,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.secondaryFixed,
        side: BorderSide.none,
        labelStyle: GoogleFonts.hankenGrotesk(
          color: AppColors.onSecondaryFixed,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.secondary,
        unselectedLabelColor: AppColors.onSurfaceVariant,
        indicatorColor: AppColors.secondary,
        labelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.14,
        ),
        unselectedLabelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      iconTheme: IconThemeData(color: AppColors.primary),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _typeScale(TextTheme base) {
    return base.copyWith(
      headlineLarge: GoogleFonts.hankenGrotesk(
        fontSize: 28,
        height: 36 / 28,
        letterSpacing: -0.56,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
      displaySmall: GoogleFonts.hankenGrotesk(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
      headlineMedium: GoogleFonts.hankenGrotesk(
        fontSize: 22,
        height: 28 / 22,
        letterSpacing: -0.22,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      headlineSmall: GoogleFonts.hankenGrotesk(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      titleLarge: GoogleFonts.hankenGrotesk(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      titleMedium: GoogleFonts.hankenGrotesk(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      titleSmall: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      bodyLarge: GoogleFonts.hankenGrotesk(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      ),
      bodyMedium: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant,
      ),
      bodySmall: GoogleFonts.hankenGrotesk(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0.14,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.24,
        fontWeight: FontWeight.w500,
        color: AppColors.outline,
      ),
    );
  }
}
