import 'package:supabase_flutter/supabase_flutter.dart';
import 'prayer_times_service.dart';

class SharedData {
  SharedData._();
  static final instance = SharedData._();

  String sunrise = '';
  String sunset = '';
  DateTime? _nextIqamahTarget;
  List<DateTime> _iqamahDateTimes = [];

  Future<void> init() async {
    final service = PrayerTimesService();
    final data = await service.fetchPrayerTimes();
    if (data != null) {
      sunrise = data['sunrise'] as String;
      sunset = data['sunset'] as String;
    }
    await _loadIqamahTimes();
    _computeNextTarget();
  }

  Future<void> refreshIqamah() async {
    await _loadIqamahTimes();
    _computeNextTarget();
  }

  Future<void> _loadIqamahTimes() async {
    try {
      final response = await Supabase.instance.client
          .from('prayer_times')
          .select('iqamah');
      final now = DateTime.now();
      final times = <DateTime>[];
      for (final row in response as List) {
        final dt = _parseTime(row['iqamah'] as String, now);
        if (dt != null) times.add(dt);
      }
      times.sort();
      _iqamahDateTimes = times;
    } catch (_) {}
  }

  void _computeNextTarget() {
    final now = DateTime.now();
    _nextIqamahTarget = null;
    for (final dt in _iqamahDateTimes) {
      if (dt.isAfter(now)) {
        _nextIqamahTarget = dt;
        return;
      }
    }
    // All passed today — wrap to first iqamah (Fajr) tomorrow
    if (_iqamahDateTimes.isNotEmpty) {
      final first = _iqamahDateTimes.first;
      _nextIqamahTarget = first.add(const Duration(days: 1));
    }
  }

  String getCountdown() {
    if (_nextIqamahTarget == null) return '--';

    final now = DateTime.now();
    if (now.isAfter(_nextIqamahTarget!)) {
      _computeNextTarget();
      if (_nextIqamahTarget == null) return '--';
    }

    final totalMin = _nextIqamahTarget!.difference(now).inMinutes;
    if (totalMin >= 60) {
      final hrs = totalMin ~/ 60;
      final mins = totalMin % 60;
      return mins > 0 ? '${hrs}HR ${mins}MIN' : '${hrs}HR';
    }
    return '${totalMin}MIN';
  }

  DateTime? _parseTime(String time, DateTime now) {
    try {
      final trimmed = time.trim();
      if (!trimmed.contains('AM') && !trimmed.contains('PM')) {
        final parts = trimmed.split(':');
        return DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
      }
      final parts = trimmed.split(' ');
      final tp = parts[0].split(':');
      var h = int.parse(tp[0]);
      final m = int.parse(tp[1]);
      if (parts[1] == 'PM' && h != 12) h += 12;
      if (parts[1] == 'AM' && h == 12) h = 0;
      return DateTime(now.year, now.month, now.day, h, m);
    } catch (_) {
      return null;
    }
  }
}
