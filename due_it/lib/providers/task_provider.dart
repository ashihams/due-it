import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/due_task.dart';
import '../models/task.dart';
import '../models/ai_schedule_model.dart';
import '../services/task_service.dart';
import '../services/ai_planning_service.dart';

/// A single time-block slice of a task produced by the global scheduler.
class _TaskBlock {
  final String taskId;
  final int durationMinutes;
  final DateTime? deadline;

  _TaskBlock({required this.taskId, required this.durationMinutes, this.deadline});
}

/// One time block in the derived calendar (rebuilt from scratch each recompute).
class _ScheduledBlock {
  final String id;
  final String taskId;
  final int durationMinutes;
  final double startHour;

  _ScheduledBlock({
    required this.id,
    required this.taskId,
    required this.durationMinutes,
    required this.startHour,
  });
}

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

class DailyScheduledTask {
  final DueTask task;
  final AiDaySchedule schedule;
  final int blockDurationMinutes;
  final double blockStartHour;
  /// Stable id for this block (timeline); aggregated rows use `agg_$taskId_$dateKey`.
  final String blockId;

  DailyScheduledTask({
    required this.task,
    required this.schedule,
    this.blockDurationMinutes = 120,
    this.blockStartHour = 9.0,
    required this.blockId,
  });
}

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  final AIPlanningService _aiPlanningService = AIPlanningService();
  final Map<String, Task> _tasksMap = {}; // Store tasks for AI data access
  StreamSubscription? _tasksSubscription;
  StreamSubscription? _authSubscription;
  bool _isLoading = false;
  String? _error;
  String? _currentUid; // Track current user UID for verification

  // ── Global scheduling constants (CLAUDE.md) ──────────────────────────────
  static const int _kMaxMinutesPerDay = 360; // 6 h
  static const int _kBlockMinutes = 120;     // 2 h blocks
  static const double _kWorkStartHour = 9.0; // 9 AM

  /// Derived only from [_tasksMap] — never persisted; cleared and rebuilt in [_recomputeGlobalSchedule].
  Map<String, List<_ScheduledBlock>> _globalSchedule = {};
  int _blockIdSeq = 0;

  String _nextBlockId() {
    _blockIdSeq++;
    return 'b_${_blockIdSeq}_${DateTime.now().microsecondsSinceEpoch}';
  }

  List<DueTask> get dues {
    final list = _tasksMap.values.map(_taskToDueTask).toList();
    list.sort((a, b) => a.endDate.compareTo(b.endDate));
    return list;
  }
  bool get isLoading => _isLoading;
  String? get error => _error;

  TaskProvider() {
    // Listen to auth state changes to re-initialize when user changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        final newUid = user?.uid;
        if (newUid != _currentUid) {
          print('🔄 Auth state changed: $_currentUid -> $newUid');
          _currentUid = newUid;
          _initializeTasks();
        }
      },
    );
    // Initialize immediately if user is already logged in
    _initializeTasks();
  }

  /// Rebuilds the entire derived schedule from [_tasksMap] (no merge, no append).
  /// 1) Pending tasks → sort by deadline. 2) Split into ≤2h chunks. 3) Day-strips from
  /// today, max 6h/day, round-robin across tasks so each day has multiple tasks.
  void _recomputeGlobalSchedule() {
    _blockIdSeq = 0;
    final Map<String, List<_ScheduledBlock>> schedule = {};

    final pendingTasks = _tasksMap.values
        .where((t) => !t.completed && !t.isDoneFromMicrotasks)
        .toList();

    pendingTasks.sort((a, b) {
      final aD = a.dueDate ?? DateTime.now().add(const Duration(days: 365));
      final bD = b.dueDate ?? DateTime.now().add(const Duration(days: 365));
      return aD.compareTo(bD);
    });

    final Map<String, List<_TaskBlock>> taskBlocks = {};
    final orderedTaskIds = <String>[];
    for (final task in pendingTasks) {
      final totalMinutes =
          ((task.ai?.estimatedMinutes ?? task.estimatedMinutes ?? 60))
              .clamp(15, 1200);
      var remaining = totalMinutes;
      final blocksForTask = <_TaskBlock>[];
      while (remaining > 0) {
        final chunk = remaining >= _kBlockMinutes ? _kBlockMinutes : remaining;
        blocksForTask.add(_TaskBlock(
          taskId: task.id,
          durationMinutes: chunk,
          deadline: task.dueDate,
        ));
        remaining -= chunk;
      }
      taskBlocks[task.id] = blocksForTask;
      orderedTaskIds.add(task.id);
    }

    bool hasRemainingBlocks() {
      for (final id in orderedTaskIds) {
        if ((taskBlocks[id] ?? const []).isNotEmpty) return true;
      }
      return false;
    }

    var currentDate = _onlyDate(DateTime.now());
    int safetyCount = 0;

    while (hasRemainingBlocks() && safetyCount < 365) {
      final dateKey = _formatDateKey(currentDate);
      int dailyMinutes = 0;

      bool addedSomethingInPass = true;
      while (dailyMinutes < _kMaxMinutesPerDay && addedSomethingInPass) {
        addedSomethingInPass = false;
        for (final taskId in orderedTaskIds) {
          final queue = taskBlocks[taskId];
          if (queue == null || queue.isEmpty) continue;
          final block = queue.first;
          if (dailyMinutes + block.durationMinutes <= _kMaxMinutesPerDay) {
            final startHour = _kWorkStartHour + (dailyMinutes / 60.0);
            schedule.putIfAbsent(dateKey, () => []).add(_ScheduledBlock(
                  id: _nextBlockId(),
                  taskId: block.taskId,
                  durationMinutes: block.durationMinutes,
                  startHour: startHour,
                ));
            dailyMinutes += block.durationMinutes;
            queue.removeAt(0);
            addedSomethingInPass = true;
          }
        }
      }

      if (dailyMinutes == 0) {
        for (final taskId in orderedTaskIds) {
          final queue = taskBlocks[taskId];
          if (queue == null || queue.isEmpty) continue;
          final block = queue.removeAt(0);
          schedule.putIfAbsent(dateKey, () => []).add(_ScheduledBlock(
                id: _nextBlockId(),
                taskId: block.taskId,
                durationMinutes: block.durationMinutes,
                startHour: _kWorkStartHour,
              ));
          break;
        }
      }

      currentDate = currentDate.add(const Duration(days: 1));
      safetyCount++;
    }

    _globalSchedule = schedule;
  }

  /// Minutes of derived work for [taskId] on this calendar day (sum of block chunks).
  int minutesAllocatedOnDate(String taskId, DateTime date) {
    final dateKey = _formatDateKey(_onlyDate(date));
    return (_globalSchedule[dateKey] ?? const <_ScheduledBlock>[])
        .where((b) => b.taskId == taskId)
        .fold<int>(0, (a, b) => a + b.durationMinutes);
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
      _tasksMap.clear();
      _globalSchedule.clear();
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
        _tasksMap.clear();
        for (var doc in snapshot.docs) {
          try {
            final task = Task.fromDoc(doc);
            _tasksMap[task.id] = task;
          } catch (e) {
            print('❌ Skipping bad task doc ${doc.id}: $e');
          }
        }
        _isLoading = false;
        _error = null;
        _recomputeGlobalSchedule();
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
      throw StateError('User not logged in');
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

      print('✅ Task created: $taskId');
      print('🤖 AI planning triggered in background...');

      // Merge immediately so Home updates even if the snapshot stream lags or errors.
      final fresh = await _taskService.fetchTask(user.uid, taskId);
      if (fresh != null) {
        _tasksMap[taskId] = fresh;
        _recomputeGlobalSchedule();
        notifyListeners();
      }
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

    final prevTask = _tasksMap[id];
    if (prevTask == null) {
      throw Exception('Due not found');
    }
    final newCompletedState = !prevTask.completed;

    try {
      _error = null;
      _tasksMap[id] = prevTask.copyWith(
        completed: newCompletedState,
        completedAt: newCompletedState ? DateTime.now() : null,
      );
      _recomputeGlobalSchedule();
      notifyListeners();

      await _taskService.toggleComplete(user.uid, id, newCompletedState);
      // Stream will update _dues automatically
    } catch (e) {
      _tasksMap[id] = prevTask;
      _recomputeGlobalSchedule();
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // -------------------- SUBTASK TOGGLE --------------------
  /// Toggle completion for a single AI subtask (ai.subtasks[index]).
  /// This updates Firestore so progress and state stay in sync across devices.
  Future<void> toggleSubtask(String taskId, int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    final task = _getTask(taskId);
    final ai = task?.ai;
    if (task == null || ai == null) {
      return;
    }

    if (index < 0 || index >= ai.subtasks.length) {
      return;
    }

    try {
      _error = null;
      final updatedSubtasks = [...ai.subtasks];
      final current = updatedSubtasks[index];
      updatedSubtasks[index] = AISubtask(
        text: current.text,
        completed: !current.completed,
        scheduledDate: current.scheduledDate,
      );

      final aiMap = ai.toMap();
      aiMap['subtasks'] = updatedSubtasks.map((s) => s.toMap()).toList();

      await _taskService.updateAIData(
        uid: user.uid,
        taskId: taskId,
        ai: aiMap,
      );
      // Stream will refresh _tasksMap and _dues automatically
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // -------------------- MICROTASK TOGGLE (ai.schedule) --------------------
  Future<void> toggleMicrotask({
    required String taskId,
    required String date,
    required int index,
    required bool completed,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    final prevTask = _tasksMap[taskId];
    if (prevTask == null) return;
    final prevAiRaw = prevTask.aiRaw == null
        ? null
        : Map<String, dynamic>.from(prevTask.aiRaw!);
    final nextAiRaw = _updatedAiRawForMicrotask(
      task: prevTask,
      date: date,
      index: index,
      completed: completed,
    );

    try {
      _error = null;
      _tasksMap[taskId] = prevTask.copyWith(aiRaw: nextAiRaw);
      _recomputeGlobalSchedule();
      notifyListeners();

      await _taskService.toggleMicrotask(
        uid: user.uid,
        taskId: taskId,
        date: date,
        index: index,
        completed: completed,
      );
      // Stream will refresh _tasksMap and _dues automatically
    } catch (e) {
      _tasksMap[taskId] = prevTask.copyWith(aiRaw: prevAiRaw);
      _recomputeGlobalSchedule();
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // -------------------- CALENDAR FILTER --------------------
  List<DueTask> duesForDate(DateTime date) {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return dues.where((d) => sameDay(d.endDate, date)).toList();
  }

  /// Returns the global-scheduled work blocks for a specific date.
  /// Uses the multi-task load-balanced scheduler (CLAUDE.md algorithm).
  /// Falls back to AI-generated subtask labels when available.
  List<DailyScheduledTask> dailyScheduledTasksForDate(DateTime date) {
    final dateKey = _formatDateKey(_onlyDate(date));
    final globalEntries = _globalSchedule[dateKey] ?? [];

    final result = <DailyScheduledTask>[];
    for (final entry in globalEntries) {
      final task = _tasksMap[entry.taskId];
      if (task == null) continue;

      final dueTask = _taskToDueTask(task);

      // Use the Gemini AI subtask/microtasks for the date if available; else synthesize
      final aiData = task.aiScheduleData;
      final aiDaySchedule = aiData?.scheduleForDateKey(dateKey);
      final schedule = aiDaySchedule ??
          AiDaySchedule(
            date: dateKey,
            subtask: task.title,
            microtasks: [],
          );

      result.add(DailyScheduledTask(
        task: dueTask,
        schedule: schedule,
        blockDurationMinutes: entry.durationMinutes,
        blockStartHour: entry.startHour,
        blockId: entry.id,
      ));
    }
    return result;
  }

  /// One row per pending task for Home: aggregates all blocks that day; unique [blockId] per row.
  List<DailyScheduledTask> duesEntriesForDate(DateTime date) {
    final dateKey = _formatDateKey(_onlyDate(date));
    final blocks = _globalSchedule[dateKey] ?? const <_ScheduledBlock>[];
    final byTask = <String, List<_ScheduledBlock>>{};
    for (final b in blocks) {
      byTask.putIfAbsent(b.taskId, () => []).add(b);
    }

    final out = <DailyScheduledTask>[];
    for (final d in dues) {
      final list = byTask[d.id];
      final task = _tasksMap[d.id];
      if (task == null) continue;

      final aiData = task.aiScheduleData;
      final aiDay = aiData?.scheduleForDateKey(dateKey);
      final schedule = aiDay ??
          AiDaySchedule(
            date: dateKey,
            subtask: task.title,
            microtasks: [],
          );

      if (list == null || list.isEmpty) {
        out.add(DailyScheduledTask(
          task: d,
          schedule: schedule,
          blockDurationMinutes: 0,
          blockStartHour: _kWorkStartHour,
          blockId: 'agg_${d.id}_$dateKey',
        ));
        continue;
      }

      list.sort((a, b) => a.startHour.compareTo(b.startHour));
      final totalMins = list.fold<int>(0, (a, b) => a + b.durationMinutes);
      out.add(DailyScheduledTask(
        task: d,
        schedule: schedule,
        blockDurationMinutes: totalMins,
        blockStartHour: list.first.startHour,
        blockId: 'agg_${d.id}_$dateKey',
      ));
    }
    out.sort((a, b) => a.task.endDate.compareTo(b.task.endDate));
    return out;
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
    final active = dues.where((d) => !d.isDone).toList();

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

  // Pressure is derived from single source of truth (_tasksMap).
  // Formula: total_required_time / total_available_time_until_deadlines
  // pressure = total_remaining_hours / (days_left * MAX_HOURS_PER_DAY)  — CLAUDE.md
  int pressureScoreFollowPlan({int horizonDays = 7, int dailyCapacityMinutes = 180}) {
    const maxHoursPerDay = _kMaxMinutesPerDay / 60.0;
    final today = _onlyDate(DateTime.now());
    final active = _activeTasks();
    if (active.isEmpty) return 0;

    double totalRemainingHours = 0.0;
    DateTime? latestDeadline;

    for (final task in active) {
      totalRemainingHours += _remainingMinutesForTask(task) / 60.0;
      if (task.dueDate != null) {
        final d = _onlyDate(task.dueDate!);
        if (latestDeadline == null || d.isAfter(latestDeadline)) latestDeadline = d;
      }
    }

    final daysLeft = latestDeadline != null
        ? (_daysInclusive(today, latestDeadline)).clamp(1, 365)
        : horizonDays;

    final pressure = totalRemainingHours / (daysLeft * maxHoursPerDay);
    return (pressure * 100).clamp(0, 100).round();
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

  // risk(task) = task.remaining_hours / hours_left_until_deadline  — CLAUDE.md
  int riskScore() {
    final today = _onlyDate(DateTime.now());
    final active = _activeTasks();
    if (active.isEmpty) return 0;

    double totalRisk = 0.0;
    int count = 0;

    for (final task in active) {
      if (task.dueDate == null) continue;
      final deadline = _onlyDate(task.dueDate!);
      final hoursUntilDeadline =
          deadline.difference(today).inHours.toDouble().clamp(1.0, double.maxFinite);
      final remainingHours = _remainingMinutesForTask(task) / 60.0;
      totalRisk += (remainingHours / hoursUntilDeadline) * _priorityWeight(task.priority);
      count++;
    }

    if (count == 0) return 0;
    final avgRisk = totalRisk / count;
    return (avgRisk * 100).clamp(0, 100).round();
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

    for (final d in dues) {
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
    // Use the new schedule-based streak calculation
    return currentStreak;
  }

  // ============================================================
  // ✅ ANALYTICS GETTERS (for Dashboard)
  // ============================================================

  /// Returns map of 'YYYY-MM-DD' -> total minutes worked that day, last 90 days
  Map<String, int> get heatmapData {
    final map = <String, int>{};
    final today = DateTime.now();
    for (int i = 0; i < 90; i++) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      map[key] = 0;
    }
    // Aggregate from all tasks using schedule-based microtask completion
    for (final task in _tasksMap.values) {
      for (final date in task.datesWorked) {
        if (map.containsKey(date)) {
          map[date] = (map[date] ?? 0) + task.minutesWorkedOn(date);
        }
      }
    }
    // Also include old-style completed tasks (fallback)
    for (final d in dues) {
      if (d.isDone && d.completedAt != null) {
        final day = _onlyDate(d.completedAt!);
        final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        if (map.containsKey(key)) {
          map[key] = (map[key] ?? 0) + (d.durationMinutes ?? 0);
        }
      }
    }
    return map;
  }

  /// Returns list of {date, minutes} for last 30 days, sorted oldest first
  List<Map<String, dynamic>> get workRhythmData {
    final heatmap = heatmapData;
    final today = DateTime.now();
    return List.generate(30, (i) {
      final d = today.subtract(Duration(days: 29 - i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return {'date': key, 'minutes': heatmap[key] ?? 0};
    });
  }

  /// Current streak: consecutive days with at least one completed microtask
  int get currentStreak {
    final today = DateTime.now();
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final minutes = heatmapData[key] ?? 0;
      if (minutes > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Consistency score: days worked in last 7 days / 7
  double get consistencyScore {
    final today = DateTime.now();
    int daysWorked = 0;
    for (int i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if ((heatmapData[key] ?? 0) > 0) daysWorked++;
    }
    return daysWorked / 7;
  }

  /// Completed tasks count (using microtask completion)
  int get completedTasksCount {
    return _tasksMap.values.where((t) => t.isDoneFromMicrotasks || t.completed).length;
  }

  /// Remaining tasks count
  int get remainingTasksCount {
    return _tasksMap.values.where((t) => !t.isDoneFromMicrotasks && !t.completed).length;
  }

  /// Today's workload in minutes (from schedule)
  int get todayWorkloadMinutes {
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return _tasksMap.values.fold(0, (sum, t) => sum + t.minutesWorkedOn(key));
  }

  /// Average daily minutes over last 30 days
  double get averageDailyMinutes {
    final total = workRhythmData.fold<int>(
        0, (sum, d) => sum + (d['minutes'] as int));
    return total / 30;
  }

  /// Returns map of 'YYYY-MM-DD' -> minutes worked for a specific month
  Map<String, int> heatmapForMonth(int year, int month) {
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final map = <String, int>{};

    for (int d = 1; d <= daysInMonth; d++) {
      final key =
          '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      map[key] = 0;
    }

    // Aggregate minutes from all tasks using schedule data
    for (final task in _tasksMap.values) {
      for (final date in task.datesWorked) {
        if (map.containsKey(date)) {
          map[date] = (map[date] ?? 0) + task.minutesWorkedOn(date);
        }
      }
    }

    // Fallback: also include old-style completion dates
    for (final d in dues) {
      if (d.isDone && d.completedAt != null) {
        final c = _onlyDate(d.completedAt!);
        if (c.year == year && c.month == month) {
          final key =
              '$year-${month.toString().padLeft(2, '0')}-${c.day.toString().padLeft(2, '0')}';
          if (map.containsKey(key)) {
            map[key] = (map[key] ?? 0) + (d.durationMinutes ?? 0);
          }
        }
      }
    }

    return map;
  }

  // ============================================================
  // ✅ HEATMAP (last 28 days) - Legacy method for backward compatibility
  // ============================================================

  // returns list of 28 values (0..4 intensity)
  List<int> heatmapLast28Days() {
    final heatmap = heatmapData;
    final today = DateTime.now();
    final List<int> intensity = [];

    for (int i = 27; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final mins = heatmap[key] ?? 0;

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
  String _formatDateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime d) {
    final only = _onlyDate(d);
    final diff = only.weekday - DateTime.monday;
    return only.subtract(Duration(days: diff));
  }

  int _daysInclusive(DateTime start, DateTime end) {
    final s = _onlyDate(start);
    final e = _onlyDate(end);
    return (e.isBefore(s)) ? 1 : (e.difference(s).inDays + 1);
  }

  List<Task> _activeTasks() {
    return _tasksMap.values
        .where((t) => !t.isDoneFromMicrotasks && !t.completed)
        .toList();
  }

  int _remainingMinutesForTask(Task task) {
    if (task.ai != null && task.ai!.remainingMinutes > 0) {
      return task.ai!.remainingMinutes;
    }
    final estimated = task.estimatedMinutes ?? task.ai?.estimatedMinutes ?? 60;
    final worked = task.minutesWorked;
    final remaining = estimated - worked;
    return remaining > 0 ? remaining : 0;
  }

  double _priorityWeight(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 1.5;
      case 'medium':
        return 1.0;
      case 'low':
        return 0.7;
      default:
        return 1.0;
    }
  }

  Map<String, dynamic> _updatedAiRawForMicrotask({
    required Task task,
    required String date,
    required int index,
    required bool completed,
  }) {
    final raw = task.aiRaw == null ? <String, dynamic>{} : Map<String, dynamic>.from(task.aiRaw!);
    final schedule = List<dynamic>.from((raw['schedule'] ?? const []) as List);
    for (int i = 0; i < schedule.length; i++) {
      final day = Map<String, dynamic>.from(schedule[i] as Map);
      if (day['date'] != date) continue;
      final microtasks = List<dynamic>.from((day['microtasks'] ?? const []) as List);
      if (index < 0 || index >= microtasks.length) break;
      final mt = Map<String, dynamic>.from(microtasks[index] as Map);
      mt['completed'] = completed;
      microtasks[index] = mt;
      day['microtasks'] = microtasks;
      schedule[i] = day;
      break;
    }
    raw['schedule'] = schedule;
    return raw;
  }
}
