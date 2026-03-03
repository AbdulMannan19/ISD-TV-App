import 'package:flutter/material.dart';

/// Test overlay with navigation arrows - REMOVE IN PRODUCTION
class TestControls extends StatelessWidget {
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const TestControls({
    super.key,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Left arrow
        Positioned(
          left: 20,
          top: 0,
          bottom: 0,
          child: Center(
            child: _buildArrowButton(
              icon: Icons.arrow_back_ios,
              onTap: onPrevious,
            ),
          ),
        ),
        
        // Right arrow
        Positioned(
          right: 20,
          top: 0,
          bottom: 0,
          child: Center(
            child: _buildArrowButton(
              icon: Icons.arrow_forward_ios,
              onTap: onNext,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArrowButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
