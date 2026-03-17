import 'package:flutter/material.dart';
import '../services/daily_content_service.dart';
import 'content_screen.dart';

class HadithScreen extends StatelessWidget {
  const HadithScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentScreen(
      title: 'HADITH OF THE DAY',
      fetchContent: () => DailyContentService(
        tableName: 'hadiths',
        fallback: {'text': 'The best among you are those who have the best manners and character.', 'source': 'Sahih Bukhari'},
      ).getTodaysContent(),
    );
  }
}
