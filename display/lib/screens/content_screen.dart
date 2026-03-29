import 'package:flutter/material.dart';
import 'dart:async';
import '../services/shared_data.dart';
import '../services/theme_service.dart';
import '../theme/theme_config.dart';
import 'settings_screen.dart';

class ContentScreen extends StatefulWidget {
  final String title;
  final Future<Map<String, String>> Function()? fetchContent;
  final Widget Function(BuildContext context)? customContent;
  final Color contentBgColor;
  final Color contentTextColor;

  const ContentScreen({
    super.key,
    required this.title,
    this.fetchContent,
    this.customContent,
    this.contentBgColor = const Color(0xF2FFFFFF),
    this.contentTextColor = const Color(0xFF1a1a2e),
  });

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  late DateTime _now;
  late Timer _timer;
  Map<String, String>? content;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    if (widget.fetchContent != null) {
      _loadContent();
    } else {
      isLoading = false;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final data = await widget.fetchContent!();
    if (mounted) setState(() { content = data; isLoading = false; });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime dt) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  double _dynamicFontSize(int length) {
    if (length < 100) return 32;
    if (length < 200) return 26;
    if (length < 400) return 22;
    return 18;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService().current;
    
    if (isLoading) {
      return Scaffold(
        backgroundColor: theme.bg,
        body: Center(child: CircularProgressIndicator(color: theme.accent)),
      );
    }

    return Scaffold(
      backgroundColor: theme.bg,
      body: ThemeService().buildBackground(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: widget.customContent != null
                        ? widget.customContent!(context)
                        : _buildDefaultContent(theme)),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: _buildInfoPanel(theme)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildPrayerBar(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultContent(ThemeConfig theme) {
    // Content cards always keep their original parchment + golden styling
    // regardless of the active theme — only the surrounding background changes.
    final cardBg = widget.contentBgColor;       // default: 0xFFFAF6F0 cream
    final cardText = widget.contentTextColor;    // default: 0xFF8B6914 golden
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(color: cardText.withOpacity(0.7),
              fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 3)),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(content!['text']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cardText,
                    fontSize: _dynamicFontSize(content!['text']!.length), fontWeight: FontWeight.w400, height: 1.6, letterSpacing: 0.3)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cardText.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Text(content!['source']!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cardText.withOpacity(0.8),
                fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(ThemeConfig theme) {
    final shared = SharedData.instance;
    return Container(
      decoration: BoxDecoration(
        color: theme.text.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.text.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: theme.text.withOpacity(0.2)), borderRadius: BorderRadius.circular(8)),
              child: Text('Islamic Society of Denton', textAlign: TextAlign.center,
                style: TextStyle(color: theme.accentBright, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            Text(_formatDate(_now), textAlign: TextAlign.center,
              style: TextStyle(color: theme.textMuted, fontSize: 13, letterSpacing: 0.5)),
            if (shared.hijriDate.isNotEmpty)
              Text(shared.hijriDate, textAlign: TextAlign.center,
                style: TextStyle(color: theme.textMuted.withOpacity(0.8), fontSize: 12, letterSpacing: 0.5)),
          ]),
          const Spacer(),
          _buildClock(theme),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _sunInfo('SUNRISE', shared.sunrise, theme),
            _sunInfo('SUNSET', shared.sunset, theme),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.accent.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text('NEXT IQAMAH IN',
                style: TextStyle(color: theme.textMuted, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(shared.getCountdown(),
                style: TextStyle(color: theme.accentBright, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildClock(ThemeConfig theme) {
    final timeStr = _formatTime(_now);
    final sp = timeStr.split(' ');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(sp[0],
          style: TextStyle(color: theme.text, fontSize: 54, fontWeight: FontWeight.w700, letterSpacing: -1)),
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Text(sp.length > 1 ? sp[1] : '',
            style: TextStyle(color: theme.textMuted, fontSize: 18, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildPrayerBar(ThemeConfig theme) {
    final shared = SharedData.instance;
    if (shared.prayers.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.text.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.text.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          _prayerBarHeader(theme),
          const SizedBox(width: 16),
          ...shared.prayers.asMap().entries.map((e) {
            final idx       = e.key;
            final isCurrent = idx == shared.getCurrentPrayerIndex();
            final isNext    = idx == shared.getNextPrayerIndex();
            return Expanded(child: _prayerBarItem(e.value, theme, isCurrent: isCurrent, isNext: isNext));
          }),
          if (shared.jummah.isNotEmpty) ...[
            Container(width: 1, height: 44, color: theme.textMuted.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 10)),
            _jumuahBarItem(shared.jummah, theme),
          ],
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            child: Icon(Icons.mosque, size: 24, color: theme.marker.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _prayerBarHeader(ThemeConfig theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 20),
        Text('STARTS', style: TextStyle(color: theme.textMuted, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text('IQAMAH', style: TextStyle(color: theme.textMuted, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
      ],
    );
  }

  Widget _prayerBarItem(
    Map<String, String> p,
    ThemeConfig theme, {
    bool isCurrent = false,
    bool isNext    = false,
  }) {
    final nameFg = isNext
        ? theme.accentBright
        : isCurrent
            ? theme.accent
            : theme.text;
    final rowDecor = isNext
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.accent.withOpacity(0.18),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          )
        : isCurrent
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.accent.withOpacity(0.15),
              )
            : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: rowDecor,
      child: Column(
        children: [
          Text(p['name']!,
            style: TextStyle(
              color: nameFg,
              fontSize: 18,
              fontWeight: isNext ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: 1,
            )),
          const SizedBox(height: 4),
          _subscriptTime(p['adhan']!,  22, FontWeight.w700, theme, isNext: isNext, isCurrent: isCurrent),
          const SizedBox(height: 2),
          _subscriptTime(p['iqamah']!, 22, FontWeight.w700, theme, isAccent: true, isNext: isNext, isCurrent: isCurrent),
        ],
      ),
    );
  }

  Widget _jumuahBarItem(String time, ThemeConfig theme) {
    return Column(
      children: [
        Text("JUMU'AH", style: TextStyle(color: theme.text, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        _subscriptTime(time, 22, FontWeight.w700, theme, isAccent: true),
      ],
    );
  }

  Widget _sunInfo(String label, String time, ThemeConfig theme) {
    return Column(children: [
      Text(label, style: TextStyle(color: theme.textMuted, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      _subscriptTime(time, 22, FontWeight.w600, theme),
    ]);
  }

  Widget _subscriptTime(String time, double fontSize, FontWeight weight, ThemeConfig theme, {bool isAccent = false, bool isNext = false, bool isCurrent = false}) {
    final cMain = isAccent 
        ? (isNext ? theme.accentBright : (isCurrent ? theme.accent : theme.accentBright))
        : (isNext ? theme.accent : (isCurrent ? theme.accent.withOpacity(0.8) : theme.text));
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
