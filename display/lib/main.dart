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
import 'services/hadith_service.dart';
import 'services/dua_service.dart';
import 'services/verse_service.dart';
import 'services/slides_service.dart';
import 'utils/test_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  // Pre-fetch today's content on startup
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
  List<Widget> _screens = [];
  bool _screensBuilt = false;
  
  @override
  void initState() {
    super.initState();
    _buildScreens();
    
    // Rotate screens every 30 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (mounted && _screensBuilt) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _screens.length;
        });
      }
      return mounted;
    });
    
    // Check for new day every hour and fetch fresh content
    _midnightCheckTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      final hadithService = HadithService();
      final duaService = DuaService();
      final verseService = VerseService();
      
      await Future.wait([
        hadithService.getTodaysHadith(),
        duaService.getTodaysDua(),
        verseService.getTodaysVerse(),
      ]);
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
    
    // Add one SlidesScreen that will rotate through all slides internally
    if (slides.isNotEmpty) {
      screens.add(const SlidesScreen());
    }
    
    if (mounted) {
      setState(() {
        _screens = screens;
        _screensBuilt = true;
      });
    }
  }

  @override
  void dispose() {
    _midnightCheckTimer?.cancel();
    super.dispose();
  }

  void _goToPrevious() {
    if (_screensBuilt) {
      setState(() {
        _currentIndex = (_currentIndex - 1 + _screens.length) % _screens.length;
      });
    }
  }

  void _goToNext() {
    if (_screensBuilt) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _screens.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_screensBuilt) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A2A5E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        
        TestControls(
          onPrevious: _goToPrevious,
          onNext: _goToNext,
        ),
      ],
    );
  }
}
