import 'package:supabase_flutter/supabase_flutter.dart';
import 'prayer_times_service.dart';

class SharedData {
  SharedData._();
  static final instance = SharedData._();

  String sunrise = '';
  String sunset = '';
  String jummah = '';
  String hijriDate = '';
  int hijriMonth = 1;
  int hijriDay = 1;
  List<Map<String, String>> prayers = [];
  DateTime? _nextIqamahTarget;
  List<DateTime> _iqamahDateTimes = [];

  /// Full init: fetches prayer times from Aladhan API + iqamah from DB.
  /// Call ONCE on startup and at midnight (new Gregorian day = new prayer times).
  Future<void> init() async {
    await _fetchFromApi();
    await _loadIqamahFromDb();
    _computeNextTarget();
  }

  /// Refresh only iqamah times from DB (no API call).
  /// Call when iqamah times change in the database.
  Future<void> refreshIqamah() async {
    await _loadIqamahFromDb();
    _computeNextTarget();
  }

  Future<void> _fetchFromApi() async {
    final data = await PrayerTimesService().fetchPrayerTimes();
    if (data == null) return;
    sunrise = data['sunrise'] as String;
    sunset = data['sunset'] as String;
    jummah = data['jummah'] as String;
    hijriDate = data['hijriDate'] as String;
    hijriMonth = data['hijriMonth'] as int;
    hijriDay = data['hijriDay'] as int;
    prayers = (data['prayers'] as List).map((p) => {
      'name': p['name'] as String,
      'adhan': p['adhan'] as String,
      'iqamah': p['iqamah'] as String,
    }).toList();
  }

  Future<void> _loadIqamahFromDb() async {
    try {
      final response = await Supabase.instance.client
          .from('prayer_times')
          .select('prayer, iqamah');
      final now = DateTime.now();
      final isFriday = now.weekday == DateTime.friday;
      final times = <DateTime>[];
      for (final row in response as List) {
        final prayer = row['prayer'] as String;
        if (isFriday && prayer == 'zuhr') continue;
        if (!isFriday && prayer.startsWith('jummah')) continue;
        final dt = _parseTime(row['iqamah'] as String, now);
        if (dt != null) times.add(dt);
      }
      // Also update iqamah in prayers list from DB
      final iqamahMap = <String, String>{};
      for (final row in response as List) {
        iqamahMap[row['prayer'] as String] = row['iqamah'] as String;
      }
      final nameToKey = {'FAJR': 'fajr', 'DHUHR': 'zuhr', 'ASR': 'asr', 'MAGHRIB': 'maghrib', 'ISHA': 'isha'};
      prayers = prayers.map((p) {
        final key = nameToKey[p['name']];
        final dbIqamah = key != null ? iqamahMap[key] : null;
        return {
          'name': p['name']!,
          'adhan': p['adhan']!,
          'iqamah': dbIqamah != null ? _to12(dbIqamah) : p['iqamah']!,
        };
      }).toList();
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

  String _to12(String time) {
    if (time.contains('AM') || time.contains('PM')) return time;
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final p = hour >= 12 ? 'PM' : 'AM';
    return '$h:${minute.toString().padLeft(2, '0')} $p';
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
