import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class PrayerTimesService {
  static const String _aladhanTimingsUrl = 'https://api.aladhan.com/v1/timings';
  static const String _defaultLatitude = '33.201662695006874';
  static const String _defaultLongitude = '-97.14494994434574';

  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> fetchPrayerTimes() async {
    try {
      final latitude = dotenv.env['ALADHAN_LATITUDE']?.trim().isNotEmpty == true
          ? dotenv.env['ALADHAN_LATITUDE']!.trim()
          : _defaultLatitude;
      final longitude = dotenv.env['ALADHAN_LONGITUDE']?.trim().isNotEmpty == true
          ? dotenv.env['ALADHAN_LONGITUDE']!.trim()
          : _defaultLongitude;

      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final url = Uri.parse('$_aladhanTimingsUrl/$dateStr?latitude=$latitude&longitude=$longitude&method=2');
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      if (decoded['code'] != 200 || decoded['data'] == null) return null;

      final data = decoded['data'] as Map<String, dynamic>;
      final timings = data['timings'] as Map<String, dynamic>;
      final dateData = data['date'] as Map<String, dynamic>;
      final hijri = dateData['hijri'] as Map<String, dynamic>;
      final gregorian = dateData['gregorian'] as Map<String, dynamic>;

      String _cleanTime(String t) {
        if (t.isEmpty) return t;
        return t.split(' ').first;
      }

      final fajrAdhan = _cleanTime(timings['Fajr'] as String? ?? '');
      final dhuhrAdhan = _cleanTime(timings['Dhuhr'] as String? ?? '');
      final asrAdhan = _cleanTime(timings['Asr'] as String? ?? '');
      final maghribAdhan = _cleanTime(timings['Maghrib'] as String? ?? '');
      final ishaAdhan = _cleanTime(timings['Isha'] as String? ?? '');
      final sunrise = _cleanTime(timings['Sunrise'] as String? ?? '');

      if (fajrAdhan.isEmpty ||
          dhuhrAdhan.isEmpty ||
          asrAdhan.isEmpty ||
          maghribAdhan.isEmpty ||
          ishaAdhan.isEmpty ||
          sunrise.isEmpty) {
        return null;
      }

      final hijriMonthName = hijri['month']['en'] as String? ?? '';
      final hijriDayNum = int.tryParse(hijri['day'].toString()) ?? 1;
      final hijriMonthNum = int.tryParse(hijri['month']['number'].toString()) ?? 1;
      final hijriYear = hijri['year'] as String? ?? '';
      final hijriDate = '$hijriMonthName $hijriDayNum, $hijriYear';

      final iqamahTimes = await _fetchIqamahFromDb();
      final fajrIqamah = iqamahTimes['fajr'] ?? _addMinutes(fajrAdhan, 25);
      final dhuhrIqamah = iqamahTimes['zuhr'] ?? _addMinutes(dhuhrAdhan, 19);
      final asrIqamah = iqamahTimes['asr'] ?? _addMinutes(asrAdhan, 19);
      final ishaIqamah = iqamahTimes['isha'] ?? _addMinutes(ishaAdhan, 28);
      final maghribIqamah = iqamahTimes['maghrib'] ?? _addMinutes(maghribAdhan, 10);
      final jummah1 = iqamahTimes['jummah'] ?? '1:45 PM';

      await _updateDbTimes(
        fajrAdhan,
        dhuhrAdhan,
        asrAdhan,
        maghribAdhan,
        ishaAdhan,
        fajrIqamah,
        dhuhrIqamah,
        asrIqamah,
        maghribIqamah,
        ishaIqamah,
      );

      return {
        'date': gregorian['date'] as String? ?? '',
        'prayers': [
          {'name': 'FAJR', 'adhan': _to12(fajrAdhan), 'iqamah': fajrIqamah},
          {'name': 'DHUHR', 'adhan': _to12(dhuhrAdhan), 'iqamah': dhuhrIqamah},
          {'name': 'ASR', 'adhan': _to12(asrAdhan), 'iqamah': asrIqamah},
          {'name': 'MAGHRIB', 'adhan': _to12(maghribAdhan), 'iqamah': maghribIqamah},
          {'name': 'ISHA', 'adhan': _to12(ishaAdhan), 'iqamah': ishaIqamah},
        ],
        'sunrise': _to12(sunrise),
        'sunset': _to12(maghribAdhan),
        'jummah': jummah1,
        'hijriDate': hijriDate,
        'hijriMonth': hijriMonthNum,
        'hijriDay': hijriDayNum,
      };
    } catch (_) {
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
    } catch (_) {
      return {};
    }
  }

  Future<void> _updateDbTimes(
    String fajrA,
    String zuhrA,
    String asrA,
    String maghribA,
    String ishaA,
    String fajrI,
    String zuhrI,
    String asrI,
    String maghribI,
    String ishaI,
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
    } catch (_) {}
  }

  String _addMinutes(String time24, int minutes) {
    if (time24.isEmpty) return time24;
    var parts = time24.split(':');
    if (parts.length < 2) return time24;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    
    final dt = DateTime(2000, 1, 1, h, m);
    final newDt = dt.add(Duration(minutes: minutes));
    final newH = newDt.hour > 12 ? newDt.hour - 12 : (newDt.hour == 0 ? 12 : newDt.hour);
    final newM = newDt.minute.toString().padLeft(2, '0');
    final p = newDt.hour >= 12 ? 'PM' : 'AM';
    return '$newH:$newM $p';
  }

  String _to12(String time) {
    if (time.isEmpty || time.contains('AM') || time.contains('PM')) return time;
    if (!time.contains(':')) return time;
    final parts = time.split(':');
    final hourStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    final minStr = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
    if (hourStr.isEmpty || minStr.isEmpty) return time;
    final hour = int.parse(hourStr);
    final minute = int.parse(minStr);
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final p = hour >= 12 ? 'PM' : 'AM';
    return '$h:${minute.toString().padLeft(2, '0')} $p';
  }

  String _to24(String time) {
    if (time.isEmpty || (!time.contains('AM') && !time.contains('PM'))) return time;
    final parts = time.replaceAll(RegExp(r'[APM ]'), '').split(':');
    if (parts.length < 2) return time;
    var hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    if (time.contains('PM') && hour != 12) hour += 12;
    if (time.contains('AM') && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
