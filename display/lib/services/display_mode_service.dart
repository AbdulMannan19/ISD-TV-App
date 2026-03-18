import 'dart:async';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_data.dart';
import 'prayer_times_service.dart';

enum DisplayMode { normal, silence, prohibited, iqamahLock }

class DisplayModeService {
  DisplayMode mode = DisplayMode.normal;
  DateTime? silenceEndTime;
  DateTime? prohibitedEndTime;
  DateTime? iqamahLockEndTime;

  Timer? _silenceTimer;
  Timer? _prohibitedTimer;
  Timer? _iqamahLockTimer;
  VoidCallback? _onModeChanged;

  List<String> _iqamahTimes = [];
  String _sunriseTime = '';
  String _sunsetTime = '';
  List<Map<String, String>> _prayersList = [];

  String get sunriseTime => _sunriseTime;
  String get sunsetTime => _sunsetTime;
  List<Map<String, String>> get prayersList => _prayersList;

  void setOnModeChanged(VoidCallback callback) {
    _onModeChanged = callback;
  }

  Future<void> fetchPrayerData() async {
    try {
      final data = await PrayerTimesService().fetchPrayerTimes();
      if (data == null) return;
      _prayersList = (data['prayers'] as List).map((p) => {
        'name': p['name'] as String,
        'start': p['adhan'] as String,
        'iqamah': p['iqamah'] as String,
      }).toList();
      _sunriseTime = data['sunrise'] as String;
      _sunsetTime = data['sunset'] as String;
    } catch (e) {
      print('Error fetching prayer data: $e');
    }
  }

  Future<void> fetchIqamahTimes() async {
    try {
      final response = await Supabase.instance.client
          .from('prayer_times')
          .select('prayer, iqamah');
      final now = DateTime.now();
      final isFriday = now.weekday == DateTime.friday;
      final times = <String>[];
      for (final row in response as List) {
        final prayer = row['prayer'] as String;
        if (isFriday && prayer == 'zuhr') continue;
        if (prayer.startsWith('jummah')) continue;
        times.add(row['iqamah'] as String);
      }
      _iqamahTimes = times;
      await SharedData.instance.refreshIqamah();
    } catch (e) {
      print('Error fetching iqamah times: $e');
    }
  }

  /// Schedule silence exit. Called when silence mode is active.
  /// Silence is entered by iqamahLock exit — not independently scheduled.
  void _scheduleSilenceExit() {
    _silenceTimer?.cancel();
    if (mode != DisplayMode.silence || silenceEndTime == null) return;
    final remaining = silenceEndTime!.difference(DateTime.now());
    if (remaining.isNegative) {
      mode = DisplayMode.normal;
      silenceEndTime = null;
      _onModeChanged?.call();
      scheduleIqamahLock();
      return;
    }
    _silenceTimer = Timer(remaining, () {
      mode = DisplayMode.normal;
      silenceEndTime = null;
      _onModeChanged?.call();
      scheduleIqamahLock();
    });
  }

  /// Schedule the next prohibited time screen. Calculates exact time until
  /// next prohibited window, fires once, shows for duration, then reschedules.
  void scheduleProhibited() {
    _prohibitedTimer?.cancel();
    final now = DateTime.now();

    // If currently in prohibited mode, schedule exit
    if (mode == DisplayMode.prohibited && prohibitedEndTime != null) {
      final remaining = prohibitedEndTime!.difference(now);
      if (remaining.isNegative) {
        mode = DisplayMode.normal;
        prohibitedEndTime = null;
        _onModeChanged?.call();
        scheduleProhibited();
      } else {
        _prohibitedTimer = Timer(remaining, () {
          mode = DisplayMode.normal;
          prohibitedEndTime = null;
          _onModeChanged?.call();
          scheduleProhibited();
        });
      }
      return;
    }

    // Build list of prohibited windows: (start, end)
    final windows = <List<DateTime>>[];
    final sunriseDt = _parseTimeToday(_sunriseTime);
    final sunsetDt = _parseTimeToday(_sunsetTime);

    if (sunriseDt != null) {
      windows.add([sunriseDt, sunriseDt.add(const Duration(minutes: 15))]);
    }
    if (sunsetDt != null) {
      windows.add([sunsetDt.subtract(const Duration(minutes: 15)), sunsetDt]);
    }

    final dhuhrStart = _prayersList
        .where((p) => p['name'] == 'DHUHR')
        .map((p) => _parseTimeToday(p['start']!))
        .firstOrNull;
    if (dhuhrStart != null) {
      windows.add([dhuhrStart.subtract(const Duration(minutes: 15)), dhuhrStart]);
    }

    // Check if we're currently inside a window
    for (final w in windows) {
      if (now.isAfter(w[0]) && now.isBefore(w[1])) {
        mode = DisplayMode.prohibited;
        prohibitedEndTime = w[1];
        _onModeChanged?.call();
        scheduleProhibited(); // Schedule exit
        return;
      }
    }

    // Find next upcoming window start
    final futureStarts = windows.where((w) => w[0].isAfter(now)).toList();
    if (futureStarts.isEmpty) return;
    futureStarts.sort((a, b) => a[0].compareTo(b[0]));

    final nextWindow = futureStarts.first;
    final delay = nextWindow[0].difference(now);

    _prohibitedTimer = Timer(delay, () {
      mode = DisplayMode.prohibited;
      prohibitedEndTime = nextWindow[1];
      _onModeChanged?.call();
      scheduleProhibited(); // Schedule exit
    });
  }

  void setTestSilence() {
    _silenceTimer?.cancel();
    if (mode == DisplayMode.silence) {
      mode = DisplayMode.normal;
      silenceEndTime = null;
      scheduleIqamahLock();
    } else {
      mode = DisplayMode.silence;
      silenceEndTime = DateTime.now().add(const Duration(hours: 1));
      _scheduleSilenceExit();
    }
  }

  void setTestProhibited() {
    _prohibitedTimer?.cancel();
    if (mode == DisplayMode.prohibited) {
      mode = DisplayMode.normal;
      prohibitedEndTime = null;
      scheduleProhibited();
    } else {
      mode = DisplayMode.prohibited;
      prohibitedEndTime = DateTime.now().add(const Duration(minutes: 15));
      scheduleProhibited();
    }
  }

  /// Schedule iqamah lock: 5 min before each iqamah, lock to prayer times screen
  /// until iqamah time. When lock ends, transitions directly into silence mode.
  void scheduleIqamahLock() {
    _iqamahLockTimer?.cancel();
    final now = DateTime.now();

    // If currently in iqamahLock mode, schedule exit → silence
    if (mode == DisplayMode.iqamahLock && iqamahLockEndTime != null) {
      final remaining = iqamahLockEndTime!.difference(now);
      if (remaining.isNegative) {
        _enterSilenceFromLock(iqamahLockEndTime!);
        return;
      }
      _iqamahLockTimer = Timer(remaining, () {
        _enterSilenceFromLock(iqamahLockEndTime!);
      });
      return;
    }

    // Build list of iqamah DateTimes for today
    final iqamahDts = <DateTime>[];
    for (final t in _iqamahTimes) {
      final dt = _parseTimeToday(t);
      if (dt != null) iqamahDts.add(dt);
    }
    // Friday jumu'ah
    if (now.weekday == DateTime.friday) {
      final jummahTime = SharedData.instance.jummah;
      if (jummahTime.isNotEmpty) {
        final jDt = _parseTimeToday(jummahTime);
        if (jDt != null) iqamahDts.add(jDt);
      }
    }
    if (iqamahDts.isEmpty) return;

    // Find next lock start (5 min before iqamah) that's in the future
    final upcoming = <List<DateTime>>[]; // [lockStart, iqamahTime]
    for (final iq in iqamahDts) {
      final lockStart = iq.subtract(const Duration(minutes: 5));
      // Check if we're currently inside a lock window
      if (now.isAfter(lockStart) && now.isBefore(iq)) {
        mode = DisplayMode.iqamahLock;
        iqamahLockEndTime = iq;
        _onModeChanged?.call();
        scheduleIqamahLock(); // Schedule exit → silence
        return;
      }
      if (lockStart.isAfter(now)) {
        upcoming.add([lockStart, iq]);
      }
    }

    if (upcoming.isEmpty) return;
    upcoming.sort((a, b) => a[0].compareTo(b[0]));
    final next = upcoming.first;
    final delay = next[0].difference(now);

    _iqamahLockTimer = Timer(delay, () {
      mode = DisplayMode.iqamahLock;
      iqamahLockEndTime = next[1];
      _onModeChanged?.call();
      scheduleIqamahLock(); // Schedule exit → silence
    });
  }

  /// Transition from iqamahLock into silence mode.
  /// 45 min for jumu'ah on Friday, 15 min otherwise.
  void _enterSilenceFromLock(DateTime iqamahTime) {
    iqamahLockEndTime = null;
    final isFridayJummah = DateTime.now().weekday == DateTime.friday &&
        SharedData.instance.jummah.isNotEmpty &&
        _parseTimeToday(SharedData.instance.jummah) == iqamahTime;
    final duration = isFridayJummah ? 45 : 15;

    mode = DisplayMode.silence;
    silenceEndTime = DateTime.now().add(Duration(minutes: duration));
    _onModeChanged?.call();
    _scheduleSilenceExit();
  }

  void exitSpecialMode() {
    mode = DisplayMode.normal;
    silenceEndTime = null;
    prohibitedEndTime = null;
    iqamahLockEndTime = null;
    _silenceTimer?.cancel();
    scheduleProhibited();
    scheduleIqamahLock();
  }

  void dispose() {
    _silenceTimer?.cancel();
    _prohibitedTimer?.cancel();
    _iqamahLockTimer?.cancel();
  }

  DateTime? _parseTimeToday(String time) {
    try {
      final parts = time.split(' ');
      if (parts.length != 2) return null;
      final timeParts = parts[0].split(':');
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      if (parts[1] == 'PM' && hour != 12) hour += 12;
      if (parts[1] == 'AM' && hour == 12) hour = 0;
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return null;
    }
  }
}
