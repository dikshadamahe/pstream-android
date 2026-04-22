import 'package:flutter/material.dart';
import 'package:pstream_android/config/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(title: const Text('History')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.x6),
            child: Text(
              'History screen is planned for V1.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
