/// The spec's spacing scale. Screens use these, never raw numbers.
abstract final class Gap {
  static const double micro = 4;
  static const double tight = 8;
  static const double compact = 12;
  static const double standard = 16;
  static const double section = 24;
  static const double major = 32;
  static const double screen = 48;
}

abstract final class Sizes {
  /// Minimum tap target mandated by the spec.
  static const double tapTarget = 48;

  /// Preferred size for primary actions.
  static const double primaryAction = 56;
  static const double cardRadius = 12;
  static const double navBarHeight = 56;

  /// Below this width the bottom nav hides inactive labels.
  static const double narrowScreen = 360;
}
