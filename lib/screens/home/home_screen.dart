import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../models/due_task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../add_due/add_due_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final plan = provider.todaysBalancedPlan(DateTime.now());
    final List<DueTask> dues = List<DueTask>.from(provider.dues);

    DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);
    final DateTime today = _onlyDate(DateTime.now());

    // Map of dueId -> minutes planned today (from AI plan)
    final Map<String, int> minutesById = {
      for (final p in plan) p.dueId: p.minutesPlannedToday,
    };

    // Order active items by plan, then append remaining (typically completed) items
    final List<DueTask> activeInPlanOrder = [];
    for (final p in plan) {
      for (final d in dues) {
        if (d.id == p.dueId) {
          activeInPlanOrder.add(d);
          break;
        }
      }
    }
    final List<DueTask> rest = dues
        .where((d) => !activeInPlanOrder.any((a) => a.id == d.id))
        .toList();
    final List<DueTask> combined = [...activeInPlanOrder, ...rest];

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar similar to Calendar: back icon, centered title, action on right
              Row(
                children: [
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Home",
                        style: AppText.heading2.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddDuePage(),
                        ),
                      );
                    },
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA5B4FC), Color(0xFFC7D2FE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA5B4FC).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Expanded(
                child: combined.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        itemCount: combined.length,
                        itemBuilder: (context, i) {
                          final due = combined[i];
                          final isDone = due.isDone;
                          final minutesToday = minutesById[due.id];
                          final timeLabel = minutesToday != null
                              ? "$minutesToday min today"
                              : (due.durationMinutes != null
                                  ? "${due.durationMinutes} min"
                                  : "AI estimating...");

                          // Get task to access AI planning data (subtasks)
                          final task = provider.getTask(due.id);
                          final ai = task?.ai;

                          String displayTitle = due.title;
                          List<String> displaySteps = const [];

                          if (ai != null) {
                            final subtasks = ai.subtasks;
                            // Prefer today's scheduled, incomplete subtasks
                            final todaysSubs = subtasks.where((s) {
                              final sd = s.scheduledDate;
                              return sd != null &&
                                  _onlyDate(sd) == today &&
                                  !s.completed;
                            }).toList();

                            if (todaysSubs.isNotEmpty) {
                              // Use the first today's subtask as the main title
                              displayTitle = todaysSubs.first.text;
                              // Any remaining today's subtasks become bullet points
                              displaySteps = todaysSubs
                                  .skip(1)
                                  .map((s) => s.text)
                                  .toList();
                            } else if (subtasks.isNotEmpty) {
                              // Fallback: show next incomplete subtask, even if on another day
                              final incomplete = subtasks
                                  .where((s) => !s.completed)
                                  .toList();
                              if (incomplete.isNotEmpty) {
                                displayTitle = incomplete.first.text;
                                displaySteps = incomplete
                                    .skip(1)
                                    .map((s) => s.text)
                                    .toList();
                              } else {
                                // All subtasks done: still show the last one as a label
                                displayTitle = subtasks.last.text;
                              }
                            } else if (ai.actionSteps.isNotEmpty) {
                              // Legacy fallback: use high-level action steps
                              displayTitle = ai.actionSteps.first;
                              displaySteps =
                                  ai.actionSteps.skip(1).toList();
                            }
                          }

                          return _DueCard(
                            title: displayTitle,
                            time: timeLabel,
                            isDone: isDone,
                            actionSteps: displaySteps,
                            onToggle: () {
                              provider.toggleDone(due.id);
                            },
                          );
                        },
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.1),
                ],
              ),
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 64,
              color: AppColors.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No dues yet",
            style: AppText.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add one to generate a plan",
            style: AppText.body.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DueCard extends StatefulWidget {
  final String title;
  final String time;
  final bool isDone;
  final List<String> actionSteps;
  final VoidCallback onToggle;

  const _DueCard({
    required this.title,
    required this.time,
    required this.isDone,
    required this.actionSteps,
    required this.onToggle,
  });

  @override
  State<_DueCard> createState() => _DueCardState();
}

class _DueCardState extends State<_DueCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: widget.isDone
                ? LinearGradient(
                    colors: [
                      AppColors.completedBackground,
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white,
                      AppColors.accent.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.isDone
                    ? AppColors.primary.withOpacity(0.08)
                    : AppColors.primary.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: widget.isDone
                      ? LinearGradient(
                          colors: [
                            AppColors.completedCheck.withOpacity(0.2),
                            AppColors.completedCheck.withOpacity(0.1),
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.secondary.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.work_outline_rounded,
                  color: widget.isDone
                      ? AppColors.completedCheck
                      : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: widget.isDone
                            ? AppColors.completedText
                            : AppColors.textPrimary,
                        decoration: widget.isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppColors.completedText,
                        decorationThickness: 1.5,
                      ),
                      child: Text(widget.title),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.time,
                      style: AppText.caption.copyWith(
                        fontSize: 12,
                        color: widget.isDone
                            ? AppColors.textMuted.withOpacity(0.7)
                            : AppColors.textMuted,
                      ),
                    ),
                    // Show AI-generated action steps
                    if (widget.actionSteps.isNotEmpty && !widget.isDone) ...[
                      const SizedBox(height: 8),
                      ...widget.actionSteps.take(3).map((step) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6, right: 8),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    step,
                                    style: AppText.caption.copyWith(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),

              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onToggle,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isDone
                            ? AppColors.completedCheck.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.isDone
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 24,
                        color: widget.isDone
                            ? AppColors.completedCheck
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
