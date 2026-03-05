import 'package:flutter/material.dart';
import 'dart:async';
import '../services/dua_service.dart';

class DuaScreen extends StatefulWidget {
  const DuaScreen({super.key});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  late DateTime _now;
  late Timer _timer;
  final DuaService _duaService = DuaService();

  Map<String, String>? todaysDua;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    
    _loadDua();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadDua() async {
    final dua = await _duaService.getTodaysDua();
    if (mounted) {
      setState(() {
        todaysDua = dua;
        isLoading = false;
      });
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute$period';
  }

  String _formatDate(DateTime dt) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return 'RAMADAN 11, 1447 - ${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || todaysDua == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A2A5E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D3B8C), Color(0xFF051840), Color(0xFF0A2A5E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left side - Hadith content
                Expanded(
                  flex: 3,
                  child: _buildHadithContent(),
                ),
                
                const SizedBox(width: 40),
                
                // Right side - Info panel
                Expanded(
                  flex: 2,
                  child: _buildInfoPanel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHadithContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'DUA OF THE DAY',
            style: TextStyle(
              color: const Color(0xFF0A2A5E).withOpacity(0.6),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Dua text
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                todaysDua!['text']!,
                style: const TextStyle(
                  color: Color(0xFF1a1a2e),
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Source
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2A5E).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              todaysDua!['source']!,
              style: TextStyle(
                color: const Color(0xFF0A2A5E).withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top section - Logo and date
        Column(
          children: [
            // QR Code
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/qr_code.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.qr_code_2,
                        size: 120,
                        color: Colors.black54,
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Organization name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Islamic Society of Denton',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Date
            Text(
              _formatDate(_now),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        
        // Bottom section - Time and next prayer
        Column(
          children: [
            // Current time
            Text(
              _formatTime(_now),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w200,
                letterSpacing: -1,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Next prayer info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'NEXT IQAMAH IN',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '3HRS 3MIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Sunrise and Sunset
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sunInfo('☀️', 'SUNRISE', '6:58 AM'),
                _sunInfo('🌅', 'SUNSET', '6:25 PM'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _sunInfo(String icon, String label, String time) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
