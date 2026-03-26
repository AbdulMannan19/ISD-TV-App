import 'package:flutter/material.dart';
import 'content_screen.dart';

class SplitSlideScreen extends StatelessWidget {
  final Map<String, dynamic> slide;

  const SplitSlideScreen({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    final imageUrl = slide['image_url'] as String;

    return ContentScreen(
      title: '',
      customContent: (_) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}
