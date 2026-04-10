import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:apk_sideload/install_apk.dart';

class UpdateService {
  static const _repo = 'AbdulMannan19/ISD-TV-Display-System';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';
  static const _prefKey = 'last_installed_release';

  static Future<void> checkForUpdate() async {
    // UPDATES DISABLED FOR PLAY STORE MOBILE BRANCH
    return;
    /*
    if (!Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastInstalled = prefs.getString(_prefKey) ?? '';

      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return;
      }

      final release = jsonDecode(response.body);
      final tagName = release['tag_name'] as String;

      if (tagName == lastInstalled) {
        return;
      }

      final assets = release['assets'] as List;
      final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] as String).endsWith('.apk'),
        orElse: () => <String, dynamic>{},
      );

      if (apkAsset.isEmpty) {
        return;
      }

      final downloadUrl = apkAsset['browser_download_url'] as String;

      final apkResponse = await http.get(Uri.parse(downloadUrl))
          .timeout(const Duration(minutes: 5));

      if (apkResponse.statusCode != 200) {
        return;
      }

      final dir = await getTemporaryDirectory();
      final apkPath = '${dir.path}/display_update.apk';
      await File(apkPath).writeAsBytes(apkResponse.bodyBytes);

      await prefs.setString(_prefKey, tagName);
      // await InstallApk().installApk(apkPath);
    } catch (_) {}
    */
  }
}
