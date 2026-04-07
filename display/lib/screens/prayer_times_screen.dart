import 'package:flutter/material.dart';
import 'dart:async';
import '../services/shared_data.dart';
import '../services/theme_service.dart';
import '../theme/theme_config.dart';
import '../utils/responsive.dart';
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
    _now = SharedData.instance.now;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = SharedData.instance.now);
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
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isPortrait = ResponsiveHelper.isPortrait(context);
              final isSmallHeight = ResponsiveHelper.isSmallHeight(context);
              final useSmallFonts = isPortrait || isSmallHeight;
              return isPortrait 
                 ? _buildNarrow(theme, isSmallHeight: useSmallFonts) 
                 : _buildWide(theme, isSmallHeight: useSmallFonts);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWide(ThemeConfig theme, {bool isSmallHeight = false}) {
    return Padding(
      padding: EdgeInsets.all(isSmallHeight ? 12 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _buildPrayerTable(theme, isPortrait: false, isSmallHeight: isSmallHeight)),
          SizedBox(width: isSmallHeight ? 12 : 16),
          Expanded(flex: 2, child: _buildRightPanel(theme, isPortrait: false, isSmallHeight: isSmallHeight)),
        ],
      ),
    );
  }

  Widget _buildNarrow(ThemeConfig theme, {bool isSmallHeight = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRightPanel(theme, isPortrait: true, isSmallHeight: isSmallHeight),
          const SizedBox(height: 16),
          _buildPrayerTable(theme, isPortrait: true, isSmallHeight: isSmallHeight),
        ],
      ),
    );
  }

  Widget _buildPrayerTable(ThemeConfig theme, {bool isPortrait = false, bool isSmallHeight = false}) {
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
                  'AZAN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 18,
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
                    fontSize: 18,
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
            final child = Center(child: _prayerRow(e.value, theme, isCurrent: isCurrent, isNext: isNext, isSmallHeight: isSmallHeight));
            return isPortrait ? Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: child) : Expanded(child: child);
          }),
          const SizedBox(height: 12),
          _buildJumuahBox(theme, isSmallHeight: isSmallHeight),
        ],
      ),
    );
  }

  Widget _buildJumuahBox(ThemeConfig theme, {bool isSmallHeight = false}) {
    final currentIdx = SharedData.instance.getCurrentPrayerIndex();
    final nextIdx = SharedData.instance.getNextPrayerIndex();
    final isCurrent = currentIdx == -2;
    final isNext = nextIdx == -2;
    
    final isHighlighted = isCurrent || isNext;
    final highlightMain = isCurrent ? theme.accentBright : theme.accent;
    final highlightWeight = isCurrent ? FontWeight.w900 : FontWeight.bold;

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted 
            ? (isCurrent ? theme.accentBright.withOpacity(0.18) : theme.accent.withOpacity(0.12))
            : theme.accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted ? highlightMain : theme.accent.withOpacity(0.15)
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: isSmallHeight ? 8 : 12, horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "JUMU'AH",
                style: TextStyle(
                  color: isHighlighted ? highlightMain : theme.text,
                  fontWeight: highlightWeight,
                  fontSize: isSmallHeight ? 16 : 26,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 20),
              _subscriptTime(
                SharedData.instance.jummah, 
                isSmallHeight ? 20 : 32, 
                highlightWeight, 
                theme, 
                isAccent: true,
                isNext: isNext,
                isCurrent: isCurrent,
              ),
            ],
          ),
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              child: Icon(Icons.mosque, size: isSmallHeight ? 22 : 28, color: theme.marker.withOpacity(0.5)),
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
    bool isSmallHeight = false,
  }) {
    final nameFg = isCurrent 
        ? theme.accentBright 
        : (isNext ? theme.accent : theme.text);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: isCurrent 
            ? theme.accentBright.withOpacity(0.12) 
            : (isNext ? theme.accent.withOpacity(0.08) : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  p['name']!,
                  style: TextStyle(
                    color: nameFg,
                    fontWeight: isCurrent ? FontWeight.w900 : (isNext ? FontWeight.w700 : FontWeight.bold),
                    fontSize: isSmallHeight ? 16 : 24,
                    letterSpacing: isSmallHeight ? 0.5 : 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(flex: 3, child: Center(child: _timeCell(p['adhan']!, theme, isNext: isNext, isCurrent: isCurrent, isSmallHeight: isSmallHeight))),
          Expanded(flex: 3, child: Center(child: _timeCell(p['iqamah']!, theme, isAccent: true, isNext: isNext, isCurrent: isCurrent, isSmallHeight: isSmallHeight))),
        ],
      ),
    );
}

  Widget _timeCell(String time, ThemeConfig theme, {bool isAccent = false, bool dimmed = false, bool isNext = false, bool isCurrent = false, bool isSmallHeight = false}) {
    final sp = time.split(' ');
    final primaryColor = isCurrent
        ? theme.accentBright
        : (isNext ? theme.accent : (isAccent ? theme.accentBright : theme.text));
    final secColor     = (isNext || isCurrent) 
        ? primaryColor 
        : (isAccent ? theme.accent : theme.textMuted);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          sp[0],
          style: TextStyle(
            color: primaryColor,
            fontSize: isSmallHeight ? 22 : 42,
            fontWeight: isCurrent ? FontWeight.w900 : (isNext ? FontWeight.w700 : FontWeight.w600),
          ),
        ),
        const SizedBox(width: 2),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            sp.length > 1 ? sp[1] : '',
            style: TextStyle(color: secColor, fontSize: isSmallHeight ? 9 : 13),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(ThemeConfig theme, {bool isPortrait = false, bool isSmallHeight = false}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.text.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.text.withOpacity(0.08)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSmallHeight ? 8 : 12),
      child: isPortrait ? Column(
        children: _buildRightPanelChildren(theme, isSmallHeight: isSmallHeight),
      ) : LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                maxWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 300,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _buildRightPanelChildren(theme, isSmallHeight: isSmallHeight),
              ),
            ),
          );
        }
      ),
    );
  }

  List<Widget> _buildRightPanelChildren(ThemeConfig theme, {bool isSmallHeight = false}) {
    return [
          Column(
            children: [
              Container(
                width: isSmallHeight ? 60 : 80,
                height: isSmallHeight ? 60 : 80,
                decoration: BoxDecoration(
                  color: theme.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.accent.withOpacity(0.5), width: 2),
                ),
                child: Image.asset('assets/images/qr_code.jpeg', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(child: Icon(Icons.qr_code_2, size: isSmallHeight ? 35 : 50, color: Colors.black54))),
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
                    fontSize: isSmallHeight ? 16 : 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(_now),
                style: TextStyle(
                  color: theme.accentBright,
                  fontSize: isSmallHeight ? 14 : 16,
                ),
              ),
              if (SharedData.instance.hijriDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  SharedData.instance.hijriDate,
                  style: TextStyle(
                    color: theme.accentBright,
                    fontSize: isSmallHeight ? 15 : 18,
                  )),
                ),
            ],
          ),
          SizedBox(height: isSmallHeight ? 8 : 16),
          _liveClock(theme, isSmallHeight: isSmallHeight),
          SizedBox(height: isSmallHeight ? 8 : 16),
          Container(
            padding: EdgeInsets.symmetric(vertical: isSmallHeight ? 8 : 12, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${SharedData.instance.getNextPrayerName()} IQAMA IN',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: isSmallHeight ? 11 : 13,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SharedData.instance.getCountdown(),
                  style: TextStyle(
                    color: theme.accentBright,
                    fontSize: isSmallHeight ? 24 : 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallHeight ? 8 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _sunInfo('SUNRISE', SharedData.instance.sunrise, theme, isSmallHeight: isSmallHeight),
              _sunInfo('SUNSET', SharedData.instance.sunset, theme, isSmallHeight: isSmallHeight),
              _sunInfo('LAST THIRD', SharedData.instance.lastThird, theme, isSmallHeight: isSmallHeight),
            ],
          ),
        ];
  }

  Widget _liveClock(ThemeConfig theme, {bool isSmallHeight = false}) {
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
            fontSize: isSmallHeight ? 40 : 55,
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
              fontSize: isSmallHeight ? 18 : 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sunInfo(String label, String time, ThemeConfig theme, {bool isSmallHeight = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textMuted,
            fontSize: isSmallHeight ? 10 : 12,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        _subscriptTime(time, isSmallHeight ? 20 : 24, FontWeight.w600, theme),
      ],
    );
  }

  Widget _subscriptTime(String time, double fontSize, FontWeight weight, ThemeConfig theme, {bool isAccent = false, bool isNext = false, bool isCurrent = false}) {
    final cMain = isAccent 
        ? (isCurrent ? theme.accentBright : (isNext ? theme.accent : theme.accentBright))
        : (isCurrent ? theme.accent : (isNext ? theme.accent : theme.text));
    final cSub = (isNext || isCurrent)
        ? cMain
        : (isAccent ? theme.accent : theme.textMuted);
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
