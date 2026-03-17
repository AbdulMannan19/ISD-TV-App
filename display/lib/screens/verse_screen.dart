import 'package:flutter/material.dart';
import '../services/daily_content_service.dart';
import 'content_screen.dart';

class VerseScreen extends StatelessWidget {
  const VerseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentScreen(
      title: 'VERSE OF THE DAY',
      fetchContent: () => DailyContentService(
        tableName: 'verses',
        fallback: {'text': 'Indeed, with hardship [will be] ease.', 'source': 'Quran 94:6'},
      ).getTodaysContent(),
    );
  }
}
