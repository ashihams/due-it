import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class DateChip extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final VoidCallback onClick;

  const DateChip({
    super.key,
    required this.date,
    required this.isSelected,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    // Weekday in dart is 1-7 (1=Mon, 7=Sun). Weekday in JS is 0-6 (0=Sun, 6=Sat)
    final dayName = days[date.weekday % 7];

    return GestureDetector(
      onTap: onClick,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isToday ? Colors.white.withAlpha(128) : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : (isToday
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.white.withAlpha(77),
                        blurRadius: 0,
                      )
                    ]
                  : []),
        ),
        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayName,
                style: AppText.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white.withAlpha(230)
                      : (isToday
                          ? AppColors.foreground
                          : AppColors.mutedForeground),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${date.day}",
                style: AppText.bodyBold.copyWith(
                  fontSize: 18,
                  height: 1.0,
                  color: isSelected ? Colors.white : AppColors.foreground,
                ),
              ),
              if (isToday && !isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
