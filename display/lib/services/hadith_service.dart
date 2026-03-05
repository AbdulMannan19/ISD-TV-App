import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HadithService {
  final _supabase = Supabase.instance.client;
  static const String _cacheKey = 'cached_hadiths';
  static const String _cacheDateKey = 'cached_hadiths_date';

  /// Get one hadith for today (cached locally, fetched once per day)
  Future<Map<String, String>> getTodaysHadith() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      final cachedDate = prefs.getString(_cacheDateKey);
      
      // Check if we have cached hadith for today
      if (cachedDate == today) {
        final cachedJson = prefs.getString(_cacheKey);
        if (cachedJson != null) {
          final decoded = json.decode(cachedJson);
          return Map<String, String>.from(decoded);
        }
      }
      
      // Cache miss or new day - fetch from Supabase
      final hadith = await _fetchHadithFromSupabase();
      
      // Cache the hadith
      await prefs.setString(_cacheKey, json.encode(hadith));
      await prefs.setString(_cacheDateKey, today);
      
      return hadith;
    } catch (e) {
      print('Error getting hadith: $e');
      return _getFallbackHadith();
    }
  }

  Future<Map<String, String>> _fetchHadithFromSupabase() async {
    // Get total count
    final countResponse = await _supabase
        .from('hadiths')
        .select('id')
        .count(CountOption.exact);
    
    final totalCount = countResponse.count ?? 0;
    
    if (totalCount == 0) {
      return _getFallbackHadith();
    }
    
    // Generate deterministic ID based on today's date
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);
    
    final id = random.nextInt(totalCount) + 1;
    
    // Fetch the hadith
    final response = await _supabase
        .from('hadiths')
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

  Map<String, String> _getFallbackHadith() {
    return {
      'text': 'The best among you are those who have the best manners and character.',
      'source': 'Sahih Bukhari',
    };
  }
}
