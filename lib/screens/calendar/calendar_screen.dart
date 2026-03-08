import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../models/due_task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final List<DateTime> dateList;
  int selectedIndex = 0;
  String selectedFilter = "All";

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();
    dateList = List.generate(30, (i) {
      return DateTime(today.year, today.month, today.day + i);
    });

    selectedIndex = 0;
  }

  DateTime get selectedDate => dateList[selectedIndex];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();

    final List<DueTask> dueList = provider.duesForDate(selectedDate);

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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  Text(
                    "Calendar",
                    style: AppText.heading2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Date chips row
              SizedBox(
                height: 90,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(dateList.length, (i) {
                      final date = dateList[i];
                      final isSelected = i == selectedIndex;

                      final month = _monthShort(date.month);
                      final day = date.day.toString();
                      final label = _dayShort(date.weekday);

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => setState(() => selectedIndex = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            width: 64,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [AppColors.primary, AppColors.accent],
                                    )
                                  : null,
                              color: isSelected ? null : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? AppColors.primary.withOpacity(0.3)
                                      : AppColors.primary.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  month,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.9)
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.9)
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Filter pills
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterPill(
                      text: "All",
                      isActive: selectedFilter == "All",
                      onTap: () => setState(() => selectedFilter = "All"),
                    ),
                    _FilterPill(
                      text: "To do",
                      isActive: selectedFilter == "To do",
                      onTap: () => setState(() => selectedFilter = "To do"),
                    ),
                    _FilterPill(
                      text: "In Progress",
                      isActive: selectedFilter == "In Progress",
                      onTap: () => setState(() => selectedFilter = "In Progress"),
                    ),
                    _FilterPill(
                      text: "Completed",
                      isActive: selectedFilter == "Completed",
                      onTap: () => setState(() => selectedFilter = "Completed"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Task list
              Expanded(
                child: dueList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                              child: Icon(
                                Icons.calendar_today_rounded,
                                size: 48,
                                color: AppColors.primary.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No dues on this date",
                              style: AppText.body.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: dueList.length,
                        itemBuilder: (context, i) {
                          final t = dueList[i];
                          return _CalendarTaskCard(task: t);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- UI WIDGETS --------------------

class _FilterPill extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterPill({
    required this.text,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                  )
                : null,
            color: isActive ? null : AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            style: AppText.bodyBold.copyWith(
              fontSize: 13,
              color: isActive ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarTaskCard extends StatelessWidget {
  final DueTask task;

  const _CalendarTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.group,
                  style: AppText.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  task.title,
                  style: AppText.bodyBold.copyWith(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${task.durationMinutes} min",
                      style: AppText.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),

          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withOpacity(0.3),
                  AppColors.secondary.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.bookmark_rounded,
              size: 16,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- HELPER FUNCTIONS --------------------

String _monthShort(int m) {
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ];
  return months[m - 1];
}

String _dayShort(int w) {
  const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  return days[w - 1];
}
