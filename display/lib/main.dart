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
import 'services/daily_content_service.dart';
import 'services/slides_service.dart';
import 'services/update_service.dart';
import 'services/shared_data.dart';
import 'services/display_mode_service.dart';
import 'test/test_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Pre-fetch daily content
  await Future.wait([
    DailyContentService(tableName: 'hadiths', fallback: {'text': '', 'source': ''}).getTodaysContent(),
    DailyContentService(tableName: 'duas', fallback: {'text': '', 'source': ''}).getTodaysContent(),
    DailyContentService(tableName: 'verses', fallback: {'text': '', 'source': ''}).getTodaysContent(),
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  UpdateService.checkForUpdate();
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
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
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
  List<Widget> _screens = [];
  bool _screensBuilt = false;

  final _displayMode = DisplayModeService();

  Timer? _rotationTimer;
  Timer? _silenceCheckTimer;
  Timer? _prohibitedCheckTimer;
  Timer? _midnightTimer;
  Timer? _prayerRefreshTimer;
  StreamSubscription? _slidesSubscription;

  @override
  void initState() {
    super.initState();
    _buildScreens();
    _listenToSlideChanges();
    _displayMode.fetchPrayerData();
    _displayMode.fetchIqamahTimes();

    _rotationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _screensBuilt && _displayMode.mode == DisplayMode.normal) {
        setState(() => _currentIndex = (_currentIndex + 1) % _screens.length);
      }
    });

    _silenceCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_displayMode.checkSilence()) setState(() {});
    });

    _prohibitedCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_displayMode.checkProhibited()) setState(() {});
    });

    _scheduleMidnightRefresh();
    _schedulePrayerRefresh();
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      _refreshDailyContent();
      _midnightTimer = Timer.periodic(const Duration(hours: 24), (_) => _refreshDailyContent());
    });
  }

  Future<void> _refreshDailyContent() async {
    await Future.wait([
      DailyContentService(tableName: 'hadiths', fallback: {'text': '', 'source': ''}).getTodaysContent(),
      DailyContentService(tableName: 'duas', fallback: {'text': '', 'source': ''}).getTodaysContent(),
      DailyContentService(tableName: 'verses', fallback: {'text': '', 'source': ''}).getTodaysContent(),
    ]);
  }

  void _schedulePrayerRefresh() {
    final now = DateTime.now();
    final nextNoon = DateTime(now.year, now.month, now.day, 12);
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final next = now.isBefore(nextNoon) ? nextNoon : nextMidnight;
    _prayerRefreshTimer = Timer(next.difference(now), () {
      _displayMode.fetchPrayerData();
      _displayMode.fetchIqamahTimes();
      _prayerRefreshTimer = Timer.periodic(const Duration(hours: 12), (_) {
        _displayMode.fetchPrayerData();
        _displayMode.fetchIqamahTimes();
      });
    });
  }

  void _listenToSlideChanges() {
    _slidesSubscription = Supabase.instance.client
        .from('slides')
        .stream(primaryKey: ['id'])
        .listen((_) { if (mounted) _buildScreens(); });
  }

  Future<void> _buildScreens() async {
    final slides = await SlidesService().getActiveSlides();
    final screens = <Widget>[
      const PrayerTimesScreen(),
      const HadithScreen(),
      const DuaScreen(),
      const VerseScreen(),
      ...slides.map((s) => SlidesScreen(slide: s)),
    ];
    if (mounted) {
      setState(() {
        if (_currentIndex >= screens.length && screens.isNotEmpty) _currentIndex = 0;
        _screens = screens;
        _screensBuilt = true;
      });
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _silenceCheckTimer?.cancel();
    _prohibitedCheckTimer?.cancel();
    _midnightTimer?.cancel();
    _prayerRefreshTimer?.cancel();
    _slidesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_screensBuilt) {
      return const Scaffold(
        backgroundColor: Color(0xFF000428),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Stack(
      children: [
        switch (_displayMode.mode) {
          DisplayMode.silence => const SilenceScreen(),
          DisplayMode.prohibited => ProhibitedTimeScreen(endTime: _displayMode.prohibitedEndTime!),
          DisplayMode.normal => IndexedStack(index: _currentIndex, children: _screens),
        },
        TestControls(
          onPrevious: () {
            if (_screensBuilt && _displayMode.mode == DisplayMode.normal) {
              setState(() => _currentIndex = (_currentIndex - 1 + _screens.length) % _screens.length);
            }
          },
          onNext: () {
            if (_screensBuilt && _displayMode.mode == DisplayMode.normal) {
              setState(() => _currentIndex = (_currentIndex + 1) % _screens.length);
            }
          },
          onTestSilence: () => setState(() => _displayMode.setTestSilence()),
          onTestProhibited: () => setState(() => _displayMode.setTestProhibited()),
          onExit: () => setState(() => _displayMode.exitSpecialMode()),
        ),
      ],
    );
  }
}
