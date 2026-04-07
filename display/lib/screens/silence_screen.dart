import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class SilenceScreen extends StatelessWidget {
  const SilenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SILENCE PLEASE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF9CA3AF),
                    fontSize: isMobile ? 36 : 72,
                    fontWeight: FontWeight.w300,
                    letterSpacing: isMobile ? 4 : 8,
                  ),
                ),
                SizedBox(height: isMobile ? 40 : 80),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIcon(Icons.phone_disabled, isMobile ? 48 : 80),
                    SizedBox(width: isMobile ? 40 : 100),
                    _buildIcon(Icons.voice_over_off, isMobile ? 48 : 80),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: isMobile ? 20 : 40,
            right: isMobile ? 20 : 40,
            child: _buildMosqueLogo(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(IconData icon, double size) {
    return Icon(
      icon,
      size: size,
      color: const Color(0xFF4B5563),
    );
  }

  Widget _buildMosqueLogo(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF374151), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.mosque,
        size: isMobile ? 24 : 32,
        color: const Color(0xFF6B7280),
      ),
    );
  }
}
