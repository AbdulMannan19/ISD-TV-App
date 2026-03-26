import 'package:flutter/material.dart';
import '../services/shared_data.dart';
import 'content_screen.dart';

class VerseScreen extends StatelessWidget {
  const VerseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentScreen(
      title: 'VERSE OF THE DAY',
      fetchContent: () async => SharedData.instance.currentVerse,
      contentTextColor: const Color(0xFF8B6914), // golden/beige
    );
  }
}
