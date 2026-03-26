import 'package:flutter/material.dart';
import '../services/shared_data.dart';
import 'content_screen.dart';

class HadithScreen extends StatelessWidget {
  const HadithScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentScreen(
      title: 'HADITH OF THE DAY',
      fetchContent: () async => SharedData.instance.currentHadith,
      contentTextColor: const Color(0xFF1B6B7D), // teal
    );
  }
}
