import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';

class DashboardGaugeCards extends StatelessWidget {
  const DashboardGaugeCards({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final pressureScore = provider.pressureScoreFollowPlan();
    final riskScore = provider.riskScore();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _GaugeCard(
              title: "Pressure",
              value: pressureScore,
              label: "Active load",
              // hsl(200,65%,45%)
              strokeColor: const Color(0xFF2886B8),
              // hsl(200,70%,90%)
              bgColor: const Color(0xFFD6EEF9),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _GaugeCard(
              title: "Risk",
              value: riskScore,
              label: "Overdue risk",
              // hsl(150,50%,40%)
              strokeColor: const Color(0xFF339966),
              // hsl(150,50%,90%)
              bgColor: const Color(0xFFD1F2E0),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  final String title;
  final int value;
  final String label;
  final Color strokeColor;
  final Color bgColor;

  const _GaugeCard({
    required this.title,
    required this.value,
    required this.label,
    required this.strokeColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 110,
              height: 110,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, progress, child) {
                  return CustomPaint(
                    painter: _GaugePainter(
                      progress: progress,
                      color: strokeColor,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$value%",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.width / 2);
    final radius = size.width / 2 - 5;
    
    // Background Track
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withAlpha(15);
      
    // Foreground Arc
    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;

    // 270 degrees arc (0.75 of full circle), starting offset by 135 degrees.
    // In React: transform=`rotate(135)`
    // In Flutter, 0 is at 3 o'clock. 
    // We want the arc to start mathematically at +135 deg mapping.
    const startAngle = 135 * (math.pi / 180);
    // Sweep length 270 deg
    const sweepFull = 270 * (math.pi / 180);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepFull,
      false,
      bgPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepFull * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
