import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_schedule_model.dart';

/// Task model - AI-ready structure
/// 
/// All fields are consistent and predictable for AI queries.
class Task {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final bool completed;
  final String priority; // 'low', 'medium', 'high'
  final DateTime? createdAt;
  final DateTime? completedAt; // When task was completed
  
  // AI-friendly fields
  final int? estimatedMinutes; // Estimated time to complete
  final String? category; // 'work', 'study', 'personal', etc.
  
  // AI planning data (from backend)
  final AIPlanningData? ai;
  // Raw ai map for schedule parsing (ai.schedule)
  final Map<String, dynamic>? aiRaw;

  // Notion launchpad page URL (written by backend and/or Flutter NotionService)
  final String? notionPageUrl;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
    required this.priority,
    this.dueDate,
    this.createdAt,
    this.completedAt,
    this.estimatedMinutes,
    this.category,
    this.ai,
    this.aiRaw,
    this.notionPageUrl,
  });

  factory Task.fromDoc(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      throw FormatException('Task ${doc.id} has no document data');
    }
    final data = Map<String, dynamic>.from(raw as Map);
    final rawAi = data['ai'];
    Map<String, dynamic>? aiRaw;
    AIPlanningData? ai;
    if (rawAi != null && rawAi is Map) {
      aiRaw = Map<String, dynamic>.from(rawAi);
      try {
        ai = AIPlanningData.fromMap(aiRaw);
      } catch (e) {
        // Bad `ai` blob must not drop the whole task list — keep raw for schedule UI.
        ai = null;
      }
    }
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      completed: data['completed'] ?? false,
      priority: data['priority'] ?? 'medium',
      dueDate: data['dueDate'] != null 
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      estimatedMinutes: data['estimatedMinutes'] != null
          ? (data['estimatedMinutes'] as num).toInt()
          : null,
      category: data['category'] as String?,
      ai: ai,
      aiRaw: aiRaw,
      // Read from Flutter-written field first, fall back to backend-written field
      notionPageUrl: (data['notionPageUrl'] ?? data['notionLaunchpadUrl']) as String?,
    );
  }

  /// Parsed schedule data written by backend under `ai.schedule`
  TaskAiData? get aiScheduleData {
    final raw = aiRaw;
    if (raw == null) return null;
    try {
      return TaskAiData.fromMap(raw);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // ✅ ANALYTICS COMPUTED GETTERS (for Dashboard)
  // ============================================================

  /// Total number of microtasks across all schedule days
  int get totalMicrotasks {
    final sched = aiRaw?['schedule'] as List<dynamic>? ?? [];
    return sched.fold(0, (sum, day) {
      final mts = (day as Map<String, dynamic>)['microtasks'] as List<dynamic>? ?? [];
      return sum + mts.length;
    });
  }

  /// Number of completed microtasks across all schedule days
  int get completedMicrotasks {
    final sched = aiRaw?['schedule'] as List<dynamic>? ?? [];
    return sched.fold(0, (sum, day) {
      final mts = (day as Map<String, dynamic>)['microtasks'] as List<dynamic>? ?? [];
      return sum + mts.where((m) => (m as Map<String, dynamic>)['completed'] == true).length;
    });
  }

  /// Task is done if all microtasks are completed (or if completed flag is true)
  bool get isDoneFromMicrotasks {
    if (completed) return true; // Respect explicit completed flag
    if (totalMicrotasks == 0) return false;
    return completedMicrotasks == totalMicrotasks;
  }

  /// Minutes worked = completedMicrotasks fraction of estimatedMinutes
  int get minutesWorked {
    final estimated = estimatedMinutes ?? (ai?.estimatedMinutes ?? 0);
    if (totalMicrotasks == 0) return 0;
    return ((completedMicrotasks / totalMicrotasks) * estimated).round();
  }

  /// Which dates had completed microtasks — returns set of 'YYYY-MM-DD' strings
  Set<String> get datesWorked {
    final sched = aiRaw?['schedule'] as List<dynamic>? ?? [];
    final dates = <String>{};
    for (final day in sched) {
      final dayMap = day as Map<String, dynamic>;
      final mts = dayMap['microtasks'] as List<dynamic>? ?? [];
      final hasCompleted = mts.any((m) => (m as Map<String, dynamic>)['completed'] == true);
      if (hasCompleted) {
        dates.add(dayMap['date'] as String? ?? '');
      }
    }
    return dates;
  }

  /// Minutes worked on a specific date (YYYY-MM-DD)
  int minutesWorkedOn(String date) {
    final sched = aiRaw?['schedule'] as List<dynamic>? ?? [];
    for (final day in sched) {
      final dayMap = day as Map<String, dynamic>;
      if (dayMap['date'] != date) continue;
      final mts = dayMap['microtasks'] as List<dynamic>? ?? [];
      final total = mts.length;
      if (total == 0) return 0;
      final done = mts.where((m) => (m as Map<String, dynamic>)['completed'] == true).length;
      final estimated = estimatedMinutes ?? (ai?.estimatedMinutes ?? 0);
      return ((done / total) * estimated).round();
    }
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'priority': priority,
      'completed': completed,
      'estimatedMinutes': estimatedMinutes,
      'category': category,
      if (ai != null) 'ai': ai!.toMap(),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? completed,
    String? priority,
    DateTime? createdAt,
    DateTime? completedAt,
    int? estimatedMinutes,
    String? category,
    AIPlanningData? ai,
    Map<String, dynamic>? aiRaw,
    String? notionPageUrl,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      category: category ?? this.category,
      ai: ai ?? this.ai,
      aiRaw: aiRaw ?? this.aiRaw,
      notionPageUrl: notionPageUrl ?? this.notionPageUrl,
    );
  }
}

/// Single AI subtask item stored under `ai.subtasks` in Firestore
class AISubtask {
  final String text;
  final bool completed;
  final DateTime? scheduledDate;

  AISubtask({
    required this.text,
    required this.completed,
    this.scheduledDate,
  });

  factory AISubtask.fromMap(Map<String, dynamic> map) {
    DateTime? scheduled;
    final raw = map['scheduledDate'];
    if (raw is Timestamp) {
      scheduled = raw.toDate();
    } else if (raw != null) {
      try {
        scheduled = DateTime.parse(raw.toString());
      } catch (_) {
        scheduled = null;
      }
    }

    return AISubtask(
      text: (map['text'] ?? '').toString(),
      completed: map['completed'] as bool? ?? false,
      scheduledDate: scheduled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'completed': completed,
      if (scheduledDate != null)
        'scheduledDate': Timestamp.fromDate(scheduledDate!),
    };
  }
}

/// AI Planning Data structure (from backend)
/// 
/// This matches the structure returned by the FastAPI backend
class AIPlanningData {
  final int estimatedMinutes;
  final int remainingMinutes;
  final int dailyRequiredMinutes;
  final double pressureScore;
  final double riskScore;
  final double confidence;
  final List<String> actionSteps; // AI-generated action steps
  final List<AISubtask> subtasks; // Scheduled daily subtasks
  final bool generated;
  final DateTime? lastPlannedAt;

  AIPlanningData({
    required this.estimatedMinutes,
    required this.remainingMinutes,
    required this.dailyRequiredMinutes,
    required this.pressureScore,
    required this.riskScore,
    required this.confidence,
    required this.actionSteps,
    required this.generated,
    this.subtasks = const [],
    this.lastPlannedAt,
  });

  static DateTime? _parseLastPlannedAt(dynamic v) {
    if (v == null) return null;
    try {
      if (v is Timestamp) return v.toDate();
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  factory AIPlanningData.fromMap(Map<String, dynamic> map) {
    // Handle actionSteps - could be List<String> or null
    List<String> steps = [];
    if (map['actionSteps'] != null) {
      final stepsData = map['actionSteps'];
      if (stepsData is List) {
        steps = stepsData.map((e) => e.toString()).toList();
      }
    }
    // Handle structured subtasks
    List<AISubtask> parsedSubtasks = [];
    if (map['subtasks'] != null && map['subtasks'] is List) {
      for (final item in (map['subtasks'] as List)) {
        if (item is Map<String, dynamic>) {
          parsedSubtasks.add(AISubtask.fromMap(item));
        } else if (item is Map) {
          parsedSubtasks.add(AISubtask.fromMap(
              item.map((key, value) => MapEntry(key.toString(), value))));
        }
      }
    }

    return AIPlanningData(
      estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt() ?? 0,
      remainingMinutes: (map['remainingMinutes'] as num?)?.toInt() ?? 0,
      dailyRequiredMinutes: (map['dailyRequiredMinutes'] as num?)?.toInt() ?? 0,
      pressureScore: (map['pressureScore'] as num?)?.toDouble() ?? 0.0,
      riskScore: (map['riskScore'] as num?)?.toDouble() ?? 0.0,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      actionSteps: steps,
      subtasks: parsedSubtasks,
      generated: map['generated'] as bool? ?? false,
      lastPlannedAt: _parseLastPlannedAt(map['lastPlannedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'estimatedMinutes': estimatedMinutes,
      'remainingMinutes': remainingMinutes,
      'dailyRequiredMinutes': dailyRequiredMinutes,
      'pressureScore': pressureScore,
      'riskScore': riskScore,
      'confidence': confidence,
      'actionSteps': actionSteps,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'generated': generated,
      if (lastPlannedAt != null)
        'lastPlannedAt': Timestamp.fromDate(lastPlannedAt!),
    };
  }
}

