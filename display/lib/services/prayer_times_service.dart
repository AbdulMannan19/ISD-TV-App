import 'dart:convert';
import 'package:http/http.dart' as http;

class PrayerTimesService {
  static const String _aladhanApiBase = 'http://api.aladhan.com/v1';
  static const String _city = 'Denton';
  static const String _state = 'TX';
  static const String _country = 'USA';
  static const int _method = 2; 

  Future<Map<String, dynamic>?> fetchPrayerTimes() async {
    try {
      final now = DateTime.now();
      final url = Uri.parse(
        '$_aladhanApiBase/timingsByCity/${now.day}-${now.month}-${now.year}?city=$_city&state=$_state&country=$_country&method=$_method',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          return _processPrayerTimes(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching prayer times: $e');
      return null;
    }
  }

  Map<String, dynamic> _processPrayerTimes(Map<String, dynamic> data) {
    final timings = data['timings'] as Map<String, dynamic>;
    final date = data['date']['readable'] as String;

    final fajrAdhan = _cleanTime(timings['Fajr']);
    final dhuhrAdhan = _cleanTime(timings['Dhuhr']);
    final asrAdhan = _cleanTime(timings['Asr']);
    final maghribAdhan = _cleanTime(timings['Maghrib']);
    final ishaAdhan = _cleanTime(timings['Isha']);
    final sunrise = _cleanTime(timings['Sunrise']);

    final maghribIqamah = _addMinutes(maghribAdhan, 10);

    final fajrIqamah = _addMinutes(fajrAdhan, 25); // Placeholder: +25 min
    final dhuhrIqamah = _addMinutes(dhuhrAdhan, 19); // Placeholder: +19 min
    final asrIqamah = _addMinutes(asrAdhan, 19); // Placeholder: +19 min
    final ishaIqamah = _addMinutes(ishaAdhan, 28); // Placeholder: +28 min

    return {
      'date': date,
      'prayers': [
        {'name': 'FAJR', 'adhan': fajrAdhan, 'iqamah': fajrIqamah},
        {'name': 'DHUHR', 'adhan': dhuhrAdhan, 'iqamah': dhuhrIqamah},
        {'name': 'ASR', 'adhan': asrAdhan, 'iqamah': asrIqamah},
        {'name': 'MAGHRIB', 'adhan': maghribAdhan, 'iqamah': maghribIqamah},
        {'name': 'ISHA', 'adhan': ishaAdhan, 'iqamah': ishaIqamah},
      ],
      'sunrise': sunrise,
      'sunset': maghribAdhan,
      'jummah1': '1:45 PM',
      'jummah2': '1:45 PM',
    };
  }

  String _cleanTime(String time) {
    return time.split(' ')[0];
  }

  String _addMinutes(String time, int minutes) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final dateTime = DateTime(2000, 1, 1, hour, minute);
    final newTime = dateTime.add(Duration(minutes: minutes));

    return _formatTime(newTime);
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
