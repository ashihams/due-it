import 'package:flutter/material.dart';
import '../../models/due_task.dart';
import '../../models/ai_schedule_model.dart';
import '../../theme/app_colors.dart';
import 'calendar_task_block.dart';

const double hourHeight = 80.0;
/// Working window 09:00–21:00 (12 h) — blocks stay within via scheduler cap (6 h work / day).
const int _kCalendarStartHourDefault = 9;
const int _kCalendarEndHourDefault = 21;

/// Short-duration blocks would get a tiny height (e.g. under 20px) and overflow [CalendarTaskBlock] padding + text.
const double minTaskBlockHeight = 52.0;

class CalendarDayView extends StatelessWidget {
  final DateTime selectedDate;
  final List<CalendarScheduleEntry> tasks;
  final int startHour;
  final int endHour;

  const CalendarDayView({
    super.key,
    required this.selectedDate,
    required this.tasks,
    this.startHour = _kCalendarStartHourDefault,
    this.endHour = _kCalendarEndHourDefault,
  });

  @override
  Widget build(BuildContext context) {
    // React constants: HOUR_HEIGHT = 80, START_HOUR = 7, END_HOUR = 18
    final hours = List.generate(endHour - startHour + 1, (i) => startHour + i);
    final isToday = selectedDate.year == DateTime.now().year &&
        selectedDate.month == DateTime.now().month &&
        selectedDate.day == DateTime.now().day;

    final now = DateTime.now();
    final currentHourDecimal = now.hour + (now.minute / 60.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Stack(
        children: [
          // Total height container
          SizedBox(
            height: hours.length * hourHeight,
            width: double.infinity,
          ),

          // Hour lines
          for (final hour in hours)
            Positioned(
              top: (hour - startHour) * hourHeight,
              left: 0,
              right: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      "${hour.toString().padLeft(2, '0')}:00",
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),

          // Current time indicator (Red line)
          if (isToday &&
              currentHourDecimal >= startHour &&
              currentHourDecimal <= endHour)
            Positioned(
              top: (currentHourDecimal - startHour) * hourHeight,
              left: 60, // Align with timeline start
              right: 0,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Expanded(
                    child: Divider(
                      height: 2,
                      thickness: 2,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),

          // Task Blocks
          ..._buildTaskBlocks(tasks),
        ],
      ),
    );
  }

  List<Positioned> _buildTaskBlocks(List<CalendarScheduleEntry> tasks) {
    return tasks.map((entry) {
      final double startH = entry.blockStartHour;
      final int durationMins = entry.blockDurationMinutes;
      final double durationHours = durationMins / 60.0;

      final int startHInt = startH.floor();
      final int startMInt = ((startH - startHInt) * 60).round();
      final int startMinutes = startHInt * 60 + startMInt;
      final int timelineStartMinutes = startHour * 60;

      double top = ((startMinutes - timelineStartMinutes) / 60.0) * hourHeight;
      double height = durationHours * hourHeight;

      top += 4;
      height -= 8;

      if (top < 0 || top > (endHour - startHour) * hourHeight) {
        return const Positioned(child: SizedBox.shrink());
      }

      if (height <= 0) {
        return const Positioned(child: SizedBox.shrink());
      }
      if (height < minTaskBlockHeight) {
        height = minTaskBlockHeight;
      }

      return Positioned(
        key: ValueKey(entry.blockId),
        top: top,
        left: 60,
        right: 12,
        height: height,
        child: CalendarTaskBlock(
          key: ValueKey(entry.blockId),
          task: entry.task,
          virtualStartHour: startH,
          durationMinutes: durationMins,
          schedule: entry.schedule,
        ),
      );
    }).toList();
  }
}

class CalendarScheduleEntry {
  final DueTask task;
  final AiDaySchedule schedule;
  final int blockDurationMinutes;
  final double blockStartHour;
  final String blockId;

  const CalendarScheduleEntry({
    required this.task,
    required this.schedule,
    this.blockDurationMinutes = 120,
    this.blockStartHour = 9.0,
    required this.blockId,
  });
}
