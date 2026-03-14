import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          '$title — Coming Soon',
          style: const TextStyle(
            fontSize: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}