import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/due_task.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class TaskDetailScreen extends StatelessWidget {
  final DueTask task;

  const TaskDetailScreen({super.key, required this.task});

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final fullTask = context.watch<TaskProvider>().getTask(task.id);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8FAFF), Color(0xFFFFFFFF)],
            ),
          ),
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Due Detail',
                          style: AppText.heading2.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18), // balance the back button
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    // Title + group badge
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: AppText.heading2.copyWith(
                                    color: AppColors.foreground,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _GroupBadge(group: task.group),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 13,
                                color: AppColors.mutedForeground,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Due ${_formatDate(task.endDate)}',
                                style: AppText.caption.copyWith(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                              if (task.durationMinutes != null) ...[
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.access_time,
                                  size: 13,
                                  color: AppColors.mutedForeground,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${task.durationMinutes} min',
                                  style: AppText.caption.copyWith(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Description
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _SectionCard(
                        label: 'Description',
                        child: Text(
                          task.description,
                          style: AppText.body.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],

                    // AI schedule summary
                    if (fullTask?.ai != null && fullTask!.ai!.generated) ...[
                      const SizedBox(height: 14),
                      _SectionCard(
                        label: 'AI Plan',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PlanRow(
                              icon: Icons.timer_outlined,
                              label: 'Estimated',
                              value: '${fullTask.ai!.estimatedMinutes} min total',
                            ),
                            const SizedBox(height: 8),
                            _PlanRow(
                              icon: Icons.today_outlined,
                              label: 'Daily',
                              value: '${fullTask.ai!.dailyRequiredMinutes} min / day',
                            ),
                            if (fullTask.ai!.remainingMinutes > 0) ...[
                              const SizedBox(height: 8),
                              _PlanRow(
                                icon: Icons.hourglass_bottom_outlined,
                                label: 'Remaining',
                                value: '${fullTask.ai!.remainingMinutes} min',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Internal widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final String? label;

  const _SectionCard({required this.child, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: AppText.caption.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _GroupBadge extends StatelessWidget {
  final String group;

  const _GroupBadge({required this.group});

  Color _color() {
    switch (group) {
      case 'Study':
        return const Color(0xFF2D9BD2);
      case 'Personal':
        return const Color(0xFF39AC73);
      default:
        return const Color(0xFFA679D2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        group,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PlanRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.mutedForeground),
        const SizedBox(width: 6),
        Text(
          '$label  ',
          style: AppText.caption.copyWith(fontSize: 12, color: AppColors.mutedForeground),
        ),
        Text(
          value,
          style: AppText.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
