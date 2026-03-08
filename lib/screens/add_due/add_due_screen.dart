import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Full-screen wrapper used when navigating to Add Due via push().
/// Keeps the original AddDueScreen logic and layout unchanged.
class AddDuePage extends StatelessWidget {
  const AddDuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFF),
      body: AddDueScreen(),
    );
  }
}

class AddDueScreen extends StatefulWidget {
  const AddDueScreen({super.key});

  @override
  State<AddDueScreen> createState() => _AddDueScreenState();
}

class _AddDueScreenState extends State<AddDueScreen> {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  DateTime selectedEndDate = DateTime.now();
  String selectedGroup = "Work";
  // Duration will be estimated by AI - no manual input needed

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return "${date.day} ${months[date.month - 1]}, ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                      }
                    },
                  ),
                  Text(
                    "Add Dues",
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

              const SizedBox(height: 24),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 60,
                  ),
                  children: [
                    // Category dropdown
                    _InputTile(
                      icon: Icons.work_outline_rounded,
                      title: "Task Group",
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) {
                              return Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                child: SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: AppColors.textMuted.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      ListTile(
                                        title: Text(
                                          "Work",
                                          style: AppText.body.copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        onTap: () {
                                          setState(() => selectedGroup = "Work");
                                          Navigator.pop(context);
                                        },
                                        trailing: selectedGroup == "Work"
                                            ? Icon(
                                                Icons.check_circle_rounded,
                                                color: AppColors.primary,
                                              )
                                            : null,
                                      ),
                                      ListTile(
                                        title: Text(
                                          "Personal",
                                          style: AppText.body.copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        onTap: () {
                                          setState(() => selectedGroup = "Personal");
                                          Navigator.pop(context);
                                        },
                                        trailing: selectedGroup == "Personal"
                                            ? Icon(
                                                Icons.check_circle_rounded,
                                                color: AppColors.primary,
                                              )
                                            : null,
                                      ),
                                      ListTile(
                                        title: Text(
                                          "Study",
                                          style: AppText.body.copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        onTap: () {
                                          setState(() => selectedGroup = "Study");
                                          Navigator.pop(context);
                                        },
                                        trailing: selectedGroup == "Study"
                                            ? Icon(
                                                Icons.check_circle_rounded,
                                                color: AppColors.primary,
                                              )
                                            : null,
                                      ),
                                      SizedBox(
                                        height: MediaQuery.of(context).padding.bottom,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedGroup,
                              style: AppText.bodyBold.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    _InputTile(
                      title: "Name",
                      child: TextField(
                        controller: nameController,
                        style: AppText.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: "Write your title...",
                          hintStyle: TextStyle(
                            color: AppColors.textMuted.withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    _InputTile(
                      title: "Description",
                      child: TextField(
                        controller: descController,
                        maxLines: 4,
                        style: AppText.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: "Write your due details here...",
                          hintStyle: TextStyle(
                            color: AppColors.textMuted.withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    _InputTile(
                      icon: Icons.event_outlined,
                      title: "End Date",
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedEndDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: AppColors.primary,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => selectedEndDate = picked);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(selectedEndDate),
                              style: AppText.bodyBold.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          final title = nameController.text.trim();
                          final desc = descController.text.trim();

                          if (title.isEmpty) return;

                          try {
                            await context.read<TaskProvider>().addDue(
                                  title: title,
                                  description: desc,
                                  group: selectedGroup,
                                  endDate: selectedEndDate,
                                  durationMinutes: null, // AI will estimate
                                );

                            nameController.clear();
                            descController.clear();
                            setState(() {
                              selectedEndDate = DateTime.now();
                              selectedGroup = "Work";
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("Due added!"),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              final navigator = Navigator.of(context);
                              if (navigator.canPop()) {
                                navigator.pop();
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: Colors.red.shade300,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          "Add Due",
                          style: AppText.bodyBold.copyWith(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputTile extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;

  const _InputTile({
    required this.title,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            AppColors.accent.withOpacity(0.03),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: AppText.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
