import 'package:supabase_flutter/supabase_flutter.dart';

class IqamahScheduleService {
  static final _supabase = Supabase.instance.client;

  static Future<void> applyScheduledChanges() async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('iqamah_schedule')
          .select('*')
          .lte('effective_date', todayStr);

      final rows = response as List;
      if (rows.isEmpty) return;

      for (final row in rows) {
        final prayer = row['prayer'] as String;
        final iqamah = row['iqamah'] as String;
        final id = row['id'];

        try {
          await _supabase
              .from('prayer_times')
              .update({'iqamah': iqamah})
              .eq('prayer', prayer);
        } catch (_) {
          continue;
        }

        try {
          await _supabase.from('iqamah_schedule').delete().eq('id', id);
        } catch (_) {}
      }
    } catch (_) {}
  }
}
