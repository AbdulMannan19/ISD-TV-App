import 'dart:async';
import 'dart:ui';
import 'shared_data.dart';

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

  void setOnModeChanged(VoidCallback callback) {
    _onModeChanged = callback;
  }

  Future<void> refreshIqamahFromDb() async {
    await SharedData.instance.refreshIqamah();
    reevaluate();
  }

  void reevaluate() {
    _silenceTimer?.cancel();
    _prohibitedTimer?.cancel();
    _iqamahLockTimer?.cancel();

    // Determine the correct mode based on current time
    final now = DateTime.now();
    final shared = SharedData.instance;

    // Check if we're in a silence window (past an iqamah, within silence duration)
    final iqamahDts = <DateTime>[];
    for (final p in shared.prayers) {
      final dt = _parseTimeToday(p['iqamah']!);
      if (dt != null) iqamahDts.add(dt);
    }
    if (now.weekday == DateTime.friday && shared.jummah.isNotEmpty) {
      final jDt = _parseTimeToday(shared.jummah);
      if (jDt != null) iqamahDts.add(jDt);
    }

    // Check silence: iqamah passed but within silence duration
    for (final iq in iqamahDts) {
      if (now.isAfter(iq)) {
        final isFridayJummah = now.weekday == DateTime.friday &&
            shared.jummah.isNotEmpty &&
            _parseTimeToday(shared.jummah) == iq;
        final silenceMins = isFridayJummah ? 45 : 10;
        final silenceEnd = iq.add(Duration(minutes: silenceMins));
        if (now.isBefore(silenceEnd)) {
          mode = DisplayMode.silence;
          silenceEndTime = silenceEnd;
          prohibitedEndTime = null;
          iqamahLockEndTime = null;
          _onModeChanged?.call();
          _scheduleSilenceExit();
          return;
        }
      }
    }

    // Check iqamah lock: 5 min before iqamah
    for (final iq in iqamahDts) {
      final lockStart = iq.subtract(const Duration(minutes: 5));
      if (now.isAfter(lockStart) && now.isBefore(iq)) {
        mode = DisplayMode.iqamahLock;
        iqamahLockEndTime = iq;
        silenceEndTime = null;
        prohibitedEndTime = null;
        _onModeChanged?.call();
        _iqamahLockTimer = Timer(iq.difference(now), () {
          _enterSilenceFromLock(iq);
        });
        return;
      }
    }

    // Otherwise normal — schedule future timers
    mode = DisplayMode.normal;
    silenceEndTime = null;
    prohibitedEndTime = null;
    iqamahLockEndTime = null;
    scheduleProhibited();
    scheduleIqamahLock();
    _onModeChanged?.call();
  }

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

  void scheduleProhibited() {
    _prohibitedTimer?.cancel();
    final now = DateTime.now();
    final shared = SharedData.instance;

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

    final windows = <List<DateTime>>[];
    final sunriseDt = _parseTimeToday(shared.sunrise);
    final sunsetDt = _parseTimeToday(shared.sunset);

    if (sunriseDt != null) {
      windows.add([sunriseDt, sunriseDt.add(const Duration(minutes: 15))]);
    }
    if (sunsetDt != null) {
      windows.add([sunsetDt.subtract(const Duration(minutes: 15)), sunsetDt]);
    }

    final dhuhrStart = shared.prayers
        .where((p) => p['name'] == 'DHUHR')
        .map((p) => _parseTimeToday(p['adhan']!))
        .firstOrNull;
    if (dhuhrStart != null) {
      windows.add([dhuhrStart.subtract(const Duration(minutes: 15)), dhuhrStart]);
    }

    for (final w in windows) {
      if (now.isAfter(w[0]) && now.isBefore(w[1])) {
        mode = DisplayMode.prohibited;
        prohibitedEndTime = w[1];
        _onModeChanged?.call();
        scheduleProhibited();
        return;
      }
    }

    final futureStarts = windows.where((w) => w[0].isAfter(now)).toList();
    if (futureStarts.isEmpty) return;
    futureStarts.sort((a, b) => a[0].compareTo(b[0]));

    final nextWindow = futureStarts.first;
    _prohibitedTimer = Timer(nextWindow[0].difference(now), () {
      mode = DisplayMode.prohibited;
      prohibitedEndTime = nextWindow[1];
      _onModeChanged?.call();
      scheduleProhibited();
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

  void scheduleIqamahLock() {
    _iqamahLockTimer?.cancel();
    final now = DateTime.now();
    final shared = SharedData.instance;

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

    final iqamahDts = <DateTime>[];
    for (final p in shared.prayers) {
      final dt = _parseTimeToday(p['iqamah']!);
      if (dt != null) iqamahDts.add(dt);
    }
    if (now.weekday == DateTime.friday && shared.jummah.isNotEmpty) {
      final jDt = _parseTimeToday(shared.jummah);
      if (jDt != null) iqamahDts.add(jDt);
    }
    if (iqamahDts.isEmpty) return;

    final upcoming = <List<DateTime>>[];
    for (final iq in iqamahDts) {
      final lockStart = iq.subtract(const Duration(minutes: 5));
      if (now.isAfter(lockStart) && now.isBefore(iq)) {
        mode = DisplayMode.iqamahLock;
        iqamahLockEndTime = iq;
        _onModeChanged?.call();
        scheduleIqamahLock();
        return;
      }
      if (lockStart.isAfter(now)) {
        upcoming.add([lockStart, iq]);
      }
    }

    if (upcoming.isEmpty) return;
    upcoming.sort((a, b) => a[0].compareTo(b[0]));
    final next = upcoming.first;

    _iqamahLockTimer = Timer(next[0].difference(now), () {
      mode = DisplayMode.iqamahLock;
      iqamahLockEndTime = next[1];
      _onModeChanged?.call();
      scheduleIqamahLock();
    });
  }

  void _enterSilenceFromLock(DateTime iqamahTime) {
    iqamahLockEndTime = null;
    final isFridayJummah = DateTime.now().weekday == DateTime.friday &&
        SharedData.instance.jummah.isNotEmpty &&
        _parseTimeToday(SharedData.instance.jummah) == iqamahTime;
    final duration = isFridayJummah ? 45 : 10;

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
      final trimmed = time.trim();
      final now = DateTime.now();
      if (trimmed.contains('AM') || trimmed.contains('PM')) {
        final parts = trimmed.split(' ');
        final tp = parts[0].split(':');
        var hour = int.parse(tp[0]);
        final minute = int.parse(tp[1]);
        if (parts[1] == 'PM' && hour != 12) hour += 12;
        if (parts[1] == 'AM' && hour == 12) hour = 0;
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
      final parts = trimmed.split(':');
      return DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }
}
