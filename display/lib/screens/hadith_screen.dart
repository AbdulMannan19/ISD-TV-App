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
      contentBgColor: const Color(0xFFF1F8F1),
      contentTextColor: const Color(0xFF1B5E20),
    );
  }
}

class Hadith2Screen extends StatelessWidget {
  const Hadith2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final h = SharedData.instance.currentHadith;
    return ContentScreen(
      title: 'HADITH OF THE DAY',
      fetchContent: () async => {
        'text': h['text2'] ?? '',
        'source': h['source2'] ?? '',
      },
      contentBgColor: const Color(0xFFF1F8F1),
      contentTextColor: const Color(0xFF1B5E20),
    );
  }
}
