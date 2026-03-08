import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();

    // Weekly goals
    final weeklyDone = provider.completedThisWeekByCategory();
    final weeklyGoals = provider.weeklyGoals;

    double pct(String key) {
      final done = (weeklyDone[key] ?? 0);
      final goal = (weeklyGoals[key] ?? 0);
      if (goal == 0) return 0;
      return (done / goal).clamp(0, 1).toDouble();
    }

    final workPct = pct("Work");
    final personalPct = pct("Personal");
    final studyPct = pct("Study");

    // Pressure & Risk
    final pressureFollow = provider.pressureScoreFollowPlan();
    final risk = provider.riskScore();

    // Streak
    final streak = provider.streakDays();

    // Heatmap
    final heat = provider.heatmapLast28Days();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // GRADIENT HEADER (FULL WIDTH)
            DashboardHeaderGradient(streak: streak),

            const SizedBox(height: 20),

            // BODY SCROLL
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // PRESSURE + RISK OUTSIDE GRADIENT
                  Row(
                    children: [
                      Expanded(
                        child: _ThemedGaugeCard(
                          title: "Pressure",
                          value: pressureFollow,
                          icon: Icons.bolt_rounded,
                          accent: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ThemedGaugeCard(
                          title: "Risk",
                          value: risk,
                          icon: Icons.warning_amber_rounded,
                          accent: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // GOAL CHECK CARD
                  _WhiteCard(
                    child: Column(
                      children: [
                        Text(
                          "Goal Check",
                          style: AppText.heading2.copyWith(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: SizedBox(
                            width: 170,
                            height: 170,
                            child: CustomPaint(
                              painter: _MultiRingPainter(
                                rings: [
                                  _RingData(progress: workPct, color: AppColors.primary),
                                  _RingData(progress: personalPct, color: AppColors.secondary),
                                  _RingData(progress: studyPct, color: AppColors.accent),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "${((workPct + personalPct + studyPct) / 3 * 100).round()}%",
                                  style: AppText.heading1.copyWith(
                                    fontSize: 24,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _LegendDot(color: AppColors.primary, text: "Work"),
                            SizedBox(width: 16),
                            _LegendDot(color: AppColors.secondary, text: "Personal"),
                            SizedBox(width: 16),
                            _LegendDot(color: AppColors.accent, text: "Study"),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TRACKER CARD
                  _WhiteCard(
                    child: Column(
                      children: [
                        Text(
                          "Tracker",
                          style: AppText.heading2.copyWith(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(child: _HeatmapGrid(levels: heat)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== DASHBOARD HEADER GRADIENT =====================

class DashboardHeaderGradient extends StatelessWidget {
  final int streak;

  const DashboardHeaderGradient({
    super.key,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.accent,
            AppColors.secondary,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOP BAR INSIDE GRADIENT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.9),
              ),
              Text(
                "Dashboard",
                style: AppText.heading2.copyWith(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              Icon(
                Icons.notifications_none_rounded,
                color: Colors.white.withOpacity(0.9),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            "$streak day streak",
            style: AppText.heading1.copyWith(
              fontSize: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Keep following the plan to reduce pressure.",
            style: AppText.body.copyWith(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== THEMED GAUGE CARD =====================

class _ThemedGaugeCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color accent;

  const _ThemedGaugeCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final v = (value / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: AppColors.accent.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppText.bodyBold.copyWith(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 85,
            child: CustomPaint(
              painter: _SemiGaugePainterThemed(
                progress: v,
                accent: accent,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    "$value%",
                    style: AppText.heading1.copyWith(
                      fontSize: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemiGaugePainterThemed extends CustomPainter {
  final double progress;
  final Color accent;

  _SemiGaugePainterThemed({
    required this.progress,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.98);
    final radius = math.min(size.width / 2, size.height) - 6;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent.withOpacity(0.2);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = accent;

    final start = math.pi;
    final sweepFull = math.pi;
    final sweep = sweepFull * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweepFull,
      false,
      bg,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===================== MULTI RING PAINTER =====================

class _RingData {
  final double progress;
  final Color color;

  const _RingData({required this.progress, required this.color});
}

class _MultiRingPainter extends CustomPainter {
  final List<_RingData> rings;

  _MultiRingPainter({required this.rings});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent.withOpacity(0.2);

    final startAngle = -math.pi / 2;

    const double strokeWidth = 10;
    const double gap = 7;

    double radius = (size.shortestSide / 2) - 6;

    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];

      bgPaint.strokeWidth = strokeWidth;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        0,
        2 * math.pi,
        false,
        bgPaint,
      );

      final fgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = ring.color;

      final sweep = (2 * math.pi) * ring.progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        fgPaint,
      );

      radius -= (strokeWidth + gap);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===================== HEATMAP GRID =====================

class _HeatmapGrid extends StatelessWidget {
  final List<int> levels;

  const _HeatmapGrid({required this.levels});

  Color _heatColor(int level) {
    switch (level) {
      case 0:
        return AppColors.accent.withOpacity(0.2);
      case 1:
        return AppColors.accent.withOpacity(0.4);
      case 2:
        return AppColors.primary.withOpacity(0.6);
      case 3:
        return AppColors.primary.withOpacity(0.8);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 28,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (context, i) {
          final level = levels[i];
          return Container(
            decoration: BoxDecoration(
              color: _heatColor(level),
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}

// ===================== LEGEND DOT =====================

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendDot({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppText.caption.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ===================== WHITE CARD =====================

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: AppColors.accent.withOpacity(0.18),
        ),
      ),
      child: child,
    );
  }
}
