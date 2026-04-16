import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:apk_sideload/install_apk.dart';
import '../services/theme_service.dart';
import '../theme/theme_config.dart';
import '../services/navigation_service.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import '../utils/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _repo = 'AbdulMannan19/ISD-TV-Display-System';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';
  static const _prefKey = 'last_installed_release';

  String _status = '';
  String _currentVersion = '';
  String _latestVersion = '';
  String _downloadUrl = '';
  bool _checking = false;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentVersion = prefs.getString(_prefKey) ?? 'Unknown';
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() { _checking = true; _status = ''; _latestVersion = ''; _downloadUrl = ''; });

    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        setState(() { _status = 'Failed to check (HTTP ${response.statusCode})'; _checking = false; });
        return;
      }

      final release = jsonDecode(response.body);
      final tagName = release['tag_name'] as String;
      setState(() => _latestVersion = tagName);

      if (tagName == _currentVersion) {
        setState(() { _status = 'up_to_date'; _checking = false; });
        return;
      }

      final assets = release['assets'] as List;
      final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] as String).endsWith('.apk'),
        orElse: () => <String, dynamic>{},
      );

      if (apkAsset.isEmpty) {
        setState(() { _status = 'No APK found in latest release'; _checking = false; });
        return;
      }

      setState(() {
        _downloadUrl = apkAsset['browser_download_url'] as String;
        _status = 'update_available';
        _checking = false;
      });
    } catch (e) {
      setState(() { _status = 'Error: $e'; _checking = false; });
    }
  }

  Future<void> _downloadAndInstall() async {
    if (_downloadUrl.isEmpty || !Platform.isAndroid) return;
    setState(() { _downloading = true; _progress = 0; });

    try {
      final response = await http.get(Uri.parse(_downloadUrl))
          .timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        setState(() { _status = 'Download failed'; _downloading = false; });
        return;
      }

      setState(() => _progress = 0.8);

      final dir = await getTemporaryDirectory();
      final apkPath = '${dir.path}/display_update.apk';
      await File(apkPath).writeAsBytes(response.bodyBytes);

      setState(() => _progress = 1.0);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _latestVersion);
      // await InstallApk().installApk(apkPath);

      setState(() { _status = 'Install triggered'; _downloading = false; _currentVersion = _latestVersion; });
    } catch (e) {
      setState(() { _status = 'Error: $e'; _downloading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService().current;
    
    return Scaffold(
      backgroundColor: theme.bg,
      body: ThemeService().buildBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: theme.text),
                    ),
                    const SizedBox(width: 8),
                    Text('Settings',
                      style: TextStyle(color: theme.text, fontSize: 24, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: 500,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.text.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.text.withOpacity(0.12)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset('assets/images/logo.png', width: 48, height: 48, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.image, size: 48, color: theme.marker.withOpacity(0.6))),
                        ),
                        const SizedBox(height: 16),
                        Text('ISD Prayer Times',
                          style: TextStyle(color: theme.text, fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Installed: $_currentVersion',
                          style: TextStyle(color: theme.textMuted, fontSize: 14)),
                        // 1. Update Section (DANGEROUS FOR PLAY STORE)
                        // Only show this on non-mobile Android devices (TV Boxes)
                        if (!kIsWeb && Platform.isAndroid && !ResponsiveHelper.isMobile(context)) ...[
                          _buildUpdateSection(theme),
                          const SizedBox(height: 24),
                          Divider(color: theme.text.withOpacity(0.1)),
                        ],

                        // 2. System Maintenance (SAFE FOR PLAY STORE)
                        // Show this on all Android devices (Mobile, Tablet, and TV)
                        if (!kIsWeb && Platform.isAndroid) ...[
                          const SizedBox(height: 24),
                          Text('System Maintenance',
                            style: TextStyle(color: theme.text.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _maintenanceButton(
                                theme, 
                                icon: Icons.settings, 
                                label: 'Android Settings', 
                                onTap: () => NavigationService.openSettings(),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateSection(ThemeConfig theme) {
    if (_checking) {
      return Column(
        children: [
          SizedBox(height: 8, width: 8, child: CircularProgressIndicator(color: theme.accentBright, strokeWidth: 2)),
          const SizedBox(height: 12),
          Text('Checking for updates...', style: TextStyle(color: theme.textMuted, fontSize: 14)),
        ],
      );
    }

    if (_downloading) {
      return Column(
        children: [
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(value: _progress > 0 ? _progress : null, color: theme.accentBright, backgroundColor: theme.text.withOpacity(0.1)),
          ),
          const SizedBox(height: 12),
          Text('Downloading update...', style: TextStyle(color: theme.textMuted, fontSize: 14)),
        ],
      );
    }

    if (_status == 'up_to_date') {
      return Column(
        children: [
          Icon(Icons.check_circle, color: theme.accent, size: 40),
          const SizedBox(height: 12),
          Text('You\'re up to date', style: TextStyle(color: theme.accent, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Version $_latestVersion', style: TextStyle(color: theme.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          _checkButton(theme),
        ],
      );
    }

    if (_status == 'update_available') {
      return Column(
        children: [
          const Icon(Icons.system_update, color: Colors.amberAccent, size: 40),
          const SizedBox(height: 12),
          Text('Update available: $_latestVersion',
            style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (Platform.isAndroid)
            ElevatedButton.icon(
              onPressed: _downloadAndInstall,
              icon: const Icon(Icons.download),
              label: const Text('Download & Install'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.bg,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            Text('Updates are only available on Android',
              style: TextStyle(color: theme.textMuted, fontSize: 13)),
        ],
      );
    }

    if (_status.isNotEmpty && !_status.startsWith('up_to_date') && !_status.startsWith('update_available')) {
      return Column(
        children: [
          Icon(Icons.error_outline, color: Colors.redAccent.shade100, size: 40),
          const SizedBox(height: 12),
          Text(_status, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.redAccent.shade100, fontSize: 14)),
          const SizedBox(height: 20),
          _checkButton(theme),
        ],
      );
    }

    return _checkButton(theme);
  }

  Widget _checkButton(ThemeConfig theme) {
    return ElevatedButton.icon(
      onPressed: _checkForUpdate,
      icon: const Icon(Icons.refresh),
      label: const Text('Check for Updates'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.text.withOpacity(0.1),
        foregroundColor: theme.text,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: theme.text.withOpacity(0.2)),
      ),
    );
  }

  Widget _maintenanceButton(ThemeConfig theme, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.textMuted,
          side: BorderSide(color: theme.text.withOpacity(0.15)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
