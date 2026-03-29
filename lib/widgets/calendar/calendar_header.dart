import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 12),
      child: Row(
        children: [
          Text(
            "Calendar",
            style: AppText.heading2.copyWith(
              color: AppColors.foreground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

