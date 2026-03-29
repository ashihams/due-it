import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../models/ai_schedule_model.dart';
import '../../models/due_task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/calendar/calendar_widgets.dart';
import '../../widgets/home/due_card.dart';

bool _entryDoneForCalendarTask(DueTask task, AiDaySchedule schedule) {
  if (task.isDone) return true;
  final mts = schedule.microtasks;
  if (mts.isEmpty) return false;
  return mts.every((m) => m.completed);
}

class _BaseCalendarDayTask {
  final DueTask task;
  final AiDaySchedule schedule;
  final int durationMinutes;

  const _BaseCalendarDayTask({
    required this.task,
    required this.schedule,
    required this.durationMinutes,
  });
}

class _CalendarDayTask {
  final DueTask task;
  final AiDaySchedule schedule;
  final int durationMinutes;
  final double startHour;
  final String blockId;
  final String timeRangeLabel;

  const _CalendarDayTask({
    required this.task,
    required this.schedule,
    required this.durationMinutes,
    required this.startHour,
    required this.blockId,
    required this.timeRangeLabel,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final List<DateTime> dateList;
  late final ScrollController _scrollController;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();
    
    // Generate 90 days starting from 30 days ago to show history and future
    dateList = List.generate(90, (i) {
      return DateTime(today.year, today.month, today.day - 30 + i);
    });

    selectedIndex = dateList.indexWhere(
      (d) => d.year == today.year && d.month == today.month && d.day == today.day,
    );
    if (selectedIndex == -1) selectedIndex = 0;

    // Approximate width of DateChip + padding = 52 + 12 = 64
    // Calculate initial offset to keep today's chip somewhat centered/visible
    double initialOffset = (selectedIndex * 64.0) - 100.0;
    if (initialOffset < 0) initialOffset = 0;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime get selectedDate => dateList[selectedIndex];

  void _onDateSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  String _formatTimeAmPm(int hour24, int minute) {
    final h = hour24 % 24;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = (h % 12 == 0) ? 12 : (h % 12);
    final mm = minute.toString().padLeft(2, '0');
    return '$hour12:$mm $ampm';
  }

  String _formatTimeRangeAmPm(double startHour, int durationMinutes) {
    final startH = startHour.floor();
    final startM = ((startHour - startH) * 60).round();

    final endVirtualHour = startHour + (durationMinutes / 60.0);
    final endH = endVirtualHour.floor();
    final endM = ((endVirtualHour - endH) * 60).round();

    final int startMClamped = startM == 60 ? 0 : startM;
    final int startHClamped = startM == 60 ? startH + 1 : startH;

    final int endMClamped = endM == 60 ? 0 : endM;
    final int endHClamped = endM == 60 ? endH + 1 : endH;

    return '${_formatTimeAmPm(startHClamped, startMClamped)} — ${_formatTimeAmPm(endHClamped, endMClamped)}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final dateKey =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    // Build day entries directly from the Firestore-written ai.schedule[*] for this date.
    // This fixes:
    // - bug: only 2–3 tasks show (no longer using the capped global scheduler)
    // - bug: tasks pile on one day (now keyed strictly by ai.schedule[*].date)
    //
    // Time blocking is UI-only: each task's microtasks are allocated equal-duration
    // slices derived from (estimatedMinutes / totalMicrotasks), then stacked from 9:00 AM.
    const int calendarStartHour = 9;
    final baseDayTasks = <_BaseCalendarDayTask>[];

    for (final due in provider.dues) {
      final taskModel = provider.getTask(due.id);
      if (taskModel == null) continue;

      final aiDay = taskModel.aiScheduleData?.scheduleForDateKey(dateKey);
      if (aiDay == null) continue;
      if (aiDay.microtasks.isEmpty) continue; // no visible schedule content for this day

      final totalMicrotasks = taskModel.totalMicrotasks;
      final estimatedMinutes = taskModel.estimatedMinutes ??
          taskModel.ai?.estimatedMinutes ??
          due.durationMinutes ??
          60;

      final double minutesPerMicrotask =
          (totalMicrotasks > 0) ? (estimatedMinutes / totalMicrotasks) : 0.0;

      final int durationMinutes = math.max(
        1,
        (minutesPerMicrotask * aiDay.microtasks.length).round(),
      );

      baseDayTasks.add(_BaseCalendarDayTask(
        task: due,
        schedule: aiDay,
        durationMinutes: durationMinutes,
      ));
    }

    baseDayTasks.sort((a, b) {
      final byDate = a.task.endDate.compareTo(b.task.endDate);
      if (byDate != 0) return byDate;
      return a.task.id.compareTo(b.task.id);
    });

    double cursorHour = calendarStartHour.toDouble();
    final dayTasks = <_CalendarDayTask>[];
    for (final t in baseDayTasks) {
      final startHour = cursorHour;
      final durationMinutes = t.durationMinutes;
      final endHour = startHour + (durationMinutes / 60.0);
      final timeRangeLabel = _formatTimeRangeAmPm(startHour, durationMinutes);

      dayTasks.add(_CalendarDayTask(
        task: t.task,
        schedule: t.schedule,
        durationMinutes: durationMinutes,
        startHour: startHour,
        blockId: '${t.task.id}_$dateKey',
        timeRangeLabel: timeRangeLabel,
      ));

      cursorHour = endHour;
    }

    final int totalDailyMinutes =
        dayTasks.fold<int>(0, (sum, t) => sum + t.durationMinutes);
    final bool overEightHours = totalDailyMinutes > 8 * 60;

    final int dayEndHour = math.max(
      21,
      calendarStartHour + ((totalDailyMinutes / 60.0).ceil()),
    );

    final scheduled = dayTasks
        .map((entry) => CalendarScheduleEntry(
              task: entry.task,
              schedule: entry.schedule,
              blockDurationMinutes: entry.durationMinutes,
              blockStartHour: entry.startHour,
              blockId: entry.blockId,
            ))
        .toList();

    final listActive = dayTasks
        .where((t) => !_entryDoneForCalendarTask(t.task, t.schedule))
        .toList();
    final listCompleted = dayTasks
        .where((t) => _entryDoneForCalendarTask(t.task, t.schedule))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header (Replaces original top bar with React styled header)
            const CalendarHeader(),
            
            // Week day selector (90-day scrollable)
            SizedBox(
              height: 90,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: dateList.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: DateChip(
                      date: dateList[i],
                      isSelected: i == selectedIndex,
                      onClick: () => _onDateSelected(i),
                    ),
                  );
                },
              ),
            ),

            // Divider
            const Divider(height: 1, thickness: 1, color: AppColors.border),

            // Full-width timeline + scrollable summary (avoids narrow-column overflow).
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (overEightHours)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Daily workload exceeds 8h',
                              style: AppText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      height: 560,
                      child: CalendarDayView(
                        selectedDate: selectedDate,
                        tasks: scheduled,
                        endHour: dayEndHour,
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: AppColors.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (listActive.isNotEmpty) ...[
                            Text(
                              'TASKS (${listActive.length})',
                              style: AppText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...listActive.map(
                              (entry) => Padding(
                                key: ValueKey(entry.blockId),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: DueCard(
                                  task: entry.task,
                                  dateKey: dateKey,
                                  scheduleOverride: entry.schedule,
                                  timeRangeLabel: entry.timeRangeLabel,
                                ),
                              ),
                            ),
                          ],
                          if (listCompleted.isNotEmpty) ...[
                            if (listActive.isNotEmpty) const SizedBox(height: 16),
                            Text(
                              'DONE (${listCompleted.length})',
                              style: AppText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...listCompleted.map(
                              (entry) => Padding(
                                key: ValueKey(entry.blockId),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: DueCard(
                                  task: entry.task,
                                  dateKey: dateKey,
                                  scheduleOverride: entry.schedule,
                                  timeRangeLabel: entry.timeRangeLabel,
                                ),
                              ),
                            ),
                          ],
                          if (listActive.isEmpty && listCompleted.isEmpty)
                            Text(
                              'No tasks',
                              style: AppText.body.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

