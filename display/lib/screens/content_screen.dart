import 'package:flutter/material.dart';
import 'dart:async';
import '../services/shared_data.dart';
import 'settings_screen.dart';

class ContentScreen extends StatefulWidget {
  final String title;
  final Future<Map<String, String>> Function()? fetchContent;
  final Widget Function(BuildContext context)? customContent;

  const ContentScreen({
    super.key,
    required this.title,
    this.fetchContent,
    this.customContent,
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
    if (length < 100) return 28;
    if (length < 200) return 22;
    return 19;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF000428),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF000428), Color(0xFF004E92), Color(0xFF001F54)],
          ),
        ),
        child: SafeArea(
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
                          : _buildDefaultContent()),
                      const SizedBox(width: 20),
                      Expanded(flex: 3, child: _buildInfoPanel()),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildPrayerBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(color: const Color(0xFF0A2A5E).withOpacity(0.6),
              fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 3)),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(content!['text']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: const Color(0xFF1a1a2e),
                    fontSize: _dynamicFontSize(content!['text']!.length), fontWeight: FontWeight.w400, height: 1.6, letterSpacing: 0.3)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2A5E).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
            child: Text(content!['source']!,
              textAlign: TextAlign.center,
              style: TextStyle(color: const Color(0xFF0A2A5E).withOpacity(0.7),
                fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    final shared = SharedData.instance;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: Colors.white),
              child: Image.asset('assets/images/qr_code.jpeg', fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.qr_code_2, size: 50, color: Colors.black54))),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(8)),
              child: const Text('Islamic Society of Denton', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Text(_formatDate(_now), textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, letterSpacing: 0.5)),
            if (shared.hijriDate.isNotEmpty)
              Text(shared.hijriDate, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, letterSpacing: 0.5)),
          ]),
          Column(children: [
            _buildClock(),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _sunInfo('SUNRISE', shared.sunrise),
              _sunInfo('SUNSET', shared.sunset),
            ]),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Text('NEXT IQAMAH IN',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text(shared.getCountdown(),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ]),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildClock() {
    final timeStr = _formatTime(_now);
    final sp = timeStr.split(' ');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(sp[0],
          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -1)),
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Text(sp.length > 1 ? sp[1] : '',
            style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildPrayerBar() {
    final shared = SharedData.instance;
    if (shared.prayers.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          _prayerBarHeader(),
          const SizedBox(width: 16),
          ...shared.prayers.map((p) => Expanded(child: _prayerBarItem(p))),
          if (shared.jummah.isNotEmpty) ...[
            Container(width: 1, height: 44, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 10)),
            _jumuahBarItem(shared.jummah),
          ],
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            child: Icon(Icons.mosque, size: 24, color: Colors.white.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _prayerBarHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 20),
        Text('STARTS', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text('IQAMAH', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
      ],
    );
  }

  Widget _prayerBarItem(Map<String, String> p) {
    return Column(
      children: [
        Text(p['name']!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        _subscriptTime(p['adhan']!, 22, FontWeight.w700),
        const SizedBox(height: 2),
        _subscriptTime(p['iqamah']!, 22, FontWeight.w700),
      ],
    );
  }

  Widget _jumuahBarItem(String time) {
    return Column(
      children: [
        const Text("JUMU'AH", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        _subscriptTime(time, 22, FontWeight.w700),
      ],
    );
  }

  Widget _sunInfo(String label, String time) {
    return Column(children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      _subscriptTime(time, 15, FontWeight.w500),
    ]);
  }

  Widget _subscriptTime(String time, double fontSize, FontWeight weight, {double opacity = 1.0}) {
    final sp = time.split(' ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(sp[0], style: TextStyle(color: Colors.white.withOpacity(opacity), fontSize: fontSize, fontWeight: weight)),
        if (sp.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 1, left: 2),
            child: Text(sp[1], style: TextStyle(color: Colors.white70.withOpacity(opacity), fontSize: fontSize * 0.55, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}
