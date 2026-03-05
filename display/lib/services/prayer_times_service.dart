import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class PrayerTimesService {
  static const String _aladhanApiBase = 'http://api.aladhan.com/v1';
  static const String _city = 'Denton';
  static const String _state = 'TX';
  static const String _country = 'USA';
  static const int _method = 2;

  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> fetchPrayerTimes() async {
    try {
      final now = DateTime.now();
      final url = Uri.parse(
        '$_aladhanApiBase/timingsByCity/${now.day}-${now.month}-${now.year}'
        '?city=$_city&state=$_state&country=$_country&method=$_method',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['code'] != 200 || data['data'] == null) return null;

      final timings = data['data']['timings'] as Map<String, dynamic>;
      final date = data['data']['date']['readable'] as String;

      final fajrAdhan = _cleanTime(timings['Fajr']);
      final dhuhrAdhan = _cleanTime(timings['Dhuhr']);
      final asrAdhan = _cleanTime(timings['Asr']);
      final maghribAdhan = _cleanTime(timings['Maghrib']);
      final ishaAdhan = _cleanTime(timings['Isha']);
      final sunrise = _cleanTime(timings['Sunrise']);

      final maghribIqamah = _addMinutes(maghribAdhan, 10);

      // Fetch iqamah times from DB
      final iqamahTimes = await _fetchIqamahFromDb();
      final fajrIqamah = iqamahTimes['fajr'] ?? _addMinutes(fajrAdhan, 25);
      final dhuhrIqamah = iqamahTimes['zuhr'] ?? _addMinutes(dhuhrAdhan, 19);
      final asrIqamah = iqamahTimes['asr'] ?? _addMinutes(asrAdhan, 19);
      final ishaIqamah = iqamahTimes['isha'] ?? _addMinutes(ishaAdhan, 28);

      // Push adhan times + maghrib iqamah to DB
      await _updateDbTimes(
        fajrAdhan, dhuhrAdhan, asrAdhan, maghribAdhan, ishaAdhan,
        fajrIqamah, dhuhrIqamah, asrIqamah, maghribIqamah, ishaIqamah,
      );

      return {
        'date': date,
        'prayers': [
          {'name': 'FAJR', 'adhan': _to12(fajrAdhan), 'iqamah': fajrIqamah},
          {'name': 'DHUHR', 'adhan': _to12(dhuhrAdhan), 'iqamah': dhuhrIqamah},
          {'name': 'ASR', 'adhan': _to12(asrAdhan), 'iqamah': asrIqamah},
          {'name': 'MAGHRIB', 'adhan': _to12(maghribAdhan), 'iqamah': maghribIqamah},
          {'name': 'ISHA', 'adhan': _to12(ishaAdhan), 'iqamah': ishaIqamah},
        ],
        'sunrise': _to12(sunrise),
        'sunset': _to12(maghribAdhan),
        'jummah1': '1:45 PM',
        'jummah2': '1:45 PM',
      };
    } catch (e) {
      print('Error fetching prayer times: $e');
      return null;
    }
  }

  Future<Map<String, String>> _fetchIqamahFromDb() async {
    try {
      final response = await _supabase
          .from('prayer_times')
          .select('prayer, iqamah');

      final Map<String, String> times = {};
      for (final row in response as List) {
        times[row['prayer'] as String] = _to12(row['iqamah'] as String);
      }
      return times;
    } catch (e) {
      print('Error fetching iqamah from DB: $e');
      return {};
    }
  }

  /// Fetches only iqamah times from DB (no API call). Returns a map of prayer name -> iqamah time in 12h format.
  Future<Map<String, String>> fetchIqamahOnly() async {
    return _fetchIqamahFromDb();
  }

  Future<void> _updateDbTimes(
    String fajrA, String zuhrA, String asrA, String maghribA, String ishaA,
    String fajrI, String zuhrI, String asrI, String maghribI, String ishaI,
  ) async {
    try {
      final rows = [
        {'prayer': 'fajr', 'adhan': fajrA, 'iqamah': _to24(fajrI)},
        {'prayer': 'zuhr', 'adhan': zuhrA, 'iqamah': _to24(zuhrI)},
        {'prayer': 'asr', 'adhan': asrA, 'iqamah': _to24(asrI)},
        {'prayer': 'maghrib', 'adhan': maghribA, 'iqamah': _to24(maghribI)},
        {'prayer': 'isha', 'adhan': ishaA, 'iqamah': _to24(ishaI)},
      ];
      await _supabase.from('prayer_times').upsert(rows);
    } catch (e) {
      print('Error updating prayer times in DB: $e');
    }
  }

  String _cleanTime(String time) => time.split(' ')[0];

  String _addMinutes(String time24, int minutes) {
    final parts = time24.split(':');
    final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    final newDt = dt.add(Duration(minutes: minutes));
    final h = newDt.hour > 12 ? newDt.hour - 12 : (newDt.hour == 0 ? 12 : newDt.hour);
    final m = newDt.minute.toString().padLeft(2, '0');
    final p = newDt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
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

  String _to24(String time) {
    if (!time.contains('AM') && !time.contains('PM')) return time;
    final parts = time.replaceAll(RegExp(r'[APM ]'), '').split(':');
    var hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    if (time.contains('PM') && hour != 12) hour += 12;
    if (time.contains('AM') && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
