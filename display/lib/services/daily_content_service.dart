import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final id = ((dayOfYear - 1) % 366) + 1;

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
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
