import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_data.dart';

class DailyContentService {
  final String tableName;
  final String _cacheKey;
  final String _cacheDateKey;
  final Map<String, String> _fallback;

  DailyContentService({
    required this.tableName,
    required Map<String, String> fallback,
  })  : _cacheKey = 'cached_$tableName',
        _cacheDateKey = 'cached_${tableName}_date',
        _fallback = fallback;

  Future<Map<String, String>> getTodaysContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      final cachedDate = prefs.getString(_cacheDateKey);

      if (cachedDate == today) {
        final cachedJson = prefs.getString(_cacheKey);
        if (cachedJson != null) {
          return Map<String, String>.from(json.decode(cachedJson));
        }
      }

      final content = await _fetchFromSupabase();
      await prefs.setString(_cacheKey, json.encode(content));
      await prefs.setString(_cacheDateKey, today);
      return content;
    } catch (e) {
      print('Error getting $tableName: $e');
      return _fallback;
    }
  }

  Future<Map<String, String>> _fetchFromSupabase() async {
    // Use hijri month & day directly: id = (month - 1) * 30 + day
    // 360 rows total (12 months × 30 days), covers every possible hijri date
    final hijriMonth = SharedData.instance.hijriMonth;
    final hijriDay = SharedData.instance.hijriDay;
    final id = (hijriMonth - 1) * 30 + hijriDay;

    final response = await Supabase.instance.client
        .from(tableName)
        .select('text, source')
        .eq('id', id)
        .single();

    return {
      'text': response['text'] as String,
      'source': response['source'] as String,
    };
  }

  String _getTodayString() {
    final m = SharedData.instance.hijriMonth;
    final d = SharedData.instance.hijriDay;
    return '$m-$d';
  }
}
