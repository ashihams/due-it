import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';

class HeatmapGridWidget extends StatefulWidget {
  const HeatmapGridWidget({super.key});

  @override
  State<HeatmapGridWidget> createState() => _HeatmapGridWidgetState();
}

class _HeatmapGridWidgetState extends State<HeatmapGridWidget> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final data = provider.heatmapForMonth(_year, _month);
    final daysInMonth = DateUtils.getDaysInMonth(_year, _month);
    final firstWeekday = DateTime(_year, _month, 1).weekday; // 1=Mon, 7=Sun
    final leadingEmpties = firstWeekday - 1;
    final totalCells = leadingEmpties + daysInMonth;

    Color colorForMinutes(int minutes) {
      if (minutes == 0) return const Color(0xFFF0F0F5);
      if (minutes < 60) return const Color(0xFFD4BBFF);
      if (minutes < 120) return const Color(0xFFAB82FF);
      if (minutes < 180) return const Color(0xFF7C4DFF);
      return const Color(0xFF5B21B6);
    }

    final dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final now = DateTime.now();
    final bool isCurrentMonth =
        (now.year == _year && now.month == _month);
    final monthNames = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withAlpha(10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 2),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "AI Productivity Heatmap",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text(
            "Your daily productivity patterns analyzed by AI",
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 16),

          // Month Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _prevMonth,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EEF5), // hsl(270,15%,95%)
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chevron_left_rounded, size: 16, color: Colors.black54),
                ),
              ),
              Text(
                "${monthNames[_month - 1]} $_year",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              GestureDetector(
                onTap: _nextMonth,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCurrentMonth ? const Color(0xFFF4F3F5) : const Color(0xFFF1EEF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isCurrentMonth ? Colors.black26 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Day Headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dayLabels.map((d) => 
              SizedBox(
                width: 36,
                child: Center(
                  child: Text(d, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black54)),
                ),
              )
            ).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < leadingEmpties) {
                return const SizedBox.shrink();
              }
              final day = index - leadingEmpties + 1;
              final key =
                  '$_year-${_month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final minutes = data[key] ?? 0;
              final now = DateTime.now();
              final isToday = now.year == _year &&
                  now.month == _month &&
                  now.day == day;

              return Container(
                decoration: BoxDecoration(
                  color: colorForMinutes(minutes),
                  borderRadius: BorderRadius.circular(6),
                  border: isToday
                      ? Border.all(color: const Color(0xFF7C4DFF), width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    "$day",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: minutes >= 120 ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text("Less", style: TextStyle(fontSize: 9, color: Colors.black54)),
              const SizedBox(width: 4),
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4BBFF),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFAB82FF),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B21B6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              const Text("More", style: TextStyle(fontSize: 9, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}

class MathHelper {
  // Rough math sin approximation for JS style pseudo seeded predictability.
  // Not cryptographic. Just identical to Math.sin in generic terms.
  static double sin(double v) {
    return (v % 3.14159) / 3.14159; // Simplified placeholder
  }
}
