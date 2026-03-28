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
import 'screens/split_slide_screen.dart';
import 'screens/silence_screen.dart';
import 'screens/prohibited_time_screen.dart';
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

  await SharedData.instance.init();
  await SharedData.instance.fetchDailyContent();

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
  RealtimeChannel? _prayerTimesChannel;
  RealtimeChannel? _slidesChannel;

  List<Object?> _lastSlideRowIds = [];
  int _slideBuildSeq = 0;

  static const int _kFixedScreens = 4;

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

    _displayMode.scheduleProhibited();
    _displayMode.scheduleIqamahLock();

    _scheduleNextRotation();
    _scheduleMidnightRefresh();
    _scheduleMaghribRefresh();
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    // 12:01 AM — 1 min buffer to ensure Gregorian date has changed
    final next = DateTime(now.year, now.month, now.day + 1, 0, 1);
    _midnightTimer = Timer(next.difference(now), () {
      _refreshAtMidnight();
      _midnightTimer = Timer.periodic(const Duration(hours: 24), (_) => _refreshAtMidnight());
    });
  }

  Future<void> _refreshAtMidnight() async {
    await IqamahScheduleService.applyScheduledChanges();
    await SharedData.instance.init();
    _displayMode.scheduleProhibited();
    _displayMode.scheduleIqamahLock();
    _maghribRefreshTimer?.cancel();
    _scheduleMaghribRefresh();
    if (mounted) setState(() {});
  }

  void _scheduleMaghribRefresh() {
    final maghribDt = _parseTimeToday(SharedData.instance.sunset);
    if (maghribDt == null) return;

    final now = DateTime.now();
    final refreshTime = maghribDt.add(const Duration(minutes: 1));

    if (refreshTime.isBefore(now)) return;

    _maghribRefreshTimer = Timer(refreshTime.difference(now), () async {
      // Hijri date changes at sunset — fetch new daily content
      await SharedData.instance.init();
      await SharedData.instance.fetchDailyContent();
      if (mounted) setState(() {});
    });
  }

  void _listenToPrayerTimesChanges() {
    _prayerTimesChannel = Supabase.instance.client
        .channel('prayer_times_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'prayer_times',
          callback: (payload) {
            if (!mounted) return;
            _prayerTimesDebounce?.cancel();
            _prayerTimesDebounce = Timer(const Duration(seconds: 1), () {
              if (!mounted) return;
              _displayMode.refreshIqamahFromDb().then((_) {
                if (mounted) setState(() {});
              });
            });
          },
        )
        .subscribe();
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
    _slidesChannel = Supabase.instance.client
        .channel('slides_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'slides',
          callback: (payload) {
            if (mounted) _buildScreens();
          },
        )
        .subscribe();
  }

  int _remapIndexAfterSlideListChange(
    int oldIndex,
    List<Object?> oldSlideIds,
    List<Object?> newSlideIds,
  ) {
    final newLen = _kFixedScreens + newSlideIds.length;
    if (newLen <= 0) return 0;

    if (oldIndex < _kFixedScreens) {
      return oldIndex.clamp(0, newLen - 1);
    }

    final oldSi = oldIndex - _kFixedScreens;
    if (oldSlideIds.isEmpty || oldSi < 0 || oldSi >= oldSlideIds.length) {
      return oldIndex.clamp(0, newLen - 1);
    }

    final currentId = oldSlideIds[oldSi];
    final newPos = newSlideIds.indexOf(currentId);
    if (newPos >= 0) {
      return _kFixedScreens + newPos;
    }

    for (var i = oldSi + 1; i < oldSlideIds.length; i++) {
      final np = newSlideIds.indexOf(oldSlideIds[i]);
      if (np >= 0) return _kFixedScreens + np;
    }
    return 0;
  }

  Future<void> _buildScreens() async {
    final seq = ++_slideBuildSeq;
    final oldSlideIds = List<Object?>.from(_lastSlideRowIds);

    final slides = await SlidesService().getActiveSlides();
    if (!mounted || seq != _slideBuildSeq) return;

    final newSlideIds = slides.map<Object?>((s) => s['id']).toList();
    final remappedIndex = _remapIndexAfterSlideListChange(_currentIndex, oldSlideIds, newSlideIds);

    final screens = <Widget>[
      const PrayerTimesScreen(),
      const HadithScreen(),
      const DuaScreen(),
      const VerseScreen(),
      ...slides.map((s) {
        final mode = (s['display_mode'] as String?) ?? 'full';
        return mode == 'split'
            ? SplitSlideScreen(key: ValueKey('${s['id']}_split'), slide: s)
            : SlidesScreen(key: ValueKey('${s['id']}_full'), slide: s);
      }),
    ];
    final durations = <int>[
      30, 30, 30, 30,
      ...slides.map((s) => (s['duration_seconds'] as int?) ?? 30),
    ];
    if (mounted && seq == _slideBuildSeq) {
      setState(() {
        _currentIndex = remappedIndex.clamp(0, screens.isEmpty ? 0 : screens.length - 1);
        _screens = screens;
        _screenDurations = durations;
        _screensBuilt = true;
        _lastSlideRowIds = newSlideIds;
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
    if (_slidesChannel != null) {
      Supabase.instance.client.removeChannel(_slidesChannel!);
    }
    if (_prayerTimesChannel != null) {
      Supabase.instance.client.removeChannel(_prayerTimesChannel!);
    }
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
