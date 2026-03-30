import 'package:supabase_flutter/supabase_flutter.dart';
import 'prayer_times_service.dart';
import 'daily_content_service.dart';

class SharedData {
  SharedData._();
  static final instance = SharedData._();

  // --- SIMULATION CONFIG ---
  // Set to true to enable keyboard shortcuts and UI for time testing
  static const bool configEnableSimulation = false;

  DateTime? _overrideTime;
  DateTime get now => (configEnableSimulation && _overrideTime != null) ? _overrideTime! : DateTime.now();
  bool get isSimulated => configEnableSimulation && _overrideTime != null;

  String sunrise = '';
  String sunset = '';
  String jummah = '';
  String hijriDate = '';
  int hijriMonth = 1;
  int hijriDay = 1;
  List<Map<String, String>> prayers = [];
  DateTime? _nextIqamahTarget;
  List<DateTime> _iqamahDateTimes = [];

  Map<String, String> currentHadith = {'text': '', 'source': ''};
  Map<String, String> currentDua = {'text': '', 'source': ''};
  Map<String, String> currentVerse = {'text': '', 'source': ''};

  bool _isFetching = false;

  Future<void> init() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      await _fetchFromApi();
      await _loadIqamahFromDb();
      _calculateLastThird();
      _computeNextTarget();
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refreshIqamah() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      await _loadIqamahFromDb();
      _calculateLastThird();
      _computeNextTarget();
    } finally {
      _isFetching = false;
    }
  }

  Future<void> recompute() async {
    _updateIqamahDateTimes();
    _calculateLastThird();
    _computeNextTarget();
  }

  void _updateIqamahDateTimes() {
    final now = this.now;
    final isFriday = now.weekday == DateTime.friday;
    final times = <DateTime>[];
    
    // Use the strings we already have in the prayers list
    for (final p in prayers) {
      final prayer = p['name']!.toLowerCase();
      // Skip zuhr on Friday and jumu'ah on non-Friday
      if (isFriday && prayer == 'dhuhr') continue;
      if (!isFriday && prayer.startsWith('jumu')) continue;
      
      final dt = _parseTime(p['iqamah']!, now);
      if (dt != null) times.add(dt);
    }
    
    // Also include Jumu'ah explicitly if needed
    if (isFriday && jummah.isNotEmpty) {
      final jDt = _parseTime(jummah, now);
      if (jDt != null && !times.any((t) => t.hour == jDt.hour && t.minute == jDt.minute)) {
        times.add(jDt);
      }
    }

    times.sort();
    _iqamahDateTimes = times;
  }

  void setOverrideTime(DateTime? time) {
    final oldDate = _overrideTime ?? DateTime.now();
    _overrideTime = time;
    final newDate = this.now;
    
    // If the date (Y-M-D) has changed, re-fetch from API to update Hijri date and timings
    if (oldDate.year != newDate.year || oldDate.month != newDate.month || oldDate.day != newDate.day) {
      _fetchFromApi().then((_) {
        recompute();
        // Also fetch daily content for the new day
        fetchDailyContent();
      });
    } else {
      recompute();
    }
  }

  void setManualTime(String dateTimeStr) {
    try {
      final oldDate = this.now;
      _overrideTime = DateTime.parse(dateTimeStr);
      final newDate = this.now;

      if (oldDate.year != newDate.year || oldDate.month != newDate.month || oldDate.day != newDate.day) {
        _fetchFromApi().then((_) => recompute());
      } else {
        recompute();
      }
    } catch (_) {}
  }

  Future<void> fetchDailyContent() async {
    try {
      currentHadith = await DailyContentService(tableName: 'hadiths', fallback: {'text': '', 'source': ''}).getTodaysContent();
      currentDua = await DailyContentService(tableName: 'duas', fallback: {'text': '', 'source': ''}).getTodaysContent();
      currentVerse = await DailyContentService(tableName: 'verses', fallback: {'text': '', 'source': ''}).getTodaysContent();
    } catch (_) {}
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
    _calculateLastThird();
  }

  String lastThird = '--';

  void _calculateLastThird() {
    if (prayers.isEmpty) return;
    String? fajrStr;
    String? maghribStr;
    
    // Check both uppercase and potential lowercase just in case
    for (final p in prayers) {
      final name = p['name']!.toUpperCase();
      if (name == 'FAJR') fajrStr = p['adhan'];
      if (name == 'MAGHRIB') maghribStr = p['adhan'];
    }
    
    if (fajrStr == null || maghribStr == null) return;

    final now = this.now;
    final fDt = _parseTime(fajrStr, now);
    final mDt = _parseTime(maghribStr, now);

    if (fDt != null && mDt != null) {
      // Logic: Maghrib to Fajr (Next Day)
      final fajrNext = fDt.add(const Duration(days: 1));
      final nightDuration = fajrNext.difference(mDt);
      final oneThirdMins = nightDuration.inMinutes / 3;
      final lastThirdStart = fajrNext.subtract(Duration(minutes: oneThirdMins.round()));
      
      final h = lastThirdStart.hour > 12 ? lastThirdStart.hour - 12 : (lastThirdStart.hour == 0 ? 12 : lastThirdStart.hour);
      final m = lastThirdStart.minute.toString().padLeft(2, '0');
      final p = lastThirdStart.hour >= 12 ? 'PM' : 'AM';
      lastThird = '$h:$m $p';
    }
  }

  Future<void> _loadIqamahFromDb() async {
    try {
      final response = await Supabase.instance.client
          .from('prayer_times')
          .select('prayer, iqamah');
      final now = this.now;
      final isFriday = now.weekday == DateTime.friday;
      final times = <DateTime>[];
      for (final row in response as List) {
        final prayer = row['prayer'] as String;
        if (isFriday && prayer == 'zuhr') continue;
        if (!isFriday && prayer.startsWith('jummah')) continue;
        final dt = _parseTime(row['iqamah'] as String, now);
        if (dt != null) times.add(dt);
      }
      final iqamahMap = <String, String>{};
      for (final row in response as List) {
        iqamahMap[row['prayer'] as String] = row['iqamah'] as String;
      }
      final nameToKey = {'FAJR': 'fajr', 'DHUHR': 'zuhr', 'ASR': 'asr', 'MAGHRIB': 'maghrib', 'ISHA': 'isha'};
      prayers = prayers.map((p) {
        final name = p['name']!;
        if (name.toUpperCase() == 'MAGHRIB') {
          return {
            'name': name,
            'adhan': p['adhan']!,
            'iqamah': _addMinutes(p['adhan']!, 10),
          };
        }
        final key = nameToKey[name];
        final dbIqamah = key != null ? iqamahMap[key] : null;
        return {
          'name': name,
          'adhan': p['adhan']!,
          'iqamah': dbIqamah != null ? _to12(dbIqamah) : p['iqamah']!,
        };
      }).toList();
      times.sort();
      _iqamahDateTimes = times;
    } catch (_) {}
  }

  void _computeNextTarget() {
    final now = this.now;
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
    final now = this.now;
    if (now.isAfter(_nextIqamahTarget!)) {
      _computeNextTarget();
      if (_nextIqamahTarget == null) return '--';
    }
    final totalMin = _nextIqamahTarget!.difference(now).inMinutes + 1;
    if (totalMin >= 60) {
      final hrs = totalMin ~/ 60;
      final mins = totalMin % 60;
      return mins > 0 ? '$hrs HR $mins MIN' : '$hrs HR';
    }
    return '$totalMin MIN';
  }

  /// Index of the prayer whose adhan window we are currently in.
  /// Returns -1 if none determined yet.
  int getCurrentPrayerIndex() {
    if (prayers.isEmpty) return -1;
    final now = this.now;
    final adhans = prayers.map((p) => _parseTime(p['adhan']!, now)).toList();
    int current = -1;
    for (int i = 0; i < adhans.length; i++) {
      if (adhans[i] != null && !now.isBefore(adhans[i]!)) {
        current = i;
      }
    }
    // If it's before the first prayer of the day (Fajr), 
    // the current prayer is the last one of the previous day (Isha).
    if (current == -1 && adhans.isNotEmpty) {
      current = adhans.length - 1;
    }

    // On Fridays, Dhuhr adhan marks the start of Jumu'ah window.
    if (current != -1 && now.weekday == DateTime.friday) {
      if (prayers[current]['name']?.toUpperCase() == 'DHUHR') {
        return -2; // Map Dhuhr to Jumu'ah highlight index 
      }
    }
    return current;
  }

  /// Index of the prayer whose iqamah is the next upcoming one.
  /// Returns -1 if none found, -2 if Jumu'ah.
  int getNextPrayerIndex() {
    if (prayers.isEmpty || _iqamahDateTimes.isEmpty) return -1;
    final now = this.now;
    DateTime? target;
    for (final dt in _iqamahDateTimes) {
      if (dt.isAfter(now)) {
        target = dt;
        break;
      }
    }

    // If no iqamah is after now today, the next one is Fajr (index 0).
    if (target == null) return 0;

    // Check if target matches Jumu'ah time on Fridays
    if (now.weekday == DateTime.friday && jummah.isNotEmpty) {
      final jDt = _parseTime(jummah, now);
      if (jDt != null && jDt.hour == target.hour && jDt.minute == target.minute) {
        return -2; // Special index for Jumu'ah
      }
    }

    // Find the index of the prayer matching this iqamah time.
    for (int i = 0; i < prayers.length; i++) {
      final pDt = _parseTime(prayers[i]['iqamah']!, now);
      if (pDt != null && pDt.hour == target.hour && pDt.minute == target.minute) {
        return i;
      }
    }
    return 0; // Fallback to Fajr
  }

  String getNextPrayerName() {
    final idx = getNextPrayerIndex();
    if (idx == -2) return "JUMU'AH";
    if (idx >= 0 && idx < prayers.length) {
      return prayers[idx]['name']!;
    }
    return "PRAYER";
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

  String _addMinutes(String timeStr, int minutes) {
    final dt = _parseTime(timeStr, now);
    if (dt == null) return timeStr;
    final newDt = dt.add(Duration(minutes: minutes));
    final h = newDt.hour > 12 ? newDt.hour - 12 : (newDt.hour == 0 ? 12 : newDt.hour);
    final m = newDt.minute.toString().padLeft(2, '0');
    final p = newDt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
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
