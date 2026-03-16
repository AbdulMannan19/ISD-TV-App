import 'package:flutter/material.dart';
import '../services/dua_service.dart';
import 'content_screen.dart';

class DuaScreen extends StatelessWidget {
  const DuaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentScreen(
      title: 'DUA OF THE DAY',
      fetchContent: () => DuaService().getTodaysDua(),
    );
  }
}
