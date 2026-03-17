import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_data.dart';
import 'prayer_times_service.dart';

enum DisplayMode { normal, silence, prohibited }

class DisplayModeService {
  DisplayMode mode = DisplayMode.normal;
  DateTime? silenceEndTime;
  DateTime? prohibitedEndTime;

  List<String> _iqamahTimes = [];
  String _sunriseTime = '';
  String _sunsetTime = '';
  List<Map<String, String>> _prayersList = [];

  String get sunriseTime => _sunriseTime;
  String get sunsetTime => _sunsetTime;
  List<Map<String, String>> get prayersList => _prayersList;

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

  /// Returns true if mode changed.
  bool checkSilence() {
    if (mode == DisplayMode.silence) {
      if (DateTime.now().isAfter(silenceEndTime!)) {
        mode = DisplayMode.normal;
        silenceEndTime = null;
        return true;
      }
      return false;
    }

    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final iqamah in _iqamahTimes) {
      if (iqamah == currentTime) {
        mode = DisplayMode.silence;
        silenceEndTime = now.add(const Duration(minutes: 15));
        return true;
      }
    }

    // Friday Jumu'ah: 45 min silence
    if (now.weekday == DateTime.friday && mode != DisplayMode.silence) {
      final jummahTime = SharedData.instance.jummah;
      if (jummahTime.isNotEmpty) {
        final jummahDt = _parseTimeToday(jummahTime);
        if (jummahDt != null) {
          final jummahEnd = jummahDt.add(const Duration(minutes: 45));
          if (now.isAfter(jummahDt) && now.isBefore(jummahEnd)) {
            mode = DisplayMode.silence;
            silenceEndTime = jummahEnd;
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Returns true if mode changed.
  bool checkProhibited() {
    if (mode == DisplayMode.prohibited) {
      if (DateTime.now().isAfter(prohibitedEndTime!)) {
        mode = DisplayMode.normal;
        prohibitedEndTime = null;
        return true;
      }
      return false;
    }

    final now = DateTime.now();
    final sunriseDt = _parseTimeToday(_sunriseTime);
    final sunsetDt = _parseTimeToday(_sunsetTime);
    if (sunriseDt == null || sunsetDt == null) return false;

    // 15 min after sunrise
    final sunriseEnd = sunriseDt.add(const Duration(minutes: 15));
    if (now.isAfter(sunriseDt) && now.isBefore(sunriseEnd)) {
      mode = DisplayMode.prohibited;
      prohibitedEndTime = sunriseEnd;
      return true;
    }

    // 15 min before sunset
    final sunsetStart = sunsetDt.subtract(const Duration(minutes: 15));
    if (now.isAfter(sunsetStart) && now.isBefore(sunsetDt)) {
      mode = DisplayMode.prohibited;
      prohibitedEndTime = sunsetDt;
      return true;
    }

    // 15 min before Dhuhr start (solar zenith)
    final dhuhrStart = _prayersList
        .where((p) => p['name'] == 'DHUHR')
        .map((p) => _parseTimeToday(p['start']!))
        .firstOrNull;
    if (dhuhrStart != null) {
      final dhuhrProhibitedStart = dhuhrStart.subtract(const Duration(minutes: 15));
      if (now.isAfter(dhuhrProhibitedStart) && now.isBefore(dhuhrStart)) {
        mode = DisplayMode.prohibited;
        prohibitedEndTime = dhuhrStart;
        return true;
      }
    }
    return false;
  }

  void setTestSilence() {
    mode = mode == DisplayMode.silence ? DisplayMode.normal : DisplayMode.silence;
    if (mode == DisplayMode.silence) {
      silenceEndTime = DateTime.now().add(const Duration(hours: 1));
    }
  }

  void setTestProhibited() {
    mode = mode == DisplayMode.prohibited ? DisplayMode.normal : DisplayMode.prohibited;
    if (mode == DisplayMode.prohibited) {
      prohibitedEndTime = DateTime.now().add(const Duration(minutes: 15));
    }
  }

  void exitSpecialMode() {
    mode = DisplayMode.normal;
    silenceEndTime = null;
    prohibitedEndTime = null;
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
