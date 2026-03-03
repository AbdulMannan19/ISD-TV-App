import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'screens/prayer_times_screen.dart';
import 'screens/hadith_screen.dart';
import 'services/hadith_service.dart';
import 'utils/test_controls.dart'; // TODO: Remove in production

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  // Pre-fetch today's hadiths on startup
  final hadithService = HadithService();
  await hadithService.getTodaysHadiths();
  
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
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
  
  final List<Widget> _screens = const [
    PrayerTimesScreen(),
    HadithScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Rotate screens every 30 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _screens.length;
        });
      }
      return mounted;
    });
    
    // Check for new day every hour and fetch fresh hadiths
    _midnightCheckTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      final hadithService = HadithService();
      await hadithService.getTodaysHadiths();
    });
  }

  @override
  void dispose() {
    _midnightCheckTimer?.cancel();
    super.dispose();
  }

  void _goToPrevious() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _screens.length) % _screens.length;
    });
  }

  void _goToNext() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _screens.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _screens[_currentIndex],
        
        // TODO: Remove TestControls in production
        TestControls(
          onPrevious: _goToPrevious,
          onNext: _goToNext,
        ),
      ],
    );
  }
}
