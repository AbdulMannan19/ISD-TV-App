import 'package:flutter/material.dart';
import 'dart:async';
import '../services/hadith_service.dart';
import '../services/shared_data.dart';

class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  late DateTime _now;
  late Timer _timer;
  final HadithService _hadithService = HadithService();
  Map<String, String>? todaysHadith;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    _loadHadith();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadHadith() async {
    final hadith = await _hadithService.getTodaysHadith();
    if (mounted) setState(() { todaysHadith = hadith; isLoading = false; });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute$period';
  }

  String _formatDate(DateTime dt) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || todaysHadith == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A3A6B),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E4D8C), Color(0xFF0F2D5E), Color(0xFF1A3A6B)],
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
                      Expanded(flex: 7, child: _buildContent()),
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

  Widget _buildContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HADITH OF THE DAY',
            style: TextStyle(color: const Color(0xFF0A2A5E).withOpacity(0.6),
              fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 3)),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Text(todaysHadith!['text']!,
                style: const TextStyle(color: Color(0xFF1a1a2e),
                  fontSize: 20, fontWeight: FontWeight.w400, height: 1.6, letterSpacing: 0.3)),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2A5E).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
            child: Text(todaysHadith!['source']!,
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/qr_code.jpeg', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.qr_code_2, size: 50, color: Colors.black54))),
              ),
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
          ]),
          Column(children: [
            Text(_formatTime(_now),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w200, letterSpacing: -1)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _sunInfo('☀️', 'SUNRISE', shared.sunrise),
              _sunInfo('🌅', 'SUNSET', shared.sunset),
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
          if (shared.jummah1.isNotEmpty) ...[
            Container(width: 1, height: 44, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 10)),
            _jumuahBarItem(shared.jummah1, shared.jummah2),
          ],
        ],
      ),
    );
  }

  Widget _prayerBarHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 16),
        Text('STARTS', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text('IQAMAH', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      ],
    );
  }

  Widget _prayerBarItem(Map<String, String> p) {
    return Column(
      children: [
        Text(p['name']!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(p['adhan']!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(p['iqamah']!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _jumuahBarItem(String j1, String j2) {
    return Column(
      children: [
        const Text("JUMU'AH", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        Row(children: [
          Column(children: [
            Text('1st', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
            Text(j1, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(width: 14),
          Column(children: [
            Text('2nd', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
            Text(j2, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ],
    );
  }

  Widget _sunInfo(String icon, String label, String time) {
    return Column(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(time, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }
}
