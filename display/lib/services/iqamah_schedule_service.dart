import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_data.dart';

class IqamahScheduleService {
  static final _supabase = Supabase.instance.client;

  /// Look ahead to tomorrow's scheduled changes and apply only for
  /// prayers whose iqamah has already passed today.
  static Future<void> applyLookaheadChanges() async {
    try {
      final now = SharedData.instance.now;
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('iqamah_schedule')
          .select('*')
          .eq('effective_date', tomorrowStr);

      final rows = response as List;
      if (rows.isEmpty) return;

      // Map DB prayer keys to SharedData prayer names
      const keyToName = {
        'fajr': 'FAJR', 'zuhr': 'DHUHR', 'asr': 'ASR',
        'maghrib': 'MAGHRIB', 'isha': 'ISHA',
      };

      for (final row in rows) {
        final prayer = row['prayer'] as String;
        final iqamah = row['iqamah'] as String;
        final id = row['id'];

        // Find this prayer's current iqamah from in-memory data
        final displayName = keyToName[prayer];
        final prayerData = SharedData.instance.prayers
            .where((p) => p['name'] == displayName)
            .firstOrNull;
        if (prayerData != null) {
          final iqamahDt = _parseTime(prayerData['iqamah']!, now);
          if (iqamahDt != null && !now.isAfter(iqamahDt)) {
            continue; // Prayer hasn't happened yet, skip
          }
        }

        await _supabase
            .from('prayer_times')
            .update({'iqamah': iqamah})
            .eq('prayer', prayer);

        await _supabase.from('iqamah_schedule').delete().eq('id', id);
      }
    } catch (_) {}
  }

  static DateTime? _parseTime(String time, DateTime now) {
    try {
      final trimmed = time.trim();
      if (trimmed.contains('AM') || trimmed.contains('PM')) {
        final parts = trimmed.split(' ');
        final tp = parts[0].split(':');
        var h = int.parse(tp[0]);
        final m = int.parse(tp[1]);
        if (parts[1] == 'PM' && h != 12) h += 12;
        if (parts[1] == 'AM' && h == 12) h = 0;
        return DateTime(now.year, now.month, now.day, h, m);
      }
      final parts = trimmed.split(':');
      return DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }
}
