import 'package:flutter/material.dart';
import '../services/hadith_service.dart';
import 'content_screen.dart';

class HadithScreen extends StatelessWidget {
  const HadithScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentScreen(
      title: 'HADITH OF THE DAY',
      fetchContent: () => HadithService().getTodaysHadith(),
    );
  }
}
