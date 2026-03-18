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
import 'services/alert_service.dart';
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
  List<String> _alerts = [];
  StreamSubscription? _alertSubscription;

  Timer? _rotationTimer;
  Timer? _midnightTimer;
  Timer? _prayerRefreshTimer;
  StreamSubscription? _slidesSubscription;

  @override
  void initState() {
    super.initState();
    _buildScreens();
    _listenToSlideChanges();

    // Init alerts
    AlertService.instance.init();
    _alerts = AlertService.instance.currentAlerts;
    _alertSubscription = AlertService.instance.alertStream.listen((alerts) {
      if (mounted) setState(() => _alerts = alerts);
    });

    _displayMode.setOnModeChanged(() {
      if (mounted) setState(() {});
    });

    // Fetch data then schedule smart timers
    _displayMode.fetchPrayerData().then((_) {
      _displayMode.fetchIqamahTimes().then((_) {
        _displayMode.scheduleProhibited();
        _displayMode.scheduleIqamahLock();
      });
    });

    _rotationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _screensBuilt &&
          _displayMode.mode == DisplayMode.normal) {
        setState(() => _currentIndex = (_currentIndex + 1) % _screens.length);
      }
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
      _displayMode.fetchPrayerData().then((_) {
        _displayMode.fetchIqamahTimes().then((_) {
          _displayMode.scheduleProhibited();
          _displayMode.scheduleIqamahLock();
        });
      });
      _prayerRefreshTimer = Timer.periodic(const Duration(hours: 12), (_) {
        _displayMode.fetchPrayerData().then((_) {
          _displayMode.fetchIqamahTimes().then((_) {
            _displayMode.scheduleProhibited();
            _displayMode.scheduleIqamahLock();
          });
        });
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
    _midnightTimer?.cancel();
    _prayerRefreshTimer?.cancel();
    _slidesSubscription?.cancel();
    _alertSubscription?.cancel();
    AlertService.instance.dispose();
    _displayMode.dispose();
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

    // Show alert marquee on all screens except silence and slides
    final showAlerts = _alerts.isNotEmpty &&
        _displayMode.mode != DisplayMode.silence &&
        !(_displayMode.mode == DisplayMode.normal && _currentIndex >= 4);

    return Stack(
      children: [
        switch (_displayMode.mode) {
          DisplayMode.silence => const SilenceScreen(),
          DisplayMode.prohibited => ProhibitedTimeScreen(endTime: _displayMode.prohibitedEndTime!),
          DisplayMode.iqamahLock => IndexedStack(index: 0, children: _screens),
          DisplayMode.normal => IndexedStack(index: _currentIndex, children: _screens),
        },
        if (showAlerts) _buildAlertMarquee(),
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

  Widget _buildAlertMarquee() {
    final text = _alerts.join('     •     ');
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: _AlertMarquee(key: ValueKey(text), text: text),
      ),
    );
  }
}

class _AlertMarquee extends StatefulWidget {
  final String text;
  const _AlertMarquee({super.key, required this.text});

  @override
  State<_AlertMarquee> createState() => _AlertMarqueeState();
}

class _AlertMarqueeState extends State<_AlertMarquee>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _childWidth = 0;
  double _screenWidth = 0;
  final _childKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    _screenWidth = MediaQuery.of(context).size.width;
    final renderBox = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _childWidth = renderBox.size.width;
    }
    final totalDistance = _screenWidth + _childWidth;
    final durationMs = (totalDistance / 100 * 1000).toInt();
    _controller.duration = Duration(milliseconds: durationMs);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final totalDistance = _screenWidth + _childWidth;
        final dx = _screenWidth - _controller.value * totalDistance;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: UnconstrainedBox(
        alignment: Alignment.centerLeft,
        child: Container(
          key: _childKey,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade800,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.text,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
