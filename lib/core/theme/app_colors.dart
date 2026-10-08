import 'package:flutter/material.dart';

import '../../features/tenant/domain/tenant.dart';

/// A complete colour palette derived from a tenant's three brand colours
/// (P1 / P2 / P3). Built once per tenant change and applied to [AppColors]
/// by the app shell.
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primaryFixed,
    required this.primaryFixedDim,
    required this.onPrimaryFixed,
    required this.onPrimaryFixedVariant,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.secondaryFixed,
    required this.secondaryFixedDim,
    required this.onSecondaryFixed,
    required this.onSecondaryFixedVariant,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.tertiaryFixed,
    required this.tertiaryFixedDim,
    required this.onTertiaryFixed,
    required this.onTertiaryFixedVariant,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.surfaceBright,
    required this.surfaceDim,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceTint,
    required this.inverseSurface,
    required this.inverseOnSurface,
    required this.inversePrimary,
    required this.outline,
    required this.outlineVariant,
    required this.cardShadow,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color primaryFixed;
  final Color primaryFixedDim;
  final Color onPrimaryFixed;
  final Color onPrimaryFixedVariant;

  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color secondaryFixed;
  final Color secondaryFixedDim;
  final Color onSecondaryFixed;
  final Color onSecondaryFixedVariant;

  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color tertiaryFixed;
  final Color tertiaryFixedDim;
  final Color onTertiaryFixed;
  final Color onTertiaryFixedVariant;

  final Color background;
  final Color onBackground;
  final Color surface;
  final Color surfaceBright;
  final Color surfaceDim;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceTint;
  final Color inverseSurface;
  final Color inverseOnSurface;
  final Color inversePrimary;

  final Color outline;
  final Color outlineVariant;

  final Color cardShadow;

  /// Derive a full palette from a tenant's three brand colours.
  ///
  /// Mapping:
  ///  - P1 (e.g. white)       -> surface/background stack + on-primary inks
  ///  - P2 (e.g. dark navy)   -> primary + navy aliases + inverse surface
  ///  - P3 (e.g. royal blue)  -> secondary + accents + fixed/dim variants
  /// Everything else is derived by tinting or lightness adjustments.
  factory AppPalette.fromTenant(Tenant t) {
    final p1 = t.colorP1;
    final p2 = t.colorP2;
    final p3 = t.colorP3;

    // Helpers — operate in HSL for predictable lightness math.
    Color lighten(Color c, double amount) =>
        HSLColor.fromColor(c).withLightness(
              (HSLColor.fromColor(c).lightness + amount).clamp(0.0, 1.0),
            ).toColor();
    Color darken(Color c, double amount) =>
        HSLColor.fromColor(c).withLightness(
              (HSLColor.fromColor(c).lightness - amount).clamp(0.0, 1.0),
            ).toColor();
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

    // Surface stack — anchored on P1, tinted very slightly toward P2 as
    // we go up the elevation ladder.
    final surface = p1;
    final surfaceContainerLowest = p1;
    final surfaceContainerLow = mix(p1, p3, 0.04);
    final surfaceContainer = mix(p1, p3, 0.08);
    final surfaceContainerHigh = mix(p1, p3, 0.13);
    final surfaceContainerHighest = mix(p1, p3, 0.18);
    final surfaceVariant = mix(p1, p3, 0.18);
    final surfaceBright = p1;
    final surfaceDim = mix(p1, p3, 0.20);
    // Page background sits a hair off-white (#FAFAFA on a white P1) so white
    // cards lift off it, matching tcbinfotech.com.
    final background = mix(p1, Colors.black, 0.02);

    // Inks — derived from P2 (the primary brand).
    final onSurface = mix(p2, Colors.black, 0.0);
    final onSurfaceVariant = lighten(p2, 0.20);
    final onBackground = onSurface;
    final outline = mix(p2, Colors.white, 0.55);
    final outlineVariant = mix(p2, Colors.white, 0.80);

    return AppPalette(
      // Primary cluster -> P2
      primary: p2,
      onPrimary: p1,
      primaryContainer: lighten(p2, 0.10),
      onPrimaryContainer: mix(p2, Colors.white, 0.45),
      primaryFixed: mix(p2, Colors.white, 0.82),
      primaryFixedDim: mix(p2, Colors.white, 0.66),
      onPrimaryFixed: darken(p2, 0.05),
      onPrimaryFixedVariant: mix(p2, Colors.white, 0.30),

      // Secondary cluster -> P3
      secondary: p3,
      onSecondary: p1,
      secondaryContainer: lighten(p3, 0.05),
      // White ink on the bright-blue boxes (Apply for Leave, Add, Save…).
      onSecondaryContainer: Colors.white,
      secondaryFixed: mix(p3, Colors.white, 0.55),
      secondaryFixedDim: mix(p3, Colors.white, 0.35),
      onSecondaryFixed: darken(p2, 0.10),
      onSecondaryFixedVariant: mix(p2, Colors.white, 0.15),

      // Tertiary cluster -> deep success/accent green (independent of tenant).
      // Held constant so success states stay readable across any branding.
      tertiary: const Color(0xFF001C10),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFF003320),
      onTertiaryContainer: const Color(0xFF00A774),
      tertiaryFixed: const Color(0xFF6FFBBE),
      tertiaryFixedDim: const Color(0xFF4EDEA3),
      onTertiaryFixed: const Color(0xFF002113),
      onTertiaryFixedVariant: const Color(0xFF005236),

      // Surface stack
      background: background,
      onBackground: onBackground,
      surface: surface,
      surfaceBright: surfaceBright,
      surfaceDim: surfaceDim,
      surfaceVariant: surfaceVariant,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceTint: mix(p2, Colors.white, 0.40),
      inverseSurface: darken(p2, 0.05),
      inverseOnSurface: mix(p1, p3, 0.05),
      inversePrimary: mix(p2, Colors.white, 0.55),

      // Outline / lines
      outline: outline,
      outlineVariant: outlineVariant,

      cardShadow: p2.withValues(alpha: 0.05),
    );
  }

  /// A full **dark** palette: near-black graphite surfaces + light inks, with
  /// the tenant's brand colour brightened into a readable accent. Every screen
  /// reads [AppColors], so applying this flips the whole app to dark at once.
  factory AppPalette.darkFromTenant(Tenant t) {
    final p2 = t.colorP2; // brand (navy)
    final p3 = t.colorP3; // brand accent (royal blue)

    Color lighten(Color c, double amount) =>
        HSLColor.fromColor(c).withLightness(
              (HSLColor.fromColor(c).lightness + amount).clamp(0.0, 1.0),
            ).toColor();
    Color mix(Color a, Color b, double f) => Color.lerp(a, b, f)!;

    // Brand accent, brightened so it reads on near-black surfaces.
    final accent = lighten(p2, 0.42);

    // Graphite surface ladder.
    const bg = Color(0xFF0E1116);
    const s1 = Color(0xFF161B23); // cards / app bars
    const s2 = Color(0xFF1A2029);
    const s3 = Color(0xFF1E2530);
    const s4 = Color(0xFF232B37);
    const s5 = Color(0xFF29323F);
    const ink = Color(0xFFE7ECF3);
    const inkMuted = Color(0xFFA6B0BF);

    return AppPalette(
      // Primary cluster -> brightened brand accent
      primary: accent,
      onPrimary: const Color(0xFF07101E),
      primaryContainer: mix(p2, bg, 0.30),
      onPrimaryContainer: lighten(p3, 0.16),
      primaryFixed: mix(accent, bg, 0.30),
      primaryFixedDim: mix(accent, bg, 0.12),
      onPrimaryFixed: const Color(0xFFEAF1FB),
      onPrimaryFixedVariant: mix(accent, Colors.white, 0.10),

      // Secondary cluster -> P3
      secondary: lighten(p3, 0.06),
      onSecondary: const Color(0xFF07101E),
      secondaryContainer: mix(p3, bg, 0.58),
      onSecondaryContainer: lighten(p3, 0.20),
      secondaryFixed: mix(p3, bg, 0.66),
      secondaryFixedDim: mix(p3, bg, 0.52),
      onSecondaryFixed: ink,
      onSecondaryFixedVariant: inkMuted,

      // Tertiary -> success green, tuned for dark surfaces.
      tertiary: const Color(0xFF4EDEA3),
      onTertiary: const Color(0xFF00110A),
      tertiaryContainer: const Color(0xFF0F3D2A),
      onTertiaryContainer: const Color(0xFF5FE9B0),
      tertiaryFixed: const Color(0xFF6FFBBE),
      tertiaryFixedDim: const Color(0xFF4EDEA3),
      onTertiaryFixed: const Color(0xFF002113),
      onTertiaryFixedVariant: const Color(0xFF7FE9BC),

      // Surface stack
      background: bg,
      onBackground: ink,
      surface: s1,
      surfaceBright: s5,
      surfaceDim: bg,
      surfaceVariant: s4,
      onSurface: ink,
      onSurfaceVariant: inkMuted,
      surfaceContainerLowest: s1,
      surfaceContainerLow: s2,
      surfaceContainer: s3,
      surfaceContainerHigh: s4,
      surfaceContainerHighest: s5,
      surfaceTint: accent,
      inverseSurface: const Color(0xFFE7ECF3),
      inverseOnSurface: const Color(0xFF1A2029),
      inversePrimary: mix(p2, bg, 0.20),

      // Outline / lines
      outline: const Color(0xFF3A4453),
      outlineVariant: const Color(0xFF262E3A),

      cardShadow: const Color(0x66000000),
    );
  }

  /// Built-in default — TCB Infotech's brand. Used before any tenant resolves
  /// (fresh install, first launch).
  static final tcbDefault = AppPalette.fromTenant(Tenant.tcbDefault);
}

/// Globally-readable colour tokens for the app.
///
/// Each field is a mutable static, updated via [apply] when the active tenant
/// changes. The owning `MaterialApp` rebuilds whenever the tenant changes,
/// which in turn re-reads these values during the build pass — so the visual
/// switch is atomic from the user's point of view.
///
/// Fixed colours (error, warning, success) are independent of the tenant —
/// they need to mean the same thing regardless of branding.
class AppColors {
  AppColors._();

  // Primary cluster (P2-derived)
  static Color primary = AppPalette.tcbDefault.primary;
  static Color onPrimary = AppPalette.tcbDefault.onPrimary;
  static Color primaryContainer = AppPalette.tcbDefault.primaryContainer;
  static Color onPrimaryContainer = AppPalette.tcbDefault.onPrimaryContainer;
  static Color primaryFixed = AppPalette.tcbDefault.primaryFixed;
  static Color primaryFixedDim = AppPalette.tcbDefault.primaryFixedDim;
  static Color onPrimaryFixed = AppPalette.tcbDefault.onPrimaryFixed;
  static Color onPrimaryFixedVariant =
      AppPalette.tcbDefault.onPrimaryFixedVariant;

  // Secondary cluster (P3-derived)
  static Color secondary = AppPalette.tcbDefault.secondary;
  static Color onSecondary = AppPalette.tcbDefault.onSecondary;
  static Color secondaryContainer = AppPalette.tcbDefault.secondaryContainer;
  static Color onSecondaryContainer =
      AppPalette.tcbDefault.onSecondaryContainer;
  static Color secondaryFixed = AppPalette.tcbDefault.secondaryFixed;
  static Color secondaryFixedDim = AppPalette.tcbDefault.secondaryFixedDim;
  static Color onSecondaryFixed = AppPalette.tcbDefault.onSecondaryFixed;
  static Color onSecondaryFixedVariant =
      AppPalette.tcbDefault.onSecondaryFixedVariant;

  // Tertiary cluster (fixed, brand-independent)
  static Color tertiary = AppPalette.tcbDefault.tertiary;
  static Color onTertiary = AppPalette.tcbDefault.onTertiary;
  static Color tertiaryContainer = AppPalette.tcbDefault.tertiaryContainer;
  static Color onTertiaryContainer = AppPalette.tcbDefault.onTertiaryContainer;
  static Color tertiaryFixed = AppPalette.tcbDefault.tertiaryFixed;
  static Color tertiaryFixedDim = AppPalette.tcbDefault.tertiaryFixedDim;
  static Color onTertiaryFixed = AppPalette.tcbDefault.onTertiaryFixed;
  static Color onTertiaryFixedVariant =
      AppPalette.tcbDefault.onTertiaryFixedVariant;

  // Surface stack
  static Color background = AppPalette.tcbDefault.background;
  static Color onBackground = AppPalette.tcbDefault.onBackground;
  static Color surface = AppPalette.tcbDefault.surface;
  static Color surfaceBright = AppPalette.tcbDefault.surfaceBright;
  static Color surfaceDim = AppPalette.tcbDefault.surfaceDim;
  static Color surfaceVariant = AppPalette.tcbDefault.surfaceVariant;
  static Color onSurface = AppPalette.tcbDefault.onSurface;
  static Color onSurfaceVariant = AppPalette.tcbDefault.onSurfaceVariant;
  static Color surfaceContainerLowest =
      AppPalette.tcbDefault.surfaceContainerLowest;
  static Color surfaceContainerLow = AppPalette.tcbDefault.surfaceContainerLow;
  static Color surfaceContainer = AppPalette.tcbDefault.surfaceContainer;
  static Color surfaceContainerHigh = AppPalette.tcbDefault.surfaceContainerHigh;
  static Color surfaceContainerHighest =
      AppPalette.tcbDefault.surfaceContainerHighest;
  static Color surfaceTint = AppPalette.tcbDefault.surfaceTint;
  static Color inverseSurface = AppPalette.tcbDefault.inverseSurface;
  static Color inverseOnSurface = AppPalette.tcbDefault.inverseOnSurface;
  static Color inversePrimary = AppPalette.tcbDefault.inversePrimary;

  // Outline / lines
  static Color outline = AppPalette.tcbDefault.outline;
  static Color outlineVariant = AppPalette.tcbDefault.outlineVariant;

  // Fixed brand-independent colours
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color warning = Color(0xFFB54708);

  // TCB navy inks — the dark anchor of the hero / header gradients and the
  // mobile bottom nav. `graphiteHigh` is TCB's brand navy (#022B60) and
  // `graphite` a deeper shade of it, so headers carry the brand instead of
  // reading black.
  static const Color graphite = Color(0xFF011A3A);
  static const Color graphiteHigh = Color(0xFF022B60);

  // Card shadow (tinted by primary)
  static Color cardShadow = AppPalette.tcbDefault.cardShadow;

  // ---- Convenience aliases used widely across the codebase ----
  // Kept for backward compatibility with screens written before P1/P2/P3.
  static Color get navy => primary;
  static Color get canvas => background;
  static Color get navyTint => secondaryFixed;
  static Color get navyTintStrong => primaryFixedDim;
  static Color get ink => onSurface;
  static Color get inkMuted => onSurfaceVariant;
  static Color get inkFaint => outline;
  static Color get line => outlineVariant;
  static Color get danger => error;
  static Color get success => onTertiaryContainer;
  static Color get navy90 => onPrimaryFixedVariant;
  static Color get surfaceMuted => surfaceContainerLow;

  /// Swap the active palette. Called from the app shell whenever the
  /// resolved tenant changes. The MaterialApp rebuild that follows will
  /// re-read all values during build().
  static void apply(AppPalette p) {
    primary = p.primary;
    onPrimary = p.onPrimary;
    primaryContainer = p.primaryContainer;
    onPrimaryContainer = p.onPrimaryContainer;
    primaryFixed = p.primaryFixed;
    primaryFixedDim = p.primaryFixedDim;
    onPrimaryFixed = p.onPrimaryFixed;
    onPrimaryFixedVariant = p.onPrimaryFixedVariant;

    secondary = p.secondary;
    onSecondary = p.onSecondary;
    secondaryContainer = p.secondaryContainer;
    onSecondaryContainer = p.onSecondaryContainer;
    secondaryFixed = p.secondaryFixed;
    secondaryFixedDim = p.secondaryFixedDim;
    onSecondaryFixed = p.onSecondaryFixed;
    onSecondaryFixedVariant = p.onSecondaryFixedVariant;

    tertiary = p.tertiary;
    onTertiary = p.onTertiary;
    tertiaryContainer = p.tertiaryContainer;
    onTertiaryContainer = p.onTertiaryContainer;
    tertiaryFixed = p.tertiaryFixed;
    tertiaryFixedDim = p.tertiaryFixedDim;
    onTertiaryFixed = p.onTertiaryFixed;
    onTertiaryFixedVariant = p.onTertiaryFixedVariant;

    background = p.background;
    onBackground = p.onBackground;
    surface = p.surface;
    surfaceBright = p.surfaceBright;
    surfaceDim = p.surfaceDim;
    surfaceVariant = p.surfaceVariant;
    onSurface = p.onSurface;
    onSurfaceVariant = p.onSurfaceVariant;
    surfaceContainerLowest = p.surfaceContainerLowest;
    surfaceContainerLow = p.surfaceContainerLow;
    surfaceContainer = p.surfaceContainer;
    surfaceContainerHigh = p.surfaceContainerHigh;
    surfaceContainerHighest = p.surfaceContainerHighest;
    surfaceTint = p.surfaceTint;
    inverseSurface = p.inverseSurface;
    inverseOnSurface = p.inverseOnSurface;
    inversePrimary = p.inversePrimary;

    outline = p.outline;
    outlineVariant = p.outlineVariant;

    cardShadow = p.cardShadow;
  }
}
