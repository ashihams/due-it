import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';


class StreakCard extends StatelessWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final streak = provider.currentStreak;

    // Replicating: bg-[hsl(270,60%,92%)]
    final bgColor = const Color(0xFFF0E5FA);
    
    // Replicating: text-[hsl(270,40%,45%)]
    final labelColor = const Color(0xFF7A45B0);
    
    // Replicating: text-[hsl(270,40%,30%)]
    final titleColor = const Color(0xFF532E7A);
    
    // Replicating: text-[hsl(270,30%,55%)]
    final subColor = const Color(0xFF9069B5);

    // Replicating: bg-[hsl(270,50%,80%)]/20 (Blob color)
    final blobColor = const Color(0xFFD6B3F5).withAlpha(51);

    // Replicating: bg-[hsl(270,50%,65%)]/20 (Icon background)
    final iconBgColor = const Color(0xFFB57CEB).withAlpha(51);

    // Replicating: text-[hsl(270,50%,45%)] (Icon color)
    final iconColor = const Color(0xFF7E39C2);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(20),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  // 0 4px 20px -4px hsl(270,50%,70%,0.15)
                  color: const Color(0xFFC791F2).withAlpha(38),
                  blurRadius: 20,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Abstract Blob
                Positioned(
                  top: -60,
                  right: -30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: blobColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          color: iconColor,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current Streak",
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "$streak Days",
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          "Keep up the momentum 🚀",
                          style: TextStyle(
                            color: subColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
