// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // Spacing
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // Border Radius
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 100.0;

  // Animation Durations
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration mockLoadDelay = Duration(milliseconds: 800);

  // App Info
  static const String appName = 'CityPulse';
  static const String appVersion = '1.0.0';
  static const String appBuild = '1';

  // SharedPreferences Keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyIsOnboarded = 'is_onboarded';
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyUserName = 'user_name';
  static const String keyUserEmail = 'user_email';

  // Pagination
  static const int pageSize = 20;

  // Search debounce
  static const Duration searchDebounce = Duration(milliseconds: 400);
}
