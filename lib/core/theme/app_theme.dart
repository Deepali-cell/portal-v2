import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Light-only Material 3 theme. Colours come from [AppColors], which is
/// updated by the app shell whenever the active tenant changes.
///
/// Design language: airy cool canvas, white cards that float on soft shadows
/// instead of hard outlines, generous radii, filled inputs, pill chips and
/// Plus Jakarta Sans throughout.
///
/// Note: nothing in this file is `const`, because [AppColors] is a mutable
/// runtime palette. Rebuild the theme whenever the tenant changes (the app
/// shell does this by re-issuing `AppTheme.light` to MaterialApp.theme).
class AppTheme {
  AppTheme._();

  static TextStyle _font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

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
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );
    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
    );

    return base.copyWith(
      textTheme: _typeScale(jakarta),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.cardShadow,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: _font(
          color: AppColors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: AppColors.onSurface),
        actionsIconTheme: IconThemeData(color: AppColors.onSurface),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        margin: EdgeInsets.zero,
        shadowColor: AppColors.primary.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.7),
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
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          textStyle: _font(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          shape: pill,
          textStyle: _font(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surfaceContainerLowest,
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          side: BorderSide(color: AppColors.outlineVariant, width: 1.2),
          textStyle: _font(fontSize: 14, fontWeight: FontWeight.w700),
          shape: pill,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onSecondary,
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          textStyle: _font(fontSize: 14, fontWeight: FontWeight.w700),
          shape: pill,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        elevation: 4,
        highlightElevation: 8,
        extendedTextStyle: _font(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md + 2,
          vertical: AppDimens.md + 2,
        ),
        hintStyle: _font(color: AppColors.outline, fontSize: 14),
        labelStyle: _font(color: AppColors.onSurfaceVariant, fontSize: 14),
        floatingLabelStyle: _font(
          color: AppColors.secondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.focused)
              ? AppColors.secondary
              : AppColors.onSurfaceVariant,
        ),
        suffixIconColor: AppColors.onSurfaceVariant,
        border: _border(AppColors.outlineVariant),
        enabledBorder: _border(AppColors.outlineVariant, width: 1.2),
        focusedBorder: _border(AppColors.secondary, width: 1.8),
        errorBorder: _border(AppColors.error, width: 1.2),
        focusedErrorBorder: _border(AppColors.error, width: 1.8),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius3xl),
        ),
        titleTextStyle: _font(
          color: AppColors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        contentTextStyle: _font(
          color: AppColors.onSurfaceVariant,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surfaceContainerLowest,
        dragHandleColor: AppColors.outlineVariant,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radius3xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.cardShadow,
        textStyle: _font(color: AppColors.onSurface, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor:
              WidgetStatePropertyAll(AppColors.surfaceContainerLowest),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.graphite,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        contentTextStyle: _font(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.sky,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.secondary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => _font(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? AppColors.secondary
                : AppColors.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppColors.secondary);
          }
          return IconThemeData(color: AppColors.onSurfaceVariant);
        }),
        elevation: 0,
        height: AppDimens.bottomNavHeight,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceContainerLowest,
        selectedColor: AppColors.secondary.withValues(alpha: 0.14),
        checkmarkColor: AppColors.secondary,
        side: BorderSide(color: AppColors.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        labelStyle: _font(
          color: AppColors.onSurface,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: _font(
          color: AppColors.secondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        shape: const StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.outlineVariant),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.secondary.withValues(alpha: 0.14)
                : AppColors.surfaceContainerLowest,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.secondary
                : AppColors.onSurfaceVariant,
          ),
          textStyle: WidgetStatePropertyAll(
            _font(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.secondary,
        unselectedLabelColor: AppColors.onSurfaceVariant,
        indicatorColor: AppColors.secondary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.outlineVariant.withValues(alpha: 0.6),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.secondary, width: 3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
        labelStyle: _font(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: _font(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.onSurfaceVariant,
        titleTextStyle: _font(
          color: AppColors.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: _font(
          color: AppColors.onSurfaceVariant,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.secondary : null,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.secondary : null,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.secondary : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.secondary,
        linearTrackColor: AppColors.secondary.withValues(alpha: 0.12),
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(999),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.graphite,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: _font(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius3xl),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius3xl),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        iconColor: AppColors.secondary,
        textColor: AppColors.onSurface,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.rose,
        textStyle: _font(fontSize: 10, fontWeight: FontWeight.w800),
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
      headlineLarge: _font(
        fontSize: 30,
        height: 38 / 30,
        letterSpacing: -0.9,
        fontWeight: FontWeight.w800,
        color: AppColors.onSurface,
      ),
      displaySmall: _font(
        fontSize: 26,
        height: 32 / 26,
        letterSpacing: -0.6,
        fontWeight: FontWeight.w800,
        color: AppColors.onSurface,
      ),
      headlineMedium: _font(
        fontSize: 22,
        height: 28 / 22,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w800,
        color: AppColors.onSurface,
      ),
      headlineSmall: _font(
        fontSize: 19,
        height: 26 / 19,
        letterSpacing: -0.3,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      titleLarge: _font(
        fontSize: 18,
        height: 24 / 18,
        letterSpacing: -0.3,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      titleMedium: _font(
        fontSize: 16,
        height: 22 / 16,
        letterSpacing: -0.15,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      titleSmall: _font(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      bodyLarge: _font(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      ),
      bodyMedium: _font(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant,
      ),
      bodySmall: _font(
        fontSize: 12.5,
        height: 18 / 12.5,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurfaceVariant,
      ),
      labelLarge: _font(
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: _font(
        fontSize: 12.5,
        height: 16 / 12.5,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: _font(
        fontSize: 11.5,
        height: 16 / 11.5,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w600,
        color: AppColors.outline,
      ),
    );
  }
}
