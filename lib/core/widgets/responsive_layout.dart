import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < ResponsiveHelper.mobileMaxWidth) {
          return mobile;
        }
        if (constraints.maxWidth <= ResponsiveHelper.tabletMaxWidth) {
          return tablet ?? desktop;
        }
        return desktop;
      },
    );
  }
}
