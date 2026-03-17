import 'package:flutter/material.dart';
import '../services/daily_content_service.dart';
import 'content_screen.dart';

class DuaScreen extends StatelessWidget {
  const DuaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentScreen(
      title: 'DUA OF THE DAY',
      fetchContent: () => DailyContentService(
        tableName: 'duas',
        fallback: {'text': 'Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.', 'source': 'Quran 2:201'},
      ).getTodaysContent(),
    );
  }
}
