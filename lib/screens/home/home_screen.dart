import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../add_due/add_due_screen.dart';
import '../../widgets/home/due_card.dart';
import '../../widgets/home/empty_state.dart';

/// True when today's slice should appear under "Completed" (task done or all today's steps done).
bool _entryDoneForHome(DailyScheduledTask entry) {
  if (entry.task.isDone) return true;
  final mts = entry.schedule.microtasks;
  if (mts.isEmpty) return false;
  return mts.every((m) => m.completed);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // One row per task (see TaskProvider.duesEntriesForDate) — not only tasks with a block today.
    final allTodayRows = provider.duesEntriesForDate(now);
    final activeToday =
        allTodayRows.where((e) => !_entryDoneForHome(e)).toList();
    final completedToday =
        allTodayRows.where((e) => _entryDoneForHome(e)).toList();

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Home",
                        style: AppText.heading2.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddDuePage(),
                        ),
                      );
                    },
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA5B4FC), Color(0xFFC7D2FE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA5B4FC).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: allTodayRows.isEmpty
                    ? const EmptyState()
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (activeToday.isNotEmpty) ...[
                            _HomeSectionHeader(
                              label: 'Active',
                              count: activeToday.length,
                              isCompletedSection: false,
                            ),
                            const SizedBox(height: 12),
                            ...activeToday.map(
                              (entry) => Padding(
                                key: ValueKey(entry.blockId),
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DueCard(
                                  task: entry.task,
                                  dateKey: dateKey,
                                  scheduleOverride: entry.schedule,
                                ),
                              ),
                            ),
                          ],
                          if (completedToday.isNotEmpty) ...[
                            if (activeToday.isNotEmpty)
                              const SizedBox(height: 24),
                            _HomeSectionHeader(
                              label: 'Completed',
                              count: completedToday.length,
                              isCompletedSection: true,
                            ),
                            const SizedBox(height: 12),
                            ...completedToday.map(
                              (entry) => Padding(
                                key: ValueKey(entry.blockId),
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DueCard(
                                  task: entry.task,
                                  dateKey: dateKey,
                                  scheduleOverride: entry.schedule,
                                ),
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

/// Matches due-it-delight: label + divider + count (primary vs success).
class _HomeSectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool isCompletedSection;

  const _HomeSectionHeader({
    required this.label,
    required this.count,
    required this.isCompletedSection,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppText.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedForeground,
            letterSpacing: 0.6,
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
          '$count',
          style: AppText.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isCompletedSection ? AppColors.success : AppColors.primary,
          ),
        ),
      ],
    );
  }
}
