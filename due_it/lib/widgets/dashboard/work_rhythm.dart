import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';

class WorkRhythm extends StatelessWidget {
  const WorkRhythm({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final rhythmData = provider.workRhythmData;
    
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    
    // Aggregate minutes by day of week from last 30 days
    final Map<int, double> minutesByWeekday = {};
    for (final entry in rhythmData) {
      final dateStr = entry['date'] as String;
      final minutes = entry['minutes'] as int;
      try {
        final parts = dateStr.split('-');
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        // DateTime.weekday: 1=Mon, 7=Sun. Map to 0=Mon, 6=Sun
        final weekday = (date.weekday - 1) % 7;
        minutesByWeekday[weekday] = (minutesByWeekday[weekday] ?? 0.0) + minutes;
      } catch (_) {
        // Skip invalid dates
      }
    }
    
    // Calculate average per weekday and convert to percentage (max 180 min = 100%)
    final rhythm = List.generate(7, (i) {
      final avg = (minutesByWeekday[i] ?? 0.0) / 4.0; // ~4 weeks in 30 days
      return (avg / 180.0 * 100.0).clamp(0.0, 100.0); // Convert to percentage
    });
    
    final maxVal = rhythm.reduce((a, b) => a > b ? a : b);
    final maxValForDisplay = maxVal > 0 ? maxVal : 100.0; // Avoid division by zero

    Color getBarColor(double val) {
      if (val >= 80) return const Color(0xFFC791F2); // bg-[hsl(270,60%,78%)]
      if (val >= 50) return const Color(0xFF8ABDEB); // bg-[hsl(210,70%,75%)]
      return const Color(0xFF8EDEA8); // bg-[hsl(150,55%,72%)]
    }

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
            "Work Rhythm",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "How your productivity flows during the week",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 180,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final barHeight = (rhythm[i] / maxValForDisplay) * 130;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "${rhythm[i].toInt()}%",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: barHeight),
                        duration: Duration(milliseconds: 800 + (i * 80)),
                        curve: Curves.easeOutCubic,
                        builder: (context, height, child) {
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: height.clamp(4.0, 130.0),
                            decoration: BoxDecoration(
                              color: getBarColor(rhythm[i]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        days[i],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),
          
          Row(
            children: [
              _LegendItem(color: const Color(0xFFC791F2), label: "High"),
              const SizedBox(width: 16),
              _LegendItem(color: const Color(0xFF8ABDEB), label: "Medium"),
              const SizedBox(width: 16),
              _LegendItem(color: const Color(0xFF8EDEA8), label: "Low"),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
