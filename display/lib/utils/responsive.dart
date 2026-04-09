import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ResponsiveHelper {
  static bool get _isTV => (dotenv.env['DEVICE'] ?? 'TV').toUpperCase() == 'TV';

  static bool isMobile(BuildContext context) {
    if (_isTV) return false;
    return MediaQuery.of(context).size.shortestSide < 600;
  }

  static bool isSmallHeight(BuildContext context) {
    if (_isTV) return false;
    return MediaQuery.of(context).size.height < 500;
  }

  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }
}
