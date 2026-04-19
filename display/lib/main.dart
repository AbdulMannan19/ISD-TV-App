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
import 'services/theme_service.dart';
import 'services/navigation_service.dart';
import 'test/test_controls.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Permanent self-healing logic to prevent startup crashes due to corrupted storage.
Future<void> _performStorageHealthCheck() async {
  try {
    final searchDirs = [
      await getApplicationSupportDirectory(), // Target: Roaming/com.isd/display
    ];

    for (var dir in searchDirs) {
      final directory = Directory(dir.path);
      if (!await directory.exists()) continue;

      await for (var entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            final len = await entity.length();
            if (len > 0 && len < 1024 * 512) { // Under 512KB
              final bytes = await entity.readAsBytes();
              if (bytes.every((b) => b == 0)) {
                debugPrint("--- STORAGE REPAIR ---");
                debugPrint("Self-healing: Found and deleted null-corrupted file: ${entity.path}");
                await entity.delete();
                debugPrint("----------------------");
              }
            }
          } catch (_) {
            // Silently ignore files that are locked by other processes
          }
        }
      }
    }
  } catch (e) {
    // Top-level catch just to be safe
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Run self-healing check before any other services startd
  await _performStorageHealthCheck();
  
  try {
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']?.trim() ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '',
    );
  } catch (e) {
    debugPrint("Supabase init error: $e");
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);


  runApp(const DisplayApp());
}

class DisplayApp extends StatelessWidget {
  const DisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, _) {
        return MaterialApp(
          title: 'ISD Display',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true, 
            fontFamily: 'Roboto',
          ),
          home: const StartupGate(),
        );
      },
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _initialized = false;
  String _status = "Initializing system...";
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    while (mounted && !_initialized) {
      try {
        setState(() => _status = _retryCount == 0 ? "Syncing Prayer Times..." : "Network sync retry #$_retryCount...");
        
        // 1. Theme Service should be localized/fast
        await ThemeService().init();
        
        // 2. Shared Data (Prayer times from API/DB)
        final prayerSuccess = await SharedData.instance.init();
        if (prayerSuccess) {
          // 3. Daily Content
          setState(() => _status = "Fetching Daily Content...");
          final contentSuccess = await SharedData.instance.fetchDailyContent();
          
          if (contentSuccess) {
            // 4. Apply scheduled changes
            try {
              await IqamahScheduleService.applyScheduledChanges();
            } catch (_) {}

            if (mounted) {
              setState(() {
                _initialized = true;
                _status = "Synchronized";
              });
            }
            return;
          }
        }
      } catch (e) {
        debugPrint("Startup attempt $_retryCount failed: $e");
      }

      _retryCount++;
      // Exponential backoff or steady retry every 3s
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) return const ScreenRotator();

    return Scaffold(
      backgroundColor: const Color(0xFF000428),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branded Mosque Logo
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withAlpha(20),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/app_icon.jpeg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => 
                          const SizedBox(width: 80, height: 80),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                if (_retryCount > 10) ...[
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _retryCount = 0;
                        _startInitialization();
                      });
                    },
                    child: const Text("Retry Now", style: TextStyle(color: Colors.white)),
                  ),
                ]
              ],
            ),
          ),
          if (!kIsWeb && Platform.isAndroid)
            Positioned(
              top: 24,
              right: 24,
              child: IconButton(
                onPressed: () => NavigationService.openSettings(),
                icon: const Icon(Icons.settings, color: Colors.white38, size: 28),
                tooltip: 'Android Settings',
              ),
            ),
        ],
      ),
    );
  }
}

class ScreenRotator extends StatefulWidget {
  const ScreenRotator({super.key});

  @override
  State<ScreenRotator> createState() => _ScreenRotatorState();
}

class _ScreenRotatorState extends State<ScreenRotator> with WidgetsBindingObserver {
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
  Timer? _slideTransitionTimer;
  Timer? _prayerTimesDebounce;
  RealtimeChannel? _prayerTimesChannel;
  RealtimeChannel? _slidesChannel;

  List<Object?> _lastSlideRowIds = [];
  int _slideBuildSeq = 0;

  int get _fixedScreenCount {
    final hasHadith2 = (SharedData.instance.currentHadith['text2'] ?? '').isNotEmpty;
    return hasHadith2 ? 5 : 4;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force an immediate refresh of all core data whenever the mobile app returns to the foreground
      // because WebSockets and timers often get killed by the OS in the background.
      debugPrint("App resumed from background — Forcing full data sync.");
      _forceRefreshAll();
    }
  }

  Future<void> _forceRefreshAll() async {
    // 1. Apply any scheduled iqamah changes (date-based, must run after midnight)
    try {
      await IqamahScheduleService.applyScheduledChanges();
    } catch (_) {}

    // 2. Refresh global prayer times and display modes
    await SharedData.instance.init();
    await SharedData.instance.fetchDailyContent();
    await _displayMode.refreshIqamahFromDb();
    _displayMode.scheduleProhibited();
    _displayMode.scheduleIqamahLock();
    
    // 2. Fetch latest theme safely without re-registering sockets
    try {
      final settings = await Supabase.instance.client.from('settings').select('theme_id').eq('id', 1).maybeSingle();
      if (settings != null && settings['theme_id'] != null) {
        // Since _applyTheme is private, we will just re-init ThemeService which drops and reconnects safely
        await ThemeService().init();
      }
    } catch (_) {}

    // 3. Rebuild rotation screens
    await _buildScreens();
    
    // 4. Reschedule background timers
    _midnightTimer?.cancel();
    _maghribRefreshTimer?.cancel();
    _scheduleMidnightRefresh();
    _scheduleMaghribRefresh();

    if (mounted) setState(() {});
  }

  void _scheduleMidnightRefresh() {
    final now = SharedData.instance.now;
    // 12:03 AM — 3 min buffer to ensure Gregorian date has changed
    final next = DateTime(now.year, now.month, now.day + 1, 0, 3);
    _midnightTimer = Timer(next.difference(now), () {
      _refreshAtMidnight();
      _midnightTimer = Timer.periodic(const Duration(hours: 24), (_) => _refreshAtMidnight());
    });
  }

  Future<void> _refreshAtMidnight() async {
    await _forceRefreshAll();
  }

  void _scheduleMaghribRefresh() {
    final maghribDt = _parseTimeToday(SharedData.instance.sunset);
    if (maghribDt == null) return;
    
    final now = SharedData.instance.now;
    final refreshTime = maghribDt.add(const Duration(minutes: 1));

    if (refreshTime.isBefore(now)) return;

    _maghribRefreshTimer = Timer(refreshTime.difference(now), () async {
      // Hijri date changes at sunset — bump locally (Aladhan only updates at midnight)
      SharedData.instance.bumpHijriDay();
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

  /// Schedules a one-shot timer for the exact moment the next slide should
  /// appear or disappear based on its time window — same pattern as the
  /// iqamah lock timer in [DisplayModeService].
  void _scheduleSlideTransition(List<Map<String, dynamic>> allRows) {
    _slideTransitionTimer?.cancel();
    final nextTime = SlidesService().getNextTransitionTime(allRows);
    if (nextTime == null) return;
    final delay = nextTime.difference(SharedData.instance.now);
    if (delay.isNegative) {
      // Boundary already passed (race condition) — rebuild immediately
      _buildScreens();
      return;
    }
    _slideTransitionTimer = Timer(delay, () {
      if (mounted) _buildScreens();
    });
  }

  int _remapIndexAfterSlideListChange(
    int oldIndex,
    List<Object?> oldSlideIds,
    List<Object?> newSlideIds,
  ) {
    final fc = _fixedScreenCount;
    final newLen = fc + newSlideIds.length;
    if (newLen <= 0) return 0;

    if (oldIndex < fc) {
      return oldIndex.clamp(0, newLen - 1);
    }

    final oldSi = oldIndex - fc;
    if (oldSlideIds.isEmpty || oldSi < 0 || oldSi >= oldSlideIds.length) {
      return oldIndex.clamp(0, newLen - 1);
    }

    final currentId = oldSlideIds[oldSi];
    final newPos = newSlideIds.indexOf(currentId);
    if (newPos >= 0) {
      return fc + newPos;
    }

    for (var i = oldSi + 1; i < oldSlideIds.length; i++) {
      final np = newSlideIds.indexOf(oldSlideIds[i]);
      if (np >= 0) return fc + np;
    }
    return 0;
  }

  Future<void> _buildScreens() async {
    final seq = ++_slideBuildSeq;
    final oldSlideIds = List<Object?>.from(_lastSlideRowIds);

    final slidesService = SlidesService();
    final allRows = await slidesService.fetchAllSlides();
    if (!mounted || seq != _slideBuildSeq) return;

    final slides = slidesService.filterActiveSlides(allRows);

    final newSlideIds = slides.map<Object?>((s) => s['id']).toList();
    final remappedIndex = _remapIndexAfterSlideListChange(_currentIndex, oldSlideIds, newSlideIds);

    final hasHadith2 = (SharedData.instance.currentHadith['text2'] ?? '').isNotEmpty;

    final screens = <Widget>[
      const PrayerTimesScreen(),
      const HadithScreen(),
      if (hasHadith2) const Hadith2Screen(),
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
      30, 30,
      if (hasHadith2) 30,
      30, 30,
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
      _scheduleSlideTransition(allRows);
    }
  }

  DateTime? _parseTimeToday(String time) {
    try {
      final trimmed = time.trim();
      final now = SharedData.instance.now;
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
    WidgetsBinding.instance.removeObserver(this);
    _rotationTimer?.cancel();
    _midnightTimer?.cancel();
    _maghribRefreshTimer?.cancel();
    _slideTransitionTimer?.cancel();
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
        !(_displayMode.mode == DisplayMode.normal && _currentIndex >= _fixedScreenCount);

    return Stack(
      children: [
        switch (_displayMode.mode) {
          DisplayMode.silence => const SilenceScreen(),
          DisplayMode.prohibited => ProhibitedTimeScreen(endTime: _displayMode.prohibitedEndTime!),
          DisplayMode.iqamahLock => IndexedStack(index: 0, children: _screens),
          DisplayMode.normal => IndexedStack(index: _currentIndex, children: _screens),
        },
        if (showAlerts) _buildAlertMarquee(),
        if (SharedData.instance.isSimulated) _buildSimulatedIndicator(),
        if (SharedData.configEnableSimulation)
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
            onTimeShift: (offset) {
              setState(() {
                SharedData.instance.setOverrideTime(SharedData.instance.now.add(offset));
                _displayMode.reevaluate();
                // Update scheduled refresh timers based on new simulated time
                _midnightTimer?.cancel();
                _maghribRefreshTimer?.cancel();
                _scheduleMidnightRefresh();
                _scheduleMaghribRefresh();
              });
            },
            onTimeReset: () {
              setState(() {
                SharedData.instance.setOverrideTime(null);
                _displayMode.reevaluate();
                _midnightTimer?.cancel();
                _maghribRefreshTimer?.cancel();
                _scheduleMidnightRefresh();
                _scheduleMaghribRefresh();
              });
            },
          ),
      ],
    );
  }

  Widget _buildSimulatedIndicator() {
    final now = SharedData.instance.now;
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} (Day ${now.day})";
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.shade900.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                "SIMULATED: $timeStr",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(width: 12),
              Text(
                "ESC to Reset",
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
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
    final durationMs = (totalDistance / 20 * 1000).toInt();
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
    final child = UnconstrainedBox(
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
            fontSize: 23,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final totalDistance = _screenWidth + _childWidth;
          final dx = _screenWidth - _controller.value * totalDistance;
          return Transform(
            transform: Matrix4.translationValues(dx, 0, 0),
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}