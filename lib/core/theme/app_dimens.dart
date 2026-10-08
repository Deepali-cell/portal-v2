/// Spacing, radius and sizing tokens — mirrors the Material 3 redesign
/// (4 / 8 / 16 / 20 / 24 / 32 pt scale).
class AppDimens {
  AppDimens._();

  // Spacing scale (matches the Tailwind tokens in the mockups)
  static const double base = 4; // ‘base’ / xs alias
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double gutter = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Mobile screen edge inset
  static const double screenPadding = 20; // margin-mobile = 20px

  // Corner radii
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radius2xl = 24;
  static const double radius3xl = 28;

  // Components
  static const double buttonHeight = 52;
  static const double fieldHeight = 56;
  static const double maxContentWidth = 480;
  static const double sidebarWidth = 280;
  static const double bottomNavHeight = 66;
}
