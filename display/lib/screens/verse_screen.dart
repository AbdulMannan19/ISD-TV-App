import 'package:flutter/material.dart';
import '../services/verse_service.dart';
import 'content_screen.dart';

class VerseScreen extends StatelessWidget {
  const VerseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentScreen(
      title: 'VERSE OF THE DAY',
      fetchContent: () => VerseService().getTodaysVerse(),
    );
  }
}
