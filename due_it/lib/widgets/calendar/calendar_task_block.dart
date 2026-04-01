import 'package:flutter/material.dart';
import '../../models/due_task.dart';
import '../../models/ai_schedule_model.dart';
import '../../theme/app_colors.dart';

class CalendarTaskBlock extends StatefulWidget {
  final DueTask task;
  final double virtualStartHour;
  final int durationMinutes;
  final AiDaySchedule schedule;

  const CalendarTaskBlock({
    super.key,
    required this.task,
    required this.virtualStartHour,
    required this.durationMinutes,
    required this.schedule,
  });

  @override
  State<CalendarTaskBlock> createState() => _CalendarTaskBlockState();
}

class _CalendarTaskBlockState extends State<CalendarTaskBlock> {
  bool _isHovered = false;
  bool _isPressed = false;

  String _formatTimeAmPm(int hour24, int minute) {
    final h = hour24 % 24; // allow values like 24:xx to roll over
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = (h % 12 == 0) ? 12 : (h % 12);
    final mm = minute.toString().padLeft(2, '0');
    return '$hour12:$mm $ampm';
  }

  @override
  Widget build(BuildContext context) {
    // Determine Theme via Group mapped in AppColors
    final groupName = widget.task.group;
    final GroupColors theme = groupThemeColors[groupName] ?? groupThemeColors["Work"]!;

    // Resolve time strings
    final startH = widget.virtualStartHour.floor();
    final startM = ((widget.virtualStartHour - startH) * 60).round();
    final int startMClamped = startM == 60 ? 0 : startM;
    final int startHClamped = startM == 60 ? startH + 1 : startH;

    final endVirtualHour = widget.virtualStartHour + (widget.durationMinutes / 60.0);
    final endH = endVirtualHour.floor();
    final endM = ((endVirtualHour - endH) * 60).round();
    final int endMClamped = endM == 60 ? 0 : endM;
    final int endHClamped = endM == 60 ? endH + 1 : endH;

    final timeText =
        "${_formatTimeAmPm(startHClamped, startMClamped)} — ${_formatTimeAmPm(endHClamped, endMClamped)}";

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isHovered && !_isPressed ? 1.01 : (_isPressed ? 0.98 : 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Container(
              key: ValueKey(widget.task.id),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.bgCard, // full tinted background like Home cards
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color: theme.border,
                    width: 4,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                  if (_isHovered)
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final pad = h < 40
                      ? 4.0
                      : h < 56
                          ? 8.0
                          : 16.0;
                  final timeSize = h < 36 ? 9.0 : 11.0;
                  final titleSize = h < 36 ? 10.0 : 13.0;
                  final gap = h < 32 ? 2.0 : 4.0;
                  return Padding(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          timeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: timeSize,
                            fontWeight: FontWeight.w600,
                            color: theme.border,
                          ),
                        ),
                        SizedBox(height: gap),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              widget.schedule.subtask,
                              maxLines: h < 40 ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
