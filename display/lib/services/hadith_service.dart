import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HadithService {
  final _supabase = Supabase.instance.client;
  static const String _cacheKey = 'cached_hadiths';
  static const String _cacheDateKey = 'cached_hadiths_date';

  /// Get two hadiths for today (cached locally, fetched once per day)
  Future<List<Map<String, String>>> getTodaysHadiths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      final cachedDate = prefs.getString(_cacheDateKey);
      
      // Check if we have cached hadiths for today
      if (cachedDate == today) {
        final cachedJson = prefs.getString(_cacheKey);
        if (cachedJson != null) {
          final List<dynamic> decoded = json.decode(cachedJson);
          return decoded.map((h) => Map<String, String>.from(h)).toList();
        }
      }
      
      // Cache miss or new day - fetch from Supabase
      final hadiths = await _fetchHadithsFromSupabase();
      
      // Cache the hadiths
      await prefs.setString(_cacheKey, json.encode(hadiths));
      await prefs.setString(_cacheDateKey, today);
      
      return hadiths;
    } catch (e) {
      print('Error getting hadiths: $e');
      return _getFallbackHadiths();
    }
  }

  Future<List<Map<String, String>>> _fetchHadithsFromSupabase() async {
    // Get total count
    final countResponse = await _supabase
        .from('hadiths')
        .select('id')
        .count(CountOption.exact);
    
    final totalCount = countResponse.count ?? 1000;
    
    // Generate deterministic IDs based on today's date
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);
    
    // Pick two different random IDs for today
    final id1 = random.nextInt(totalCount) + 1;
    int id2 = random.nextInt(totalCount) + 1;
    
    // Ensure id2 is different from id1
    while (id2 == id1) {
      id2 = random.nextInt(totalCount) + 1;
    }
    
    // Fetch both hadiths
    final response1 = await _supabase
        .from('hadiths')
        .select('text, source')
        .eq('id', id1)
        .single();
    
    final response2 = await _supabase
        .from('hadiths')
        .select('text, source')
        .eq('id', id2)
        .single();

    return [
      {
        'text': response1['text'] as String,
        'source': response1['source'] as String,
      },
      {
        'text': response2['text'] as String,
        'source': response2['source'] as String,
      },
    ];
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, String>> _getFallbackHadiths() {
    return [
      {
        'text': 'The best among you are those who have the best manners and character.',
        'source': 'Sahih Bukhari',
      },
      {
        'text': 'None of you truly believes until he loves for his brother what he loves for himself.',
        'source': 'Sahih Bukhari & Muslim',
      },
    ];
  }
}
