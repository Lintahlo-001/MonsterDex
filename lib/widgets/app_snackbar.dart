import 'package:flutter/material.dart';
import '../constants/theme.dart';

class AppSnackbar {
  static void success(BuildContext context, String message) {
    _show(context, message, AppTheme.success, Icons.check_circle_outline);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, AppTheme.danger, Icons.error_outline);
  }

  static void gotcha(BuildContext context, String monsterName) {
    _show(
      context,
      '⚡ Gotcha! $monsterName was caught!',
      AppTheme.accentCyan,
      Icons.catching_pokemon,
      duration: const Duration(seconds: 3),
    );
  }

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgMid,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'ComicRelief',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}