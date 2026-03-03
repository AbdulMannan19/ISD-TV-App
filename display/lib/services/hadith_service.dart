import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class HadithService {
  final Random _random = Random();
  final _supabase = Supabase.instance.client;

  /// Get a random hadith from Supabase
  Future<Map<String, String>> getRandomHadith() async {
    try {
      // Get total count
      final countResponse = await _supabase
          .from('hadiths')
          .select('id', const FetchOptions(count: CountOption.exact, head: true));
      
      final totalCount = countResponse.count ?? 1000;
      
      // Pick a random ID (1 to totalCount)
      final randomId = _random.nextInt(totalCount) + 1;
      
      // Fetch that hadith
      final response = await _supabase
          .from('hadiths')
          .select('text, source')
          .eq('id', randomId)
          .single();

      return {
        'text': response['text'] as String,
        'source': response['source'] as String,
      };
    } catch (e) {
      print('Error getting hadith from Supabase: $e');
      return _getFallbackHadith();
    }
  }

  Map<String, String> _getFallbackHadith() {
    final fallbacks = [
      {
        'text': 'The best among you are those who have the best manners and character.',
        'source': 'Sahih Bukhari',
      },
      {
        'text': 'None of you truly believes until he loves for his brother what he loves for himself.',
        'source': 'Sahih Bukhari & Muslim',
      },
      {
        'text': 'Make things easy and do not make them difficult, cheer the people up by conveying glad tidings to them and do not repulse them.',
        'source': 'Sahih Bukhari',
      },
      {
        'text': 'Whoever believes in Allah and the Last Day, let him speak good or remain silent.',
        'source': 'Sahih Bukhari & Muslim',
      },
    ];
    return fallbacks[_random.nextInt(fallbacks.length)];
  }
}
