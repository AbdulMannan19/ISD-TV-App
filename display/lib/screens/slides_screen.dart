import 'package:flutter/material.dart';

class SlidesScreen extends StatelessWidget {
  final Map<String, dynamic> slide;

  const SlidesScreen({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    final imageUrl = slide['image_url'] as String;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFF0A2A5E),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D3B8C), Color(0xFF051840), Color(0xFF0A2A5E)],
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.broken_image,
                size: 64,
                color: Colors.white54,
              ),
            ),
          );
        },
      ),
    );
  }
}
