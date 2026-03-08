import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  factory Task.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      ai: data['ai'] != null 
          ? AIPlanningData.fromMap(data['ai'] as Map<String, dynamic>)
          : null,
    );
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
      lastPlannedAt: map['lastPlannedAt'] != null
          ? (map['lastPlannedAt'] is Timestamp
              ? (map['lastPlannedAt'] as Timestamp).toDate()
              : DateTime.parse(map['lastPlannedAt'].toString()))
          : null,
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

