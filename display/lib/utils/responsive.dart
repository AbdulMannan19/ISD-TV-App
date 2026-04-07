import 'package:flutter/material.dart';

class ResponsiveHelper {
  // A device is considered mobile if its shortest side is less than 600 logical pixels.
  // Phones typically have a shortest side of 300-450. Tablets and TVs are 600+.
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide < 600;
  }

  // A device is considered small height (like a phone in landscape) if height is less than 500
  static bool isSmallHeight(BuildContext context) {
    return MediaQuery.of(context).size.height < 500;
  }

  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }
}
