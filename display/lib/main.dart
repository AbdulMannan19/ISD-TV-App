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
import 'services/shared_data.dart';
import 'services/display_mode_service.dart';
import 'services/alert_service.dart';
import 'services/iqamah_schedule_service.dart';
import 'test/test_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Single API call on startup — populates SharedData with everything
  await SharedData.instance.init();

  // Pre-fetch daily content (uses hijri month/day from SharedData)
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

  await IqamahScheduleService.applyScheduledChanges();
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
  List<int> _screenDurations = [];
  bool _screensBuilt = false;

  final _displayMode = DisplayModeService();
  List<String> _alerts = [];
  StreamSubscription? _alertSubscription;

  Timer? _rotationTimer;
  Timer? _midnightTimer;
  Timer? _maghribRefreshTimer;
  Timer? _prayerTimesDebounce;
  StreamSubscription? _slidesSubscription;
  StreamSubscription? _prayerTimesSubscription;

  @override
  void initState() {
    super.initState();
    _buildScreens();
    _listenToSlideChanges();
    _listenToPrayerTimesChanges();

    AlertService.instance.init();
    _alerts = AlertService.instance.currentAlerts;
    _alertSubscription = AlertService.instance.alertStream.listen((alerts) {
      if (mounted) setState(() => _alerts = alerts);
    });

    _displayMode.setOnModeChanged(() {
      if (mounted) setState(() {});
    });

    // SharedData already populated from main() — just schedule timers
    _displayMode.scheduleProhibited();
    _displayMode.scheduleIqamahLock();

    _scheduleNextRotation();
    _scheduleMidnightRefresh();
    _scheduleMaghribRefresh();
  }

  // --- Midnight: refresh iqamah schedule + daily content cache ---
  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      _refreshAtMidnight();
      _midnightTimer = Timer.periodic(const Duration(hours: 24), (_) => _refreshAtMidnight());
    });
  }

  Future<void> _refreshAtMidnight() async {
    await IqamahScheduleService.applyScheduledChanges();
    // Full API refresh — new Gregorian day means new prayer times
    await SharedData.instance.init();
    _displayMode.scheduleProhibited();
    _displayMode.scheduleIqamahLock();
    // Refresh hijri content
    await _fetchDailyContent();
    if (mounted) setState(() {});
  }

  // --- Maghrib+1min: refresh hijri content (Islamic day changes at sunset) ---
  void _scheduleMaghribRefresh() {
    final maghribDt = _parseTimeToday(SharedData.instance.sunset);
    if (maghribDt == null) return;

    final now = DateTime.now();
    final refreshTime = maghribDt.add(const Duration(minutes: 1));

    if (refreshTime.isBefore(now)) return; // Already past maghrib today

    _maghribRefreshTimer = Timer(refreshTime.difference(now), () async {
      // Re-fetch API to get tomorrow's hijri date
      await SharedData.instance.init();
      await _fetchDailyContent();
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchDailyContent() async {
    await Future.wait([
      DailyContentService(tableName: 'hadiths', fallback: {'text': '', 'source': ''}).getTodaysContent(),
      DailyContentService(tableName: 'duas', fallback: {'text': '', 'source': ''}).getTodaysContent(),
      DailyContentService(tableName: 'verses', fallback: {'text': '', 'source': ''}).getTodaysContent(),
    ]);
  }

  // --- Realtime: iqamah changes from admin (DB only, no API) ---
  void _listenToPrayerTimesChanges() {
    _prayerTimesSubscription = Supabase.instance.client
        .from('prayer_times')
        .stream(primaryKey: ['id'])
        .listen((_) {
      if (!mounted) return;
      _prayerTimesDebounce?.cancel();
      _prayerTimesDebounce = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        // DB only — no API call. Reevaluates all modes/timers.
        _displayMode.refreshIqamahFromDb().then((_) {
          if (mounted) setState(() {});
        });
      });
    });
  }

  void _scheduleNextRotation() {
    _rotationTimer?.cancel();
    if (!_screensBuilt || _screens.isEmpty) return;
    final duration = _screenDurations.isNotEmpty && _currentIndex < _screenDurations.length
        ? _screenDurations[_currentIndex]
        : 30;
    _rotationTimer = Timer(Duration(seconds: duration), () {
      if (mounted && _screensBuilt && _displayMode.mode == DisplayMode.normal) {
        setState(() => _currentIndex = (_currentIndex + 1) % _screens.length);
      }
      _scheduleNextRotation();
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
    final durations = <int>[
      30, 30, 30, 30,
      ...slides.map((s) => (s['duration_seconds'] as int?) ?? 30),
    ];
    if (mounted) {
      setState(() {
        if (_currentIndex >= screens.length && screens.isNotEmpty) _currentIndex = 0;
        _screens = screens;
        _screenDurations = durations;
        _screensBuilt = true;
      });
      _scheduleNextRotation();
    }
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

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _midnightTimer?.cancel();
    _maghribRefreshTimer?.cancel();
    _slidesSubscription?.cancel();
    _prayerTimesSubscription?.cancel();
    _prayerTimesDebounce?.cancel();
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
    final durationMs = (totalDistance / 50 * 1000).toInt();
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
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
