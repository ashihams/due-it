import 'package:flutter/material.dart';
import '../../models/due_task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import 'due_card.dart';

class TaskSection extends StatelessWidget {
  final String title;
  final List<DueTask> tasks;
  final bool isCompleted;

  const TaskSection({
    super.key,
    required this.title,
    required this.tasks,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: EdgeInsets.only(top: isCompleted ? 24.0 : 0.0, bottom: 12.0),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: AppText.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.border,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${tasks.length}",
                style: AppText.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        // Tasks List
        ...tasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: DueCard(task: task),
            )),
      ],
    );
  }
}
