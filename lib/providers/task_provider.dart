import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/due_task.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/ai_planning_service.dart';

class PlanItem {
  final String dueId;
  final String title;
  final String group;
  final int minutesPlannedToday;
  final DateTime endDate;

  PlanItem({
    required this.dueId,
    required this.title,
    required this.group,
    required this.minutesPlannedToday,
    required this.endDate,
  });
}

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  final AIPlanningService _aiPlanningService = AIPlanningService();
  final List<DueTask> _dues = [];
  final Map<String, Task> _tasksMap = {}; // Store tasks for AI data access
  StreamSubscription? _tasksSubscription;
  StreamSubscription? _authSubscription;
  bool _isLoading = false;
  String? _error;
  String? _currentUid; // Track current user UID for verification

  List<DueTask> get dues => _dues;
  bool get isLoading => _isLoading;
  String? get error => _error;

  TaskProvider() {
    // Listen to auth state changes to re-initialize when user changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        final newUid = user?.uid;
        if (newUid != _currentUid) {
          print('🔄 Auth state changed: ${_currentUid} -> $newUid');
          _currentUid = newUid;
          _initializeTasks();
        }
      },
    );
    // Initialize immediately if user is already logged in
    _initializeTasks();
  }

  // Trigger backend replanning once per day (per task) based on lastPlannedAt
  void _maybeTriggerDailyReplanning() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final entry in _tasksMap.entries) {
      final task = entry.value;
      final ai = task.ai;

      if (ai == null || !ai.generated) continue;
      if (task.dueDate == null) continue; // only tasks with deadlines need replanning

      final last = ai.lastPlannedAt;
      if (last == null) {
        // Never planned (or migrated old tasks) -> plan now
        _aiPlanningService.planTask(task.id);
        continue;
      }

      final lastDay = DateTime(last.year, last.month, last.day);
      if (today.isAfter(lastDay)) {
        // New calendar day since last plan -> replan to compress remaining work
        _aiPlanningService.planTask(task.id);
      }
    }
  }

  void _initializeTasks() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ No user logged in - clearing tasks');
      _dues.clear();
      _tasksMap.clear();
      _tasksSubscription?.cancel();
      _tasksSubscription = null;
      _currentUid = null;
      notifyListeners();
      return;
    }

    // Verify we're using the correct UID
    if (_currentUid != null && _currentUid != user.uid) {
      print('⚠️ UID mismatch detected! Expected: $_currentUid, Got: ${user.uid}');
    }

    print('✅ Initializing tasks for user: ${user.uid}');
    _currentUid = user.uid;
    _isLoading = true;
    notifyListeners();

    // Cancel any existing subscription
    _tasksSubscription?.cancel();
    
    // Create new subscription with user's UID
    _tasksSubscription = _taskService.getTasks(user.uid).listen(
      (snapshot) {
        print('📥 Received ${snapshot.docs.length} tasks for user: ${user.uid}');
        _dues.clear();
        _tasksMap.clear();
        for (var doc in snapshot.docs) {
          final task = Task.fromDoc(doc);
          _tasksMap[task.id] = task; // Store task for AI data access
          final dueTask = _taskToDueTask(task);
          _dues.add(dueTask);
        }
        _isLoading = false;
        _error = null;
        _maybeTriggerDailyReplanning();
        notifyListeners();
      },
      onError: (error) {
        print('❌ Error loading tasks for user ${user.uid}: $error');
        _isLoading = false;
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // Convert Firestore Task to DueTask for compatibility
  DueTask _taskToDueTask(Task task) {
    // Map category to group (capitalize first letter)
    String group = "Work";
    if (task.category != null) {
      final cat = task.category!.toLowerCase();
      if (cat == "personal") {
        group = "Personal";
      } else if (cat == "study") {
        group = "Study";
      } else if (cat == "work") {
        group = "Work";
      } else {
        // Default to Work if unknown
        group = "Work";
      }
    }

    // Use AI estimated minutes if available, otherwise fallback to manual estimate
    int? durationMinutes; // Nullable - AI will estimate if not provided
    if (task.ai != null && task.ai!.estimatedMinutes > 0) {
      durationMinutes = task.ai!.estimatedMinutes;
    } else if (task.estimatedMinutes != null && task.estimatedMinutes! > 0) {
      durationMinutes = task.estimatedMinutes!;
    }
    // If still null, AI will estimate later

    return DueTask(
      id: task.id,
      title: task.title,
      description: task.description,
      group: group,
      endDate: task.dueDate ?? DateTime.now().add(const Duration(days: 7)),
      durationMinutes: durationMinutes, // Can be null
      isDone: task.completed,
      completedAt: task.completedAt,
    );
  }

  // Map group to category (lowercase)
  String _groupToCategory(String group) {
    switch (group) {
      case "Personal":
        return "personal";
      case "Study":
        return "study";
      case "Work":
      default:
        return "work";
    }
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  // -------------------- ADD DUE --------------------
  Future<void> addDue({
    required String title,
    required String description,
    required String group,
    required DateTime endDate,
    int? durationMinutes, // Optional - AI will estimate if not provided
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      final taskId = await _taskService.addTask(
        uid: user.uid,
        title: title,
        description: description,
        dueDate: endDate,
        priority: 'medium',
        estimatedMinutes: durationMinutes, // Can be null - AI will estimate
        category: _groupToCategory(group),
      );
      
      // AI planning is triggered automatically in TaskService
      // The stream will update _dues when AI data is available
      
      print('✅ Task created: $taskId');
      print('🤖 AI planning triggered in background...');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // -------------------- DONE / UNDO --------------------
  Future<void> toggleDone(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    final due = _dues.firstWhere((d) => d.id == id, orElse: () => throw Exception('Due not found'));
    final newCompletedState = !due.isDone;

    try {
      _error = null;
      await _taskService.toggleComplete(user.uid, id, newCompletedState);
      // Stream will update _dues automatically
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // -------------------- CALENDAR FILTER --------------------
  List<DueTask> duesForDate(DateTime date) {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return _dues.where((d) => sameDay(d.endDate, date)).toList();
  }

  // ============================================================
  // ✅ AI-POWERED PLANNER (USES GEMINI ESTIMATES)
  // ============================================================

  // Helper to get task from stored map (private)
  Task? _getTask(String taskId) {
    return _tasksMap[taskId];
  }

  // Public method to get task (for UI)
  Task? getTask(String taskId) {
    return _getTask(taskId);
  }

  // Generates today's AI-optimized plan
  // Uses AI planning data from backend when available
  List<PlanItem> todaysBalancedPlan(DateTime today) {
    final active = _dues.where((d) => !d.isDone).toList();

    final List<PlanItem> plan = [];

    for (final d in active) {
      // Get corresponding task to access AI data
      final task = _getTask(d.id);

      int minutesPlannedToday;

      if (task?.ai != null && task!.ai!.generated) {
        // Use AI planning data from backend
        // The backend calculates dailyRequiredMinutes based on:
        // - AI-estimated total minutes (from Gemini)
        // - Days remaining until deadline
        // - Pressure and risk scores
        minutesPlannedToday = task.ai!.dailyRequiredMinutes;
        
        print('🤖 Using AI plan for "${d.title}": $minutesPlannedToday min today');
        print('   AI estimated: ${task.ai!.estimatedMinutes} min total');
        print('   Daily required: ${task.ai!.dailyRequiredMinutes} min');
        print('   Pressure score: ${task.ai!.pressureScore}');
        print('   Risk score: ${task.ai!.riskScore}');
        print('   Confidence: ${task.ai!.confidence}');
      } else {
        // Fallback to smart distribution if AI data not available yet
        final daysLeft = d.endDate.difference(_onlyDate(today)).inDays;
        final remainingDays = daysLeft <= 0 ? 1 : (daysLeft + 1);
        
        // Use the duration (which may be AI-estimated or manual)
        // If duration is null, use a default estimate
        final taskDuration = d.durationMinutes ?? 60; // Default 60 min if not set
        minutesPlannedToday = (taskDuration / remainingDays).ceil();
        
        // If task has description but no AI data yet, it might still be processing
        if (task?.description.isNotEmpty == true && task?.dueDate != null) {
          print('⏳ AI planning pending for "${d.title}", using fallback: $minutesPlannedToday min');
        } else {
          print('📝 Using manual estimate for "${d.title}": $minutesPlannedToday min');
        }
      }

      plan.add(
        PlanItem(
          dueId: d.id,
          title: d.title,
          group: d.group,
          minutesPlannedToday: minutesPlannedToday,
          endDate: d.endDate,
        ),
      );
    }

    // Sort by: AI risk score (if available), then deadline
    plan.sort((a, b) {
      final taskA = _getTask(a.dueId);
      final taskB = _getTask(b.dueId);
      
      final riskA = taskA?.ai?.riskScore ?? 0.0;
      final riskB = taskB?.ai?.riskScore ?? 0.0;
      
      if (riskA != riskB) {
        return riskB.compareTo(riskA); // Higher risk first
      }
      
      return a.endDate.compareTo(b.endDate); // Earlier deadline first
    });
    
    return plan;
  }

  // ============================================================
  // ✅ PRESSURE METER
  // ============================================================

  // Pressure based on next N days workload
  // Uses AI pressure scores when available
  int pressureScoreFollowPlan({int horizonDays = 7, int dailyCapacityMinutes = 180}) {
    final today = _onlyDate(DateTime.now());
    final end = today.add(Duration(days: horizonDays));

    // Try to use AI pressure scores first
    double totalPressure = 0.0;
    int aiTaskCount = 0;
    
    for (final d in _dues.where((x) => !x.isDone)) {
      if (d.endDate.isBefore(end) || _sameDay(d.endDate, end)) {
        final task = _getTask(d.id);
        if (task?.ai != null && task!.ai!.generated) {
          // Use AI pressure score (weighted by days in horizon)
          totalPressure += task.ai!.pressureScore;
          aiTaskCount++;
        }
      }
    }

    // If we have AI data, use it; otherwise fallback to calculation
    if (aiTaskCount > 0) {
      final avgPressure = totalPressure / aiTaskCount;
      // Convert pressure score (0-1.5+) to percentage (0-100)
      return ((avgPressure / 1.5) * 100).clamp(0, 100).round();
    }

    // Fallback: calculate from duration
    int totalWork = 0;
    for (final d in _dues.where((x) => !x.isDone)) {
      if (d.endDate.isBefore(end) || _sameDay(d.endDate, end)) {
        totalWork += d.durationMinutes ?? 60; // Default 60 min if not set
      }
    }

    final available = horizonDays * dailyCapacityMinutes;
    final ratio = available == 0 ? 0.0 : totalWork / available;

    return (ratio * 100).clamp(0, 100).round();
  }

  // If user skips today's plan -> pressure increases
  int pressureScoreIfSkippedToday({int horizonDays = 7, int dailyCapacityMinutes = 180}) {
    final follow = pressureScoreFollowPlan(
      horizonDays: horizonDays,
      dailyCapacityMinutes: dailyCapacityMinutes,
    );

    final todayPlan = todaysBalancedPlan(DateTime.now());
    final skippedMinutes = todayPlan.fold<int>(0, (sum, p) => sum + p.minutesPlannedToday);

    // Increase pressure based on skipped minutes relative to daily capacity
    final bump = ((skippedMinutes / dailyCapacityMinutes) * 25).round(); // tuned for demo feel
    return (follow + bump).clamp(0, 100).round();
  }

  // ============================================================
  // ✅ RISK METER
  // ============================================================

  int riskScore() {
    final today = _onlyDate(DateTime.now());
    final active = _dues.where((d) => !d.isDone).toList();

    if (active.isEmpty) return 0;

    // Try to use AI risk scores first
    double totalRisk = 0.0;
    int aiTaskCount = 0;
    
    for (final d in active) {
      final task = _getTask(d.id);
      if (task?.ai != null && task!.ai!.generated) {
        totalRisk += task.ai!.riskScore;
        aiTaskCount++;
      }
    }

    // If we have AI data, use it; otherwise fallback to calculation
    if (aiTaskCount > 0) {
      final avgRisk = totalRisk / aiTaskCount;
      // AI risk score is already 0-1, convert to 0-100
      return (avgRisk * 100).clamp(0, 100).round();
    }

    // Fallback: calculate from overdue/due soon + pressure
    int overdueCount = active.where((d) => d.endDate.isBefore(today)).length;
    int dueSoonCount = active.where((d) {
      final daysLeft = d.endDate.difference(today).inDays;
      return daysLeft >= 0 && daysLeft <= 2;
    }).length;

    final pressure = pressureScoreFollowPlan();

    int score = 0;
    score += overdueCount * 35;
    score += dueSoonCount * 15;
    score += (pressure * 0.5).round();

    return score.clamp(0, 100);
  }

  String riskLabel() {
    final r = riskScore();
    if (r >= 75) return "High";
    if (r >= 40) return "Medium";
    return "Low";
  }

  // ============================================================
  // ✅ WEEKLY GOALS (BY CATEGORY)
  // ============================================================

  // Hardcoded weekly goals (MVP)
  final Map<String, int> weeklyGoals = const {
    "Work": 10,
    "Personal": 5,
    "Study": 7,
  };

  Map<String, int> completedThisWeekByCategory() {
    final now = DateTime.now();
    final start = _startOfWeek(now); // Monday
    final end = start.add(const Duration(days: 7));

    final Map<String, int> result = {
      "Work": 0,
      "Personal": 0,
      "Study": 0,
    };

    for (final d in _dues) {
      if (d.isDone && d.completedAt != null) {
        final c = d.completedAt!;
        if ((c.isAfter(start) || _sameDay(c, start)) && c.isBefore(end)) {
          result[d.group] = (result[d.group] ?? 0) + 1;
        }
      }
    }
    return result;
  }

  // ============================================================
  // ✅ STREAK
  // ============================================================

  int streakDays() {
    final doneDates = <String>{};

    for (final d in _dues) {
      if (d.isDone && d.completedAt != null) {
        final c = _onlyDate(d.completedAt!);
        doneDates.add("${c.year}-${c.month}-${c.day}");
      }
    }

    int streak = 0;
    DateTime cursor = _onlyDate(DateTime.now());

    while (true) {
      final key = "${cursor.year}-${cursor.month}-${cursor.day}";
      if (doneDates.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  // ============================================================
  // ✅ HEATMAP (last 28 days)
  // ============================================================

  // returns list of 28 values (0..4 intensity)
  List<int> heatmapLast28Days() {
    final today = _onlyDate(DateTime.now());

    // minutes done per day
    final Map<String, int> minutesByDay = {};

    for (final d in _dues) {
      if (d.isDone && d.completedAt != null) {
        final day = _onlyDate(d.completedAt!);
        final key = "${day.year}-${day.month}-${day.day}";
        minutesByDay[key] = (minutesByDay[key] ?? 0) + (d.durationMinutes ?? 0);
      }
    }

    final List<int> intensity = [];

    for (int i = 27; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final key = "${day.year}-${day.month}-${day.day}";
      final mins = minutesByDay[key] ?? 0;

      // Convert minutes to intensity 0..4
      int level = 0;
      if (mins == 0) {
        level = 0;
      } else if (mins <= 30) level = 1;
      else if (mins <= 60) level = 2;
      else if (mins <= 120) level = 3;
      else level = 4;

      intensity.add(level);
    }

    return intensity;
  }

  // -------------------- HELPERS --------------------
  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime d) {
    final only = _onlyDate(d);
    final diff = only.weekday - DateTime.monday;
    return only.subtract(Duration(days: diff));
  }
}
