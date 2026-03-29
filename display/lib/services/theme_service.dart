import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/theme_config.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  ThemeConfig _currentTheme = appThemes['onyx_neon']!;
  RealtimeChannel? _settingsChannel;

  ThemeConfig get current => _currentTheme;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeId = prefs.getString('saved_theme_id');
    if (savedThemeId != null && appThemes.containsKey(savedThemeId)) {
      _currentTheme = appThemes[savedThemeId]!;
      notifyListeners();
    }

    try {
      final data = await Supabase.instance.client
          .from('settings')
          .select('theme_id')
          .eq('id', 1)
          .maybeSingle();
      
      if (data != null && data['theme_id'] != null) {
        _applyTheme(data['theme_id'] as String);
      }
    } catch (_) {}

    _listenToSettings();
  }

  void _listenToSettings() {
    _settingsChannel = Supabase.instance.client
        .channel('settings_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'settings',
          callback: (payload) {
            if (payload.newRecord['id'] == 1 && payload.newRecord['theme_id'] != null) {
              _applyTheme(payload.newRecord['theme_id'] as String);
            }
          },
        )
        .subscribe();
  }

  Future<void> _applyTheme(String themeId) async {
    if (appThemes.containsKey(themeId) && _currentTheme.id != themeId) {
      _currentTheme = appThemes[themeId]!;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_theme_id', themeId);
    }
  }

  void disposeService() {
    if (_settingsChannel != null) {
      Supabase.instance.client.removeChannel(_settingsChannel!);
    }
    super.dispose();
  }

  // Helper method to wrap backgrounds natively
  Widget buildBackground({required Widget child}) {
    final List<Widget> layers = [];
    layers.add(Container(color: _currentTheme.bg));

    if (_currentTheme.bgGradients != null) {
      for (final grad in _currentTheme.bgGradients!) {
        layers.add(Container(
          decoration: BoxDecoration(gradient: grad),
        ));
      }
      // Apply significant blur to soften gradients/circles on large displays (60"+)
      layers.add(BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(color: Colors.transparent),
      ));
    }

    layers.add(SafeArea(child: child));

    return Stack(children: layers);
  }
}
