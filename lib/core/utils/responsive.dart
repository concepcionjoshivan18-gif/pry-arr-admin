import 'package:flutter/material.dart';

class Breakpoints {
  static const double tablet = 700;
  static const double desktop = 1100;

  static double width(BuildContext c) => MediaQuery.sizeOf(c).width;

  static bool isMobile(BuildContext c) => width(c) < tablet;
  static bool isTablet(BuildContext c) => width(c) >= tablet && width(c) < desktop;
  static bool isDesktop(BuildContext c) => width(c) >= desktop;
}
