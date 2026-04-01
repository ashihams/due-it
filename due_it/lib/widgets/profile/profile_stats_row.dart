import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final allDues = provider.dues;

    final int completedCount = allDues.where((d) => d.isDone).length;
    final int activeCount = allDues.where((d) => !d.isDone).length;
    
    final int completedMinutes = allDues
        .where((d) => d.isDone)
        .fold(0, (sum, d) {
          final int dur = d.durationMinutes ?? 0;
          return sum + (dur > 0 ? dur : 0);
        });
    final String focusTime = (completedMinutes / 60).toStringAsFixed(0).padLeft(2, '0');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - val)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 32),
        child: Row(
          children: [
            Expanded(
              child: _StatCard(
                value: completedCount.toString().padLeft(2, '0'),
                label: "Completed",
                // bg-[hsl(150,50%,90%)]
                bgColor: const Color(0xFFD1F2E0),
                // text-[hsl(150,50%,30%)]
                textColor: const Color(0xFF26734D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                value: activeCount.toString().padLeft(2, '0'),
                label: "Active",
                // bg-[hsl(270,60%,92%)]
                bgColor: const Color(0xFFF0E5FA),
                // text-[hsl(270,40%,35%)]
                textColor: const Color(0xFF5E368A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                value: focusTime,
                label: "Focus time",
                // bg-[hsl(200,70%,90%)]
                bgColor: const Color(0xFFD6EEF9),
                // text-[hsl(200,60%,35%)]
                textColor: const Color(0xFF246B8F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color bgColor;
  final Color textColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24, // text-2xl
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, // text-xs
              fontWeight: FontWeight.w500,
              color: textColor.withAlpha(178), // opacity-70 roughly
            ),
          ),
        ],
      ),
    );
  }
}
