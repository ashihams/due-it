import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/due_task.dart';
import '../../models/ai_schedule_model.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../screens/tasks/task_detail_screen.dart';

class DueCard extends StatefulWidget {
  final DueTask task;
  /// YYYY-MM-DD for which day’s schedule to show (defaults to today).
  final String? dateKey;
  /// When set (e.g. from Home), use this day’s AI schedule instead of resolving again.
  final AiDaySchedule? scheduleOverride;
  /// When set (e.g. from Calendar), show an explicit time range like `9:00 AM — 10:30 AM`.
  final String? timeRangeLabel;

  const DueCard({
    super.key,
    required this.task,
    this.dateKey,
    this.scheduleOverride,
    this.timeRangeLabel,
  });

  @override
  State<DueCard> createState() => _DueCardState();
}

class _DueCardState extends State<DueCard> {
  bool _expanded = false;
  bool _isHovered = false;
  bool _isPressed = false;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final plan = provider.todaysBalancedPlan(DateTime.now());

    int? minutesToday;
    for (final p in plan) {
      if (p.dueId == widget.task.id) {
        minutesToday = p.minutesPlannedToday;
        break;
      }
    }

    final isDone = widget.task.isDone;

    final taskData = provider.getTask(widget.task.id);
    final ai = taskData?.ai;
    final scheduleData = taskData?.aiScheduleData;
    final dateKey = widget.dateKey ?? _todayKey();
    final todaySchedule =
        widget.scheduleOverride ?? scheduleData?.scheduleForDateKey(dateKey);

    String displayTitle = widget.task.title;
    List<dynamic> allSteps = [];
    int totalSteps = 0;
    int completedSteps = 0;
    String? microtaskDateKey;

    // Prefer Firestore ai.schedule (daily subtask + microtasks)
    if (todaySchedule != null && (scheduleData?.generated == true)) {
      microtaskDateKey = todaySchedule.date;
      if (todaySchedule.subtask.trim().isNotEmpty) {
        displayTitle = todaySchedule.subtask;
      }
      allSteps = todaySchedule.microtasks;
      totalSteps = todaySchedule.microtasks.length;
      completedSteps =
          todaySchedule.microtasks.where((m) => m.completed).length;
    } else if (ai != null) {
      final subtasks = ai.subtasks;
      totalSteps = subtasks.length;
      completedSteps = subtasks.where((s) => s.completed == true).length;
      allSteps = subtasks;

      final today = _onlyDate(DateTime.now());
      final todaysSubs = subtasks.where((s) {
        final sd = s.scheduledDate;
        return sd != null && _onlyDate(sd) == today && s.completed == false;
      }).toList();

      if (todaysSubs.isNotEmpty) {
        displayTitle = todaysSubs.first.text;
      } else if (subtasks.isNotEmpty) {
        final incomplete = subtasks.where((s) => s.completed == false).toList();
        if (incomplete.isNotEmpty) {
          displayTitle = incomplete.first.text;
        } else {
          displayTitle = subtasks.last.text;
        }
      } else if (ai.actionSteps.isNotEmpty) {
        displayTitle = ai.actionSteps.first;
      }
    }

    DateTime? scheduleDate;
    final dkParts = dateKey.split('-');
    if (dkParts.length == 3) {
      try {
        scheduleDate = DateTime(
          int.parse(dkParts[0]),
          int.parse(dkParts[1]),
          int.parse(dkParts[2]),
        );
      } catch (_) {}
    }
    final allocated = scheduleDate != null
        ? provider.minutesAllocatedOnDate(widget.task.id, scheduleDate)
        : 0;

    final String timeLabel;
    if (widget.timeRangeLabel != null && widget.timeRangeLabel!.trim().isNotEmpty) {
      timeLabel = widget.timeRangeLabel!.trim();
    } else if (scheduleDate != null && allocated > 0) {
      timeLabel = "$allocated min scheduled";
    } else if (ai != null && ai.dailyRequiredMinutes > 0) {
      timeLabel = "${ai.dailyRequiredMinutes} min today";
    } else if (minutesToday != null) {
      timeLabel = "$minutesToday min today";
    } else if (widget.task.durationMinutes != null) {
      timeLabel = "${widget.task.durationMinutes} min";
    } else {
      timeLabel = "AI estimating...";
    }

    final bool dailyDone = totalSteps > 0 && completedSteps == totalSteps;
    final bool visuallyComplete = isDone || dailyDone;

    // Group UI mapping
    final String groupName = widget.task.group;
    final GroupColors theme = groupThemeColors[groupName] ?? groupThemeColors["Work"]!;
    
    IconData groupIcon = Icons.work;
    if (groupName == "Study") groupIcon = Icons.menu_book;
    if (groupName == "Personal") groupIcon = Icons.favorite;

    final double progress = totalSteps > 0 ? (completedSteps / totalSteps) : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(task: widget.task),
            ),
          );
        },
        child: AnimatedScale(
          scale: _isHovered && !_isPressed ? 1.01 : (_isPressed ? 0.99 : 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visuallyComplete ? 0.6 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              margin: const EdgeInsets.only(bottom: 0),
              decoration: BoxDecoration(
                color: theme.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border(left: BorderSide(color: theme.border, width: 3)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.iconBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Icon(groupIcon, size: 18, color: theme.border),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 300),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: visuallyComplete ? AppColors.mutedForeground : AppColors.foreground,
                                        decoration: visuallyComplete ? TextDecoration.lineThrough : TextDecoration.none,
                                        fontFamily: 'Poppins',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      child: Text(displayTitle),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _CustomCheckbox(
                                    isDone: dailyDone || isDone,
                                    theme: theme,
                                    onTap: () async {
                                      if (microtaskDateKey == null ||
                                          allSteps.isEmpty) {
                                        await provider.toggleDone(widget.task.id);
                                        return;
                                      }
                                      final targetCompleted = !dailyDone;
                                      for (int idx = 0; idx < allSteps.length; idx++) {
                                        final step = allSteps[idx];
                                        if (step is AiMicrotask &&
                                            step.completed != targetCompleted) {
                                          await provider.toggleMicrotask(
                                            taskId: widget.task.id,
                                            date: microtaskDateKey,
                                            index: idx,
                                            completed: targetCompleted,
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 11, color: AppColors.mutedForeground),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeLabel,
                                    style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                  ),
                                  const SizedBox(width: 8),
                                  _Dot(),
                                  const SizedBox(width: 8),
                                  Text(
                                    groupName,
                                    style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                  ),
                                  if (totalSteps > 0) ...[
                                    const SizedBox(width: 8),
                                    _Dot(),
                                    const SizedBox(width: 8),
                                    Text(
                                      "$completedSteps/$totalSteps",
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
                                    ),
                                  ]
                                ],
                              ),
                              if (totalSteps > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: AppColors.muted,
                                      color: theme.progress,
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (allSteps.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _toggleExpanded,
                        child: Row(
                          children: [
                            const SizedBox(width: 56), 
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.mutedForeground),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${_expanded ? 'Hide' : 'Show'} steps",
                              style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: ClipRect(
                          child: _expanded
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8, left: 56),
                                  child: Column(
                                    children: allSteps.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final step = entry.value;
                                      return _SubtaskItem(
                                        step: step,
                                        theme: theme,
                                        onToggle: () {
                                          if (microtaskDateKey != null &&
                                              step is AiMicrotask) {
                                            provider.toggleMicrotask(
                                              taskId: widget.task.id,
                                              date: microtaskDateKey,
                                              index: idx,
                                              completed: !step.completed,
                                            );
                                          } else {
                                            provider.toggleSubtask(
                                              widget.task.id,
                                              idx,
                                            );
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ),
                                )
                              : const SizedBox(width: double.infinity, height: 0),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4, height: 4,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.mutedForeground.withAlpha(77)),
    );
  }
}

class _CustomCheckbox extends StatelessWidget {
  final bool isDone;
  final GroupColors theme;
  final VoidCallback onTap;

  const _CustomCheckbox({required this.isDone, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: isDone ? theme.bgCard : Colors.transparent,
          border: Border.all(
            color: isDone ? theme.border : AppColors.mutedForeground.withAlpha(77),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: isDone
              ? Icon(Icons.check, size: 14, color: theme.border, key: const ValueKey('checked'))
              : const SizedBox.shrink(key: ValueKey('unchecked')),
        ),
      ),
    );
  }
}

class _SubtaskItem extends StatelessWidget {
  final dynamic step;
  final GroupColors theme;
  final VoidCallback onToggle;

  const _SubtaskItem({required this.step, required this.theme, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final bool done = step.completed == true;
    final String title = step is AiMicrotask
        ? step.title
        : (step.text ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onToggle,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: done ? theme.bgCard : Colors.transparent,
                border: Border.all(
                  color: done ? theme.border : AppColors.mutedForeground.withAlpha(64),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: done
                    ? Icon(Icons.check, size: 10, color: theme.border, key: const ValueKey('c'))
                    : const SizedBox.shrink(key: ValueKey('u')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 12,
                  color: done ? AppColors.mutedForeground : AppColors.foreground,
                  decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                ),
                child: Text(title),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
