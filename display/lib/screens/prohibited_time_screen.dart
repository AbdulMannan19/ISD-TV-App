import 'package:flutter/material.dart';
import 'dart:async';
import 'content_screen.dart';
import '../services/shared_data.dart';
import '../utils/responsive.dart';

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
    final isMobile = ResponsiveHelper.isMobile(context);
    return ContentScreen(
      title: 'PROHIBITED TIME FOR VOLUNTARY SALAH',
      customContent: (_) => _buildProhibitedContent(isMobile),
    );
  }

  Widget _buildProhibitedContent(bool isMobile) {
    const accent = Color(0xFFC62828);   
    const cardBg  = Color(0xFFFFF1F1); 
    
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        primary: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('PROHIBITED TIME FOR VOLUNTARY SALAH',
              textAlign: TextAlign.center,
              style: TextStyle(color: accent.withOpacity(0.8),
                fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.w700, letterSpacing: 2)),
            SizedBox(height: isMobile ? 12 : 8),
            Text('$_remainingMinutes',
              style: TextStyle(color: accent,
                fontSize: isMobile ? 42 : 56, fontWeight: FontWeight.w700, height: 1)),
            const SizedBox(height: 2),
            Text(_remainingMinutes == 1 ? 'MINUTE REMAINING' : 'MINUTES REMAINING',
              style: TextStyle(color: accent.withOpacity(0.6),
                fontSize: isMobile ? 13 : 16, fontWeight: FontWeight.w600, letterSpacing: 2)),
            SizedBox(height: isMobile ? 16 : 12),
            Text(
              '"There were three times at which Allah\'s Messenger used to forbid us to pray or bury our dead: when the sun begins to rise till it is fully up, when the sun is at its height at midday till it passes over the meridian, and when the sun draws near to setting till it sets."',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black87,
                fontSize: isMobile ? 15 : 19, fontStyle: FontStyle.italic, height: 1.5)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text('— Sahih Muslim, 831',
                style: TextStyle(color: accent.withOpacity(0.6),
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 12, vertical: isMobile ? 12 : 8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
              child: Text('Fard prayers can still be prayed',
                textAlign: TextAlign.center,
                style: TextStyle(color: accent.withOpacity(0.7),
                  fontSize: isMobile ? 15 : 20, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
