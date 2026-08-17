import 'package:flutter/material.dart';

enum DeviceType { mobile, tablet, desktop }

class ResponsiveHelper {
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 1024;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileMaxWidth;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileMaxWidth && width <= tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > tabletMaxWidth;
  }

  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileMaxWidth) return DeviceType.mobile;
    if (width <= tabletMaxWidth) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Returns dynamic grid column counts based on screen width
  static int getGridCrossAxisCount(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 4,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  /// Returns dynamic modal/dialog width based on screen size
  static double getModalWidth(BuildContext context, {double desktopWidth = 550}) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isMobile(context)) {
      return screenWidth * 0.92;
    } else if (isTablet(context)) {
      return screenWidth * 0.75;
    }
    return desktopWidth;
  }

  /// Returns responsive horizontal page padding
  static EdgeInsets getPagePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 28, vertical: 20);
  }
}
