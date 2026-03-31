import 'package:flutter/services.dart';

/// A service to handle system-level navigation on Android (Go Home, System Settings)
class NavigationService {
  static const _channel = MethodChannel('com.isd.display/navigation');

  /// Requests the Android system to open the general System Settings activity
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } on PlatformException catch (e) {
      print("Failed to open settings: ${e.message}");
    }
  }
}
