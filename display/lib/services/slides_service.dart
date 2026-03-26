import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_data.dart';

class SlidesService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getActiveSlides() async {
    try {
      final response = await _supabase
          .from('slides')
          .select('*')
          .order('display_order', ascending: true);

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final dayName = _dayName(now.weekday);

      return List<Map<String, dynamic>>.from(response)
          .where((row) => row['is_active'] != false)
          .where((row) => _matchesDate(row, todayStr))
          .where((row) => _matchesDay(row, dayName))
          .where((row) => _matchesTime(row, now))
          .toList();
    } catch (_) {
      return [];
    }
  }

  bool _matchesDate(Map<String, dynamic> row, String todayStr) {
    final start = row['start_date'] as String?;
    final end = row['end_date'] as String?;
    if (start != null && start.isNotEmpty && todayStr.compareTo(start) < 0) return false;
    if (end != null && end.isNotEmpty && todayStr.compareTo(end) > 0) return false;
    return true;
  }

  bool _matchesDay(Map<String, dynamic> row, String dayName) {
    final day = (row['day_of_week'] as String?) ?? 'all';
    return day == 'all' || day == dayName;
  }

  bool _matchesTime(Map<String, dynamic> row, DateTime now) {
    final startType = (row['start_time_type'] as String?) ?? 'fixed';
    final startVal = (row['start_time_value'] as String?) ?? '';
    final endType = (row['end_time_type'] as String?) ?? 'fixed';
    final endVal = (row['end_time_value'] as String?) ?? '';

    final startMin = _resolveTimeMinutes(startType, startVal, now);
    final endMin = _resolveTimeMinutes(endType, endVal, now);
    final nowMin = now.hour * 60 + now.minute;

    if (startMin != null && nowMin < startMin) return false;
    if (endMin != null && nowMin > endMin) return false;
    return true;
  }

  int? _resolveTimeMinutes(String type, String value, DateTime now) {
    if (value.isEmpty) return null;
    if (type == 'iqamah') {
      return _iqamahMinutes(value, now);
    }
    // Fixed time — could be "HH:MM" or "H:MM AM/PM"
    return _parseTimeToMinutes(value);
  }

  int? _iqamahMinutes(String prayer, DateTime now) {
    final shared = SharedData.instance;
    // Find iqamah time for this prayer from shared data
    final nameMap = {'fajr': 'FAJR', 'zuhr': 'DHUHR', 'asr': 'ASR', 'maghrib': 'MAGHRIB', 'isha': 'ISHA'};
    final prayerName = nameMap[prayer];
    if (prayerName == null) return null;
    for (final p in shared.prayers) {
      if (p['name'] == prayerName) {
        final iqamah = p['iqamah'];
        if (iqamah == null) return null;
        return _parseTimeToMinutes(iqamah);
      }
    }
    return null;
  }

  int? _parseTimeToMinutes(String time) {
    try {
      final t = time.trim();
      if (t.contains('AM') || t.contains('PM')) {
        final parts = t.split(' ');
        final tp = parts[0].split(':');
        var h = int.parse(tp[0]);
        final m = int.parse(tp[1]);
        if (parts[1] == 'PM' && h != 12) h += 12;
        if (parts[1] == 'AM' && h == 12) h = 0;
        return h * 60 + m;
      }
      final parts = t.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (_) {
      return null;
    }
  }

  String _dayName(int weekday) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[weekday - 1];
  }
}
