import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'screens/prayer_times_screen.dart';
import 'screens/hadith_screen.dart';
import 'screens/dua_screen.dart';
import 'screens/verse_screen.dart';
import 'screens/slides_screen.dart';
import 'screens/silence_screen.dart';
import 'screens/prohibited_time_screen.dart';
import 'services/hadith_service.dart';
import 'services/dua_service.dart';
import 'services/verse_service.dart';
import 'services/slides_service.dart';
import 'services/prayer_times_service.dart';
import 'services/update_service.dart';
import 'services/shared_data.dart';
import 'test/test_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  final hadithService = HadithService();
  final duaService = DuaService();
  final verseService = VerseService();
  
  await Future.wait([
    hadithService.getTodaysHadith(),
    duaService.getTodaysDua(),
    verseService.getTodaysVerse(),
  ]);
  
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Check for app updates (Android only, non-blocking)
  UpdateService.checkForUpdate();
  
  // Load shared data (sunrise, sunset, iqamah countdown)
  await SharedData.instance.init();
  
  runApp(const DisplayApp());
}

class DisplayApp extends StatelessWidget {
  const DisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISD Display',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const ScreenRotator(),
    );
  }
}

class ScreenRotator extends StatefulWidget {
  const ScreenRotator({super.key});

  @override
  State<ScreenRotator> createState() => _ScreenRotatorState();
}

class _ScreenRotatorState extends State<ScreenRotator> {
  int _currentIndex = 0;
  Timer? _midnightCheckTimer;
  Timer? _prayerRefreshTimer;
  Timer? _iqamahCheckTimer;
  Timer? _prohibitedCheckTimer;
  Timer? _rotationTimer;
  List<Widget> _screens = [];
  bool _screensBuilt = false;
  StreamSubscription? _slidesSubscription;
  bool _inSilenceMode = false;
  DateTime? _silenceEndTime;
  bool _inProhibitedMode = false;
  DateTime? _prohibitedEndTime;
  List<String> _iqamahTimes = [];
  String _sunriseTime = '';
  String _sunsetTime = '';
  List<Map<String, String>> _prayersList = [];
  
  @override
  void initState() {
    super.initState();
    _buildScreens();
    _listenToSlideChanges();
    _fetchIqamahTimes();
    _fetchPrayerData();
    _startRotation();
    _startIqamahCheck();
    _startProhibitedCheck();
    
    _scheduleMidnightRefresh();

    _schedulePrayerRefresh();
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _midnightCheckTimer = Timer(nextMidnight.difference(now), () {
      _refreshDailyContent();
      _midnightCheckTimer = Timer.periodic(const Duration(hours: 24), (_) {
        _refreshDailyContent();
      });
    });
  }

  Future<void> _refreshDailyContent() async {
    await Future.wait([
      HadithService().getTodaysHadith(),
      DuaService().getTodaysDua(),
      VerseService().getTodaysVerse(),
    ]);
  }

  void _schedulePrayerRefresh() {
    final now = DateTime.now();
    final nextNoon = DateTime(now.year, now.month, now.day, 12);
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final next = now.isBefore(nextNoon) ? nextNoon : nextMidnight;
    _prayerRefreshTimer = Timer(next.difference(now), () {
      _fetchPrayerData();
      _fetchIqamahTimes();
      _prayerRefreshTimer = Timer.periodic(const Duration(hours: 12), (_) {
        _fetchPrayerData();
        _fetchIqamahTimes();
      });
    });
  }

  void _startRotation() {
    _rotationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _screensBuilt && !_inSilenceMode && !_inProhibitedMode) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _screens.length;
        });
      }
    });
  }

  void _startIqamahCheck() {
    _iqamahCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkIqamahTime();
    });
  }

  void _startProhibitedCheck() {
    _prohibitedCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkProhibitedTime();
    });
  }

  Future<void> _fetchPrayerData() async {
    try {
      final prayerService = PrayerTimesService();
      final data = await prayerService.fetchPrayerTimes();
      
      if (data == null) return;
      
      final prayers = (data['prayers'] as List).map((p) => {
        'name': p['name'] as String,
        'start': p['adhan'] as String,
        'iqamah': p['iqamah'] as String,
      }).toList();
      
      setState(() {
        _prayersList = prayers;
        _sunriseTime = data['sunrise'] as String;
        _sunsetTime = data['sunset'] as String;
      });
    } catch (e) {
      print('Error fetching prayer data: $e');
    }
  }

  void _checkProhibitedTime() {
    if (_inProhibitedMode) {
      if (DateTime.now().isAfter(_prohibitedEndTime!)) {
        setState(() {
          _inProhibitedMode = false;
          _prohibitedEndTime = null;
        });
      }
      return;
    }

    final now = DateTime.now();
    
    // Parse sunrise and sunset times
    final sunriseDateTime = _parseTimeToday(_sunriseTime);
    final sunsetDateTime = _parseTimeToday(_sunsetTime);
    
    if (sunriseDateTime == null || sunsetDateTime == null) return;
    
    // Check if within 15 min after sunrise
    final sunriseEnd = sunriseDateTime.add(const Duration(minutes: 15));
    if (now.isAfter(sunriseDateTime) && now.isBefore(sunriseEnd)) {
      setState(() {
        _inProhibitedMode = true;
        _prohibitedEndTime = sunriseEnd;
      });
      return;
    }
    
    // Check if within 15 min before sunset
    final sunsetStart = sunsetDateTime.subtract(const Duration(minutes: 15));
    if (now.isAfter(sunsetStart) && now.isBefore(sunsetDateTime)) {
      setState(() {
        _inProhibitedMode = true;
        _prohibitedEndTime = sunsetDateTime;
      });
    }
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
    } catch (e) {
      return null;
    }
  }

  Future<void> _fetchIqamahTimes() async {
    try {
      final response = await Supabase.instance.client
          .from('prayer_times')
          .select('prayer, iqamah');
      
      final times = <String>[];
      for (final row in response as List) {
        final prayer = row['prayer'] as String;
        if (prayer.startsWith('jummah')) continue;
        times.add(row['iqamah'] as String);
      }
      setState(() => _iqamahTimes = times);
      await SharedData.instance.refreshIqamah();
    } catch (e) {
      print('Error fetching iqamah times: $e');
    }
  }

  void _checkIqamahTime() {
    if (_inSilenceMode) {
      if (DateTime.now().isAfter(_silenceEndTime!)) {
        setState(() {
          _inSilenceMode = false;
          _silenceEndTime = null;
        });
      }
      return;
    }

    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    for (final iqamah in _iqamahTimes) {
      if (iqamah == currentTime) {
        setState(() {
          _inSilenceMode = true;
          _silenceEndTime = now.add(const Duration(minutes: 15));
        });
        break;
      }
    }
  }

  void _listenToSlideChanges() {
    _slidesSubscription = Supabase.instance.client
        .from('slides')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (mounted) {
            _buildScreens();
          }
        });
  }

  Future<void> _buildScreens() async {
    final slidesService = SlidesService();
    final slides = await slidesService.getActiveSlides();
    
    final screens = <Widget>[
      const PrayerTimesScreen(),
      const HadithScreen(),
      const DuaScreen(),
      const VerseScreen(),
    ];
    
    for (var slide in slides) {
      screens.add(SlidesScreen(slide: slide));
    }
    
    if (mounted) {
      setState(() {
        if (_currentIndex >= screens.length && screens.isNotEmpty) {
          _currentIndex = 0;
        }
        _screens = screens;
        _screensBuilt = true;
      });
    }
  }

  @override
  void dispose() {
    _midnightCheckTimer?.cancel();
    _prayerRefreshTimer?.cancel();
    _iqamahCheckTimer?.cancel();
    _prohibitedCheckTimer?.cancel();
    _rotationTimer?.cancel();
    _slidesSubscription?.cancel();
    super.dispose();
  }

  void _goToPrevious() {
    if (_screensBuilt && !_inSilenceMode && !_inProhibitedMode) {
      setState(() {
        _currentIndex = (_currentIndex - 1 + _screens.length) % _screens.length;
      });
    }
  }

  void _goToNext() {
    if (_screensBuilt && !_inSilenceMode && !_inProhibitedMode) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _screens.length;
      });
    }
  }

  void _testSilence() {
    setState(() {
      _inSilenceMode = !_inSilenceMode;
      _inProhibitedMode = false;
      if (_inSilenceMode) {
        _silenceEndTime = DateTime.now().add(const Duration(hours: 1));
      }
    });
  }

  void _testProhibited() {
    setState(() {
      _inProhibitedMode = !_inProhibitedMode;
      _inSilenceMode = false;
      if (_inProhibitedMode) {
        _prohibitedEndTime = DateTime.now().add(const Duration(minutes: 15));
      }
    });
  }

  void _exitSpecialScreen() {
    setState(() {
      _inSilenceMode = false;
      _inProhibitedMode = false;
      _silenceEndTime = null;
      _prohibitedEndTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_screensBuilt) {
      return const Scaffold(
        backgroundColor: Color(0xFF000428),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        _inSilenceMode
            ? const SilenceScreen()
            : _inProhibitedMode
                ? ProhibitedTimeScreen(
                    endTime: _prohibitedEndTime!,
                    prayers: _prayersList,
                    sunrise: _sunriseTime,
                    sunset: _sunsetTime,
                  )
                : IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
        
        TestControls(
          onPrevious: _goToPrevious,
          onNext: _goToNext,
          onTestSilence: _testSilence,
          onTestProhibited: _testProhibited,
          onExit: _exitSpecialScreen,
        ),
      ],
    );
  }
}
