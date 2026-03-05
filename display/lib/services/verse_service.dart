import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerseService {
  final _supabase = Supabase.instance.client;
  static const String _cacheKey = 'cached_verse';
  static const String _cacheDateKey = 'cached_verse_date';

  Future<Map<String, String>> getTodaysVerse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      final cachedDate = prefs.getString(_cacheDateKey);
      
      if (cachedDate == today) {
        final cachedJson = prefs.getString(_cacheKey);
        if (cachedJson != null) {
          final decoded = json.decode(cachedJson);
          return Map<String, String>.from(decoded);
        }
      }
      
      final verse = await _fetchVerseFromSupabase();
      
      await prefs.setString(_cacheKey, json.encode(verse));
      await prefs.setString(_cacheDateKey, today);
      
      return verse;
    } catch (e) {
      print('Error getting verse: $e');
      return _getFallbackVerse();
    }
  }

  Future<Map<String, String>> _fetchVerseFromSupabase() async {
    final countResponse = await _supabase
        .from('verses')
        .select('id')
        .count(CountOption.exact);
    
    final totalCount = countResponse.count ?? 0;
    
    if (totalCount == 0) {
      return _getFallbackVerse();
    }
    
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day + 2;
    final random = Random(seed);
    
    final id = random.nextInt(totalCount) + 1;
    
    final response = await _supabase
        .from('verses')
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

  Map<String, String> _getFallbackVerse() {
    return {
      'text': 'Indeed, with hardship [will be] ease.',
      'source': 'Quran 94:6',
    };
  }
}
