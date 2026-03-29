import 'package:flutter/material.dart';
import 'dart:async';
import '../services/shared_data.dart';
import '../services/theme_service.dart';
import '../theme/theme_config.dart';
import 'settings_screen.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime dt) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final shared = SharedData.instance;
    final theme = ThemeService().current;
    
    if (shared.prayers.isEmpty) {
      return Scaffold(
        backgroundColor: theme.bg,
        body: Center(
          child: CircularProgressIndicator(color: theme.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.bg,
      body: ThemeService().buildBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return constraints.maxWidth > 650 ? _buildWide(theme) : _buildNarrow(theme);
          },
        ),
      ),
    );
  }

  Widget _buildWide(ThemeConfig theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _buildPrayerTable(theme)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _buildRightPanel(theme)),
        ],
      ),
    );
  }

  Widget _buildNarrow(ThemeConfig theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPrayerTable(theme),
          const SizedBox(height: 16),
          _buildRightPanel(theme),
        ],
      ),
    );
  }

  Widget _buildPrayerTable(ThemeConfig theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.text.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.text.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(
                flex: 3,
                child: Text(
                  'STARTS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'IQAMAH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: theme.text.withOpacity(0.1)),
          const SizedBox(height: 4),
          ...SharedData.instance.prayers.asMap().entries.map((e) {
            final idx      = e.key;
            final isCurrent = idx == SharedData.instance.getCurrentPrayerIndex();
            final isNext    = idx == SharedData.instance.getNextPrayerIndex();
            return Expanded(child: _prayerRow(e.value, theme, isCurrent: isCurrent, isNext: isNext));
          }),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.accent.withOpacity(0.15)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "JUMU'AH",
                  style: TextStyle(
                    color: theme.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(width: 20),
                _subscriptTime(SharedData.instance.jummah, 28, FontWeight.w600, theme, isAccent: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prayerRow(
    Map<String, String> p,
    ThemeConfig theme, {
    bool isCurrent = false,
    bool isNext = false,
  }) {
    // Background highlight only — no border, no badge
    final rowDecor = isNext
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.accent.withOpacity(0.18),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          )
        : isCurrent
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.accent.withOpacity(0.15),
              )
            : null;
    final nameFg = isNext
        ? theme.accentBright
        : isCurrent
            ? theme.accent
            : theme.text;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: rowDecor,
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              p['name']!,
              style: TextStyle(
                color: nameFg,
                fontWeight: isNext ? FontWeight.w900 : FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(flex: 3, child: _timeCell(p['adhan']!, theme, isNext: isNext, isCurrent: isCurrent)),
          Expanded(flex: 3, child: _timeCell(p['iqamah']!, theme, isAccent: true, isNext: isNext, isCurrent: isCurrent)),
        ],
      ),
    );
  }

  Widget _timeCell(String time, ThemeConfig theme, {bool isAccent = false, bool dimmed = false, bool isNext = false, bool isCurrent = false}) {
    final sp = time.split(' ');
    final primaryColor = isAccent 
        ? (isNext ? theme.accentBright : (isCurrent ? theme.accent : theme.accentBright))
        : (isNext ? theme.accent : (isCurrent ? theme.accent.withOpacity(0.8) : theme.text));
    final secColor     = isAccent ? theme.accent : theme.textMuted;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          sp[0],
          style: TextStyle(
            color: primaryColor,
            fontSize: 40,
            fontWeight: FontWeight.w600,
            shadows: isAccent && !dimmed && theme.glowIntensity > 1.0 ? [
              Shadow(color: theme.accent, blurRadius: 10 * theme.glowIntensity)
            ] : null,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          sp.length > 1 ? sp[1] : '',
          style: TextStyle(color: secColor, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildRightPanel(ThemeConfig theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.text.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.text.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.accent.withOpacity(0.5), width: 2),
                ),
                child: Image.asset('assets/images/qr_code.jpeg', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.qr_code_2, size: 50, color: Colors.black54))),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white38),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Islamic Society of Denton',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.accentBright,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(_now),
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 12,
                ),
              ),
              if (SharedData.instance.hijriDate.isNotEmpty)
                Text(
                  SharedData.instance.hijriDate,
                  style: TextStyle(
                    color: theme.textMuted.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _liveClock(theme),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  'NEXT IQAMAH IN',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SharedData.instance.getCountdown(),
                  style: TextStyle(
                    color: theme.accentBright,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _sunInfo('SUNRISE', SharedData.instance.sunrise, theme),
              _sunInfo('SUNSET', SharedData.instance.sunset, theme),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            child: Icon(Icons.mosque, size: 28, color: theme.marker.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _liveClock(ThemeConfig theme) {
    final timeStr = _formatTime(_now);
    final sp = timeStr.split(' ');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          sp[0],
          style: TextStyle(
            color: theme.text,
            fontSize: 54,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            sp.length > 1 ? sp[1] : '',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sunInfo(String label, String time, ThemeConfig theme) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 12,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        _subscriptTime(time, 22, FontWeight.w600, theme),
      ],
    );
  }

  Widget _subscriptTime(String time, double fontSize, FontWeight weight, ThemeConfig theme, {bool isAccent = false}) {
    final cMain = isAccent ? theme.accentBright : theme.text;
    final cSub = isAccent ? theme.accent : theme.textMuted;
    final sp = time.split(' ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(sp[0], style: TextStyle(color: cMain, fontSize: fontSize, fontWeight: weight)),
        if (sp.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 1, left: 2),
            child: Text(sp[1], style: TextStyle(color: cSub, fontSize: fontSize * 0.55, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}
