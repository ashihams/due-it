import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class DueCard extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final bool isCompleted;
  final VoidCallback? onTap;

  const DueCard({
    super.key,
    required this.title,
    required this.time,
    this.icon = Icons.work_outline_rounded,
    this.iconColor = AppColors.primary,
    this.backgroundColor = AppColors.primary,
    this.isCompleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isCompleted
            ? LinearGradient(
                colors: [
                  AppColors.completedBackground,
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.white,
                  AppColors.accent.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? AppColors.primary.withOpacity(0.08)
                : AppColors.primary.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: isCompleted
                  ? LinearGradient(
                      colors: [
                        AppColors.completedCheck.withOpacity(0.2),
                        AppColors.completedCheck.withOpacity(0.1),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        backgroundColor.withOpacity(0.15),
                        AppColors.secondary.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isCompleted ? AppColors.completedCheck : iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isCompleted
                        ? AppColors.completedText
                        : AppColors.textPrimary,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppColors.completedText,
                    decorationThickness: 1.5,
                  ),
                  child: Text(title),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    color: isCompleted
                        ? AppColors.textMuted.withOpacity(0.7)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.completedCheck.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 24,
                    color: isCompleted
                        ? AppColors.completedCheck
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
