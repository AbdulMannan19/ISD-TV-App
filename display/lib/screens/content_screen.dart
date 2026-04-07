import 'package:flutter/material.dart';
import 'dart:async';
import '../services/shared_data.dart';
import '../services/theme_service.dart';
import '../theme/theme_config.dart';
import '../utils/responsive.dart';
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

  double _dynamicFontSize(int length, {bool isMobile = false}) {
    if (isMobile) {
      if (length < 80)  return 24;
      if (length < 150) return 20;
      if (length < 250) return 18;
      if (length < 400) return 15;
      if (length < 600) return 14;
      return 12;
    }
    if (length < 80)  return 36;
    if (length < 150) return 32;
    if (length < 250) return 28;
    if (length < 400) return 24;
    if (length < 600) return 20;
    return 17;
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

    final isPortrait = ResponsiveHelper.isPortrait(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    final isSmallHeight = ResponsiveHelper.isSmallHeight(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: ThemeService().buildBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(isPortrait ? 12.0 : 20.0),
            child: isPortrait ? _buildPortraitLayout(theme, isMobile, isSmallHeight) : _buildLandscapeLayout(theme, isMobile, isSmallHeight),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(ThemeConfig theme, bool isMobile, bool isSmallHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: _buildInfoPanel(theme, isPortrait: true, isSmallHeight: isSmallHeight),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 5,
          child: _buildPrayerBar(theme, isPortrait: true, isSmallHeight: isSmallHeight),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 5,
          child: widget.customContent != null
              ? widget.customContent!(context)
              : _buildDefaultContent(theme, isPortrait: true, isMobile: isMobile, isSmallHeight: isSmallHeight),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(ThemeConfig theme, bool isMobile, bool isSmallHeight) {
    return Column(
      children: [
        Expanded(
          flex: 7,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: widget.customContent != null
                    ? widget.customContent!(context)
                    : _buildDefaultContent(theme, isPortrait: false, isMobile: isMobile, isSmallHeight: isSmallHeight)
              ),
              SizedBox(width: isSmallHeight ? 12 : 20),
              Expanded(
                flex: 3,
                child: _buildInfoPanel(theme, isPortrait: false, isSmallHeight: isSmallHeight)
              ),
            ],
          ),
        ),
        SizedBox(height: isSmallHeight ? 4 : 12),
        Expanded(
          flex: 3,
          child: _buildPrayerBar(theme, isPortrait: false, isSmallHeight: isSmallHeight),
        ),
      ],
    );
  }

  Widget _buildDefaultContent(ThemeConfig theme, {bool isPortrait = false, bool isMobile = false, bool isSmallHeight = false}) {
    final cardBg   = widget.contentBgColor;
    final cardText = widget.contentTextColor;
    final text     = content!['text']!;
    final source   = content!['source']!;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(color: cardText.withOpacity(0.7),
                fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 2)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  primary: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cardText,
                            fontSize: _dynamicFontSize(text.length, isMobile: isMobile),
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            letterSpacing: 0.3)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cardText.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Text(source,
              textAlign: TextAlign.center,
              style: TextStyle(color: cardText.withOpacity(0.8),
                fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(ThemeConfig theme, {bool isPortrait = false, bool isSmallHeight = false}) {
    final shared = SharedData.instance;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.text.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.text.withOpacity(0.08)),
      ),
      padding: EdgeInsets.only(left: isPortrait ? 8 : 16, right: isPortrait ? 8 : 16, top: 12, bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth,
                minHeight: isPortrait ? 0 : constraints.maxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Mosque name + date block
          Column(children: [
            !isPortrait && isSmallHeight 
              ? Text('Islamic Society of Denton', textAlign: TextAlign.center, style: TextStyle(color: theme.accentBright, fontSize: 16, fontWeight: FontWeight.w600)) 
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: theme.text.withOpacity(0.2)), borderRadius: BorderRadius.circular(8)),
                  child: Text('Islamic Society of Denton', textAlign: TextAlign.center,
                    style: TextStyle(color: theme.accentBright, fontSize: 17, fontWeight: FontWeight.w600)),
                ),
            SizedBox(height: isSmallHeight ? 4 : 8),
            Text(_formatDate(_now), textAlign: TextAlign.center,
              style: TextStyle(color: theme.accentBright, fontSize: isSmallHeight ? 14 : 16, letterSpacing: 0.5)),
            if (shared.hijriDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(shared.hijriDate, textAlign: TextAlign.center,
                  style: TextStyle(color: theme.accentBright, fontSize: isSmallHeight ? 15 : 18, letterSpacing: 0.5)),
              ),
          ]),
          // Clock
          _buildClock(theme),
          // Sunrise / Sunset / Last Third
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _sunInfo('SUNRISE', shared.sunrise, theme),
            _sunInfo('LAST THIRD', shared.lastThird, theme),
          ]),
          SizedBox(height: isSmallHeight ? 4 : 8),
          // Iqama countdown
          Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(color: theme.accent.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('${shared.getNextPrayerName()} IQAMAH IN',
                style: TextStyle(color: theme.textMuted, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  const SizedBox(height: 2),
                  Text(shared.getCountdown(),
                    style: TextStyle(color: theme.accentBright, fontSize: isSmallHeight ? 20 : 26, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ]),
              ),
            ],
          ),
        ),
      );
    },
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
          style: TextStyle(color: theme.text, fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: -1)),
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Text(sp.length > 1 ? sp[1] : '',
            style: TextStyle(color: theme.textMuted, fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildPrayerBar(ThemeConfig theme, {bool isPortrait = false, bool isSmallHeight = false}) {
    final shared = SharedData.instance;
    if (shared.prayers.isEmpty) return const SizedBox();
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: isPortrait ? 4 : 12),
      decoration: BoxDecoration(
        color: theme.text.withOpacity(0.04),
        borderRadius: BorderRadius.circular(isPortrait ? 8 : 12),
        border: Border.all(color: theme.text.withOpacity(0.08)),
      ),
      child: isPortrait ? _buildPrayerListPortraitStacked(theme) : Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _prayerBarHeader(theme, isSmallHeight: isSmallHeight),
          const SizedBox(width: 8),
          ...shared.prayers.asMap().entries.map((e) {
            final idx       = e.key;
            final isCurrent = idx == shared.getCurrentPrayerIndex();
            final isNext    = idx == shared.getNextPrayerIndex();
            return Expanded(child: _prayerBarItem(e.value, theme, isCurrent: isCurrent, isNext: isNext, isSmallHeight: isSmallHeight));
          }),
          if (shared.jummah.isNotEmpty) ...[
            Container(width: 1, height: 44, color: theme.textMuted.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 6)),
            _jumuahBarItem(shared.jummah, theme, isSmallHeight: isSmallHeight),
          ],
        ],
      ),
    );
  }

  Widget _buildPrayerListPortraitStacked(ThemeConfig theme) {
    final shared = SharedData.instance;
    return LayoutBuilder(
      builder: (context, constraints) {
        final safeWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 300.0;
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: safeWidth,
              maxWidth: safeWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     ConstrainedBox(
                       constraints: const BoxConstraints(minWidth: 80),
                       child: const SizedBox(),
                     ),
                     Expanded(flex: 3, child: Text('AZAN', textAlign: TextAlign.center, style: TextStyle(color: theme.textMuted, fontSize: 13, fontWeight: FontWeight.bold))),
                     Expanded(flex: 3, child: Text('IQAMAH', textAlign: TextAlign.center, style: TextStyle(color: theme.textMuted, fontSize: 13, fontWeight: FontWeight.bold))),
                   ]
                ),
                const SizedBox(height: 6),
                ...shared.prayers.asMap().entries.map((e) {
                  final idx       = e.key;
                  final isCurrent = idx == shared.getCurrentPrayerIndex();
                  final isNext    = idx == shared.getNextPrayerIndex();
                  return _prayerBarItemStacked(e.value, theme, isCurrent: isCurrent, isNext: isNext);
                }),
                if (shared.jummah.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _jumuahBarItemStacked(shared.jummah, theme),
                ],
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _prayerBarItemStacked(
    Map<String, String> p,
    ThemeConfig theme, {
    bool isCurrent = false,
    bool isNext    = false,
  }) {
    final nameFg = isCurrent ? theme.accentBright : (isNext ? theme.accent : theme.text);
    final rowDecor = BoxDecoration(
      color: isCurrent ? theme.accentBright.withOpacity(0.12) : (isNext ? theme.accent.withOpacity(0.08) : Colors.transparent),
      borderRadius: BorderRadius.circular(6),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: rowDecor,
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 80),
            child: Text(p['name']!, style: TextStyle(color: nameFg, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          Expanded(flex: 3, child: Center(child: _subscriptTime(p['adhan']!, 18, FontWeight.w700, theme, isNext: isNext, isCurrent: isCurrent))),
          Expanded(flex: 3, child: Center(child: _subscriptTime(p['iqamah']!, 18, FontWeight.w700, theme, isAccent: true, isNext: isNext, isCurrent: isCurrent))),
        ],
      ),
    );
  }

  Widget _jumuahBarItemStacked(String time, ThemeConfig theme) {
    final currentIdx = SharedData.instance.getCurrentPrayerIndex();
    final nextIdx = SharedData.instance.getNextPrayerIndex();
    final isCurrent = currentIdx == -2;
    final isNext = nextIdx == -2;
    
    final isHighlighted = isCurrent || isNext;
    final highlightMain = isCurrent ? theme.accentBright : theme.accent;
    final highlightWeight = isCurrent ? FontWeight.w900 : FontWeight.w700;

    final rowDecor = BoxDecoration(
      color: isHighlighted ? (isCurrent ? theme.accentBright.withOpacity(0.12) : theme.accent.withOpacity(0.10)) : theme.accent.withOpacity(0.04),
      borderRadius: BorderRadius.circular(6),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: rowDecor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("JUMU'AH", style: TextStyle(color: isHighlighted ? highlightMain : theme.text, fontSize: 16, fontWeight: highlightWeight)),
          const SizedBox(width: 16),
          _subscriptTime(time, 20, highlightWeight, theme, isAccent: true, isNext: isNext, isCurrent: isCurrent),
          const SizedBox(width: 12),
          Icon(Icons.mosque, size: 20, color: theme.marker.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _prayerBarHeader(ThemeConfig theme, {bool isSmallHeight = false}) {
    // Invisible placeholder matches prayer name height so AZAN/IQAMAH
    // line up with the adhan and iqamah time rows below it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // invisible spacer = prayer name row height (14px font)
        Opacity(
          opacity: 0,
          child: Text('X', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 2),
        Text('AZAN',   style: TextStyle(color: theme.textMuted, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 22),
        Text('IQAMAH', style: TextStyle(color: theme.textMuted, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
      ],
    );
  }

  Widget _prayerBarItem(
    Map<String, String> p,
    ThemeConfig theme, {
    bool isCurrent = false,
    bool isNext    = false,
    bool isSmallHeight = false,
    bool isPortraitMode = false,
  }) {
    final nameFg = isCurrent 
        ? theme.accentBright 
        : (isNext ? theme.accent : theme.text);
    final rowDecor = BoxDecoration(
      color: isCurrent 
          ? theme.accentBright.withOpacity(0.12) 
          : (isNext ? theme.accent.withOpacity(0.08) : Colors.transparent),
      borderRadius: BorderRadius.circular(8),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: EdgeInsets.symmetric(horizontal: isSmallHeight ? 1 : 2),
      padding: EdgeInsets.symmetric(horizontal: isSmallHeight ? 2 : 4, vertical: 2),
      decoration: rowDecor,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(p['name']!,
              style: TextStyle(
                color: nameFg,
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.w900 : (isNext ? FontWeight.w700 : FontWeight.w700),
                letterSpacing: 0.5,
              )),
            if (isPortraitMode) ...[
              const SizedBox(height: 2),
              Text('AZAN', style: TextStyle(color: theme.textMuted, fontSize: 8, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 2),
            _subscriptTime(p['adhan']!,  isSmallHeight ? 22 : 30, FontWeight.w700, theme, isNext: isNext, isCurrent: isCurrent),
            
            if (isPortraitMode) ...[
              const SizedBox(height: 2),
              Text('IQAMAH', style: TextStyle(color: theme.textMuted, fontSize: 8, fontWeight: FontWeight.w600)),
            ],
            _subscriptTime(p['iqamah']!, isSmallHeight ? 22 : 30, FontWeight.w700, theme, isAccent: true, isNext: isNext, isCurrent: isCurrent),
          ],
        ),
      ),
    );
  }

  Widget _jumuahBarItem(String time, ThemeConfig theme, {bool isSmallHeight = false, bool isPortraitMode = false}) {
    final currentIdx = SharedData.instance.getCurrentPrayerIndex();
    final nextIdx = SharedData.instance.getNextPrayerIndex();
    final isCurrent = currentIdx == -2;
    final isNext = nextIdx == -2;
    
    final isHighlighted = isCurrent || isNext;
    final highlightMain = isCurrent ? theme.accentBright : theme.accent;
    final highlightWeight = isCurrent ? FontWeight.w900 : FontWeight.w700;

    final rowDecor = BoxDecoration(
      color: isHighlighted 
          ? (isCurrent ? theme.accentBright.withOpacity(0.12) : theme.accent.withOpacity(0.10))
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: rowDecor,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("JUMU'AH", 
                  style: TextStyle(
                    color: isHighlighted ? highlightMain : theme.text, 
                    fontSize: 14, 
                    fontWeight: highlightWeight, 
                    letterSpacing: 0.5,
                  )),
                if (isPortraitMode) ...[
                  const SizedBox(height: 2),
                  Text('IQAMAH', style: TextStyle(color: theme.textMuted, fontSize: 8, fontWeight: FontWeight.w600)),
                ],
                _subscriptTime(time, isSmallHeight ? 22 : 30, highlightWeight, theme, isAccent: true, isNext: isNext, isCurrent: isCurrent),
              ],
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              child: Icon(Icons.mosque, size: 24, color: theme.marker.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sunInfo(String label, String time, ThemeConfig theme) {
    return Column(children: [
      Text(label, style: TextStyle(color: theme.textMuted, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      _subscriptTime(time, 22, FontWeight.w600, theme),
    ]);
  }

  Widget _subscriptTime(String time, double fontSize, FontWeight weight, ThemeConfig theme, {bool isAccent = false, bool isNext = false, bool isCurrent = false}) {
    final cMain = isCurrent 
        ? theme.accentBright
        : (isNext ? theme.accent : (isAccent ? theme.accentBright : theme.text));
    final cSub = (isNext || isCurrent)
        ? cMain
        : (isAccent ? theme.accent : theme.textMuted);
    final sp = time.split(' ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(sp[0], style: TextStyle(color: cMain, fontSize: fontSize, fontWeight: isNext ? FontWeight.w900 : (isCurrent ? FontWeight.w700 : weight))),
        if (sp.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 1, left: 2),
            child: Text(sp[1], style: TextStyle(color: cSub, fontSize: fontSize * 0.55, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}
