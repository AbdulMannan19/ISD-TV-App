import 'package:supabase_flutter/supabase_flutter.dart';
import 'prayer_times_service.dart';

class SharedData {
  SharedData._();
  static final instance = SharedData._();

  String sunrise = '';
  String sunset = '';
  String jummah = '';
  String hijriDate = '';
  List<Map<String, String>> prayers = [];
  DateTime? _nextIqamahTarget;
  List<DateTime> _iqamahDateTimes = [];

  Future<void> init() async {
    await _fetchAll();
    await _loadIqamahTimes();
    _computeNextTarget();
  }

  Future<void> refreshIqamah() async {
    await _fetchAll();
    await _loadIqamahTimes();
    _computeNextTarget();
  }

  Future<void> _fetchAll() async {
    final service = PrayerTimesService();
    final data = await service.fetchPrayerTimes();
    if (data == null) return;
    sunrise = data['sunrise'] as String;
    sunset = data['sunset'] as String;
    jummah = data['jummah'] as String;
    hijriDate = data['hijriDate'] as String;
    prayers = (data['prayers'] as List).map((p) => {
      'name': p['name'] as String,
      'adhan': p['adhan'] as String,
      'iqamah': p['iqamah'] as String,
    }).toList();
  }

  Future<void> _loadIqamahTimes() async {
    try {
      final response = await Supabase.instance.client
          .from('prayer_times')
          .select('prayer, iqamah');
      final now = DateTime.now();
      final isFriday = now.weekday == DateTime.friday;
      final times = <DateTime>[];
      for (final row in response as List) {
        final prayer = row['prayer'] as String;
        // On Friday: skip dhuhr, include jummah
        // Other days: skip jummah, include dhuhr
        if (isFriday && prayer == 'zuhr') continue;
        if (!isFriday && prayer.startsWith('jummah')) continue;
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
    if (_iqamahDateTimes.isNotEmpty) {
      _nextIqamahTarget = _iqamahDateTimes.first.add(const Duration(days: 1));
    }
  }

  String getCountdown() {
    if (_nextIqamahTarget == null) return '--';
    final now = DateTime.now();
    if (now.isAfter(_nextIqamahTarget!)) {
      _computeNextTarget();
      if (_nextIqamahTarget == null) return '--';
    }
    final totalMin = _nextIqamahTarget!.difference(now).inMinutes + 1;
    if (totalMin >= 60) {
      final hrs = totalMin ~/ 60;
      final mins = totalMin % 60;
      return mins > 0 ? '${hrs} HR ${mins} MIN' : '${hrs} HR';
    }
    return '${totalMin} MIN';
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
