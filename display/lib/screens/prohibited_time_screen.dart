import 'package:flutter/material.dart';
import 'dart:async';
import 'content_screen.dart';
import '../services/shared_data.dart';

class ProhibitedTimeScreen extends StatefulWidget {
  final DateTime endTime;

  const ProhibitedTimeScreen({super.key, required this.endTime});

  @override
  State<ProhibitedTimeScreen> createState() => _ProhibitedTimeScreenState();
}

class _ProhibitedTimeScreenState extends State<ProhibitedTimeScreen> {
  late Timer _timer;
  int _remainingMinutes = 1;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _updateRemainingTime());
    });
  }

  void _updateRemainingTime() {
    final remaining = widget.endTime.difference(SharedData.instance.now);
    final secs = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
    _remainingMinutes = (secs / 60).ceil().clamp(1, 15);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentScreen(
      title: 'PROHIBITED TIME FOR VOLUNTARY SALAH',
      customContent: (_) => _buildProhibitedContent(),
    );
  }

  Widget _buildProhibitedContent() {
    const accent = Color(0xFFC62828);   // fixed crimson red
    const cardBg  = Color(0xFFFFF1F1); // light rose — same style as Dua
    
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(36, 12, 36, 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('PROHIBITED TIME FOR VOLUNTARY SALAH',
            textAlign: TextAlign.center,
            style: TextStyle(color: accent.withOpacity(0.8),
              fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 3)),
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$_remainingMinutes',
                      style: const TextStyle(color: accent,
                        fontSize: 72, fontWeight: FontWeight.w700, height: 1)),
                    const SizedBox(height: 4),
                    Text(_remainingMinutes == 1 ? 'MINUTE REMAINING' : 'MINUTES REMAINING',
                      style: TextStyle(color: accent.withOpacity(0.6),
                        fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 2)),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '"There were three times at which Allah\'s Messenger used to forbid us to pray or bury our dead: when the sun begins to rise till it is fully up, when the sun is at its height at midday till it passes over the meridian, and when the sun draws near to setting till it sets."',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 28, fontStyle: FontStyle.italic, height: 1.6)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 24, top: 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('— Sahih Muslim, 831',
                          style: TextStyle(color: accent.withOpacity(0.6),
                            fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
            child: Text('Fard prayers can still be prayed',
              textAlign: TextAlign.center,
              style: TextStyle(color: accent.withOpacity(0.7),
                fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}
