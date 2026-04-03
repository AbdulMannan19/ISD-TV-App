import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_data.dart';

class DailyContentService {
  final String tableName;
  final Map<String, String> _fallback;
  final bool fetchSecondContent;

  DailyContentService({
    required this.tableName,
    required Map<String, String> fallback,
    this.fetchSecondContent = false,
  }) : _fallback = fallback;

  Future<Map<String, String>> getTodaysContent() async {
    try {
      return await _fetchFromSupabase();
    } catch (_) {
      return _fallback;
    }
  }

  Future<Map<String, String>> _fetchFromSupabase() async {
    final hijriMonth = SharedData.instance.hijriMonth;
    final hijriDay = SharedData.instance.hijriDay;
    final id = (hijriMonth - 1) * 30 + hijriDay;

    final selectCols = fetchSecondContent ? 'text, source, text2, source2' : 'text, source';
    final response = await Supabase.instance.client
        .from(tableName)
        .select(selectCols)
        .eq('id', id)
        .single();

    final result = {
      'text': response['text'] as String,
      'source': response['source'] as String,
    };
    if (fetchSecondContent) {
      result['text2'] = (response['text2'] as String?) ?? '';
      result['source2'] = (response['source2'] as String?) ?? '';
    }
    return result;
  }
}
