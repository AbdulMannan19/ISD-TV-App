import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DuaService {
  final _supabase = Supabase.instance.client;
  static const String _cacheKey = 'cached_dua';
  static const String _cacheDateKey = 'cached_dua_date';

  Future<Map<String, String>> getTodaysDua() async {
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
      
      final dua = await _fetchDuaFromSupabase();
      
      await prefs.setString(_cacheKey, json.encode(dua));
      await prefs.setString(_cacheDateKey, today);
      
      return dua;
    } catch (e) {
      print('Error getting dua: $e');
      return _getFallbackDua();
    }
  }

  Future<Map<String, String>> _fetchDuaFromSupabase() async {
    final countResponse = await _supabase
        .from('duas')
        .select('id')
        .count(CountOption.exact);
    
    final totalCount = countResponse.count ?? 0;
    
    if (totalCount == 0) {
      return _getFallbackDua();
    }
    
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day + 1;
    final random = Random(seed);
    
    final id = random.nextInt(totalCount) + 1;
    
    final response = await _supabase
        .from('duas')
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

  Map<String, String> _getFallbackDua() {
    return {
      'text': 'Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.',
      'source': 'Quran 2:201',
    };
  }
}
