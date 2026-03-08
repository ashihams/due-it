import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DueBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const DueBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () => onTap(0),
                icon: Icon(
                  Icons.home_rounded,
                  color: currentIndex == 0 ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              IconButton(
                onPressed: () => onTap(1),
                icon: Icon(
                  Icons.calendar_month_rounded,
                  color: currentIndex == 1 ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 40),
              IconButton(
                onPressed: () => onTap(3),
                icon: Icon(
                  Icons.pie_chart_rounded,
                  color: currentIndex == 3 ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              IconButton(
                onPressed: () => onTap(4),
                icon: Icon(
                  Icons.person_rounded,
                  color: currentIndex == 4 ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
