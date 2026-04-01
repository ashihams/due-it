import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import 'ai_planning_service.dart';
import 'notion_service.dart';

/// Task service for Firestore CRUD operations
/// 
/// This service handles all task-related Firestore operations.
/// Keeps UI separate from Firestore implementation.
class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AIPlanningService _aiService = AIPlanningService();
  final NotionService _notionService = NotionService();

  /// Get reference to user's tasks collection
  /// CRITICAL: Always use the authenticated user's UID to scope queries
  CollectionReference tasksRef(String uid) {
    if (uid.isEmpty) {
      throw Exception('UID cannot be empty - user must be authenticated');
    }
    return _db.collection('users').doc(uid).collection('tasks');
  }

  /// Add a new task (AI-ready schema)
  /// 
  /// After creating the task, automatically triggers AI planning
  /// CRITICAL: Task is created under users/{uid}/tasks/{taskId}
  Future<String> addTask({
    required String uid,
    required String title,
    String description = '',
    DateTime? dueDate,
    String priority = 'medium',
    int? estimatedMinutes,
    String? category,
  }) async {
    if (uid.isEmpty) {
      throw Exception('UID cannot be empty - user must be authenticated');
    }
    print('➕ Creating task for user: $uid');
    print('   Title: $title');
    // Create task in Firestore
    final docRef = await tasksRef(uid).add({
      'title': title,
      'description': description,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'priority': priority, // 'low', 'medium', 'high'
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
      // AI-friendly fields
      'estimatedMinutes': estimatedMinutes,
      'category': category, // 'work', 'study', 'personal', etc.
    });

    final taskId = docRef.id;
    
    // Always trigger AI planning if task has a deadline and description
    // AI will estimate duration based on description
    if (dueDate != null && description.isNotEmpty) {
      print('🤖 Triggering AI planning for task: $taskId');
      print('   Title: $title');
      print('   Description: $description');
      print('   Deadline: $dueDate');
      
      _aiService.planTask(taskId).then((success) {
        if (success) {
          print('✅ AI planning completed for task: $taskId');
          print('   Duration estimated by Gemini AI');
          // Non-blocking: generate the Notion launchpad doc after AI plan is ready.
          // Schedule is passed as [] — the backend reads it from Firestore directly.
          print('🟡 planTask completed, taskId: $taskId');
          print('🟡 calling generateDoc now');
          unawaited(_notionService.generateDoc(
            taskId: taskId,
            title: title,
            deadline: dueDate.toIso8601String().split('T')[0],
            schedule: [],
            category: category ?? 'work',
          ));
        } else {
          print('⚠️ AI planning failed for task: $taskId');
          print('   Will use fallback duration if provided');
        }
      }).catchError((error) {
        print('❌ Error in AI planning: $error');
        print('   Task created but AI planning failed');
      });
    } else {
      print('⚠️ Skipping AI planning: task needs deadline and description');
    }

    return taskId;
  }

  /// Get tasks stream (real-time updates)
  /// CRITICAL: Only returns tasks for the specified user UID
  Stream<QuerySnapshot> getTasks(String uid) {
    if (uid.isEmpty) {
      throw Exception('UID cannot be empty - user must be authenticated');
    }
    print('📋 Querying tasks for user: $uid');
    print('   Firestore path: users/$uid/tasks');
    return tasksRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Fetch one task document by id for immediate UI merge.
  Future<Task?> fetchTask(String uid, String taskId) async {
    if (uid.isEmpty) {
      throw Exception('UID cannot be empty - user must be authenticated');
    }
    final doc = await tasksRef(uid).doc(taskId).get();
    if (!doc.exists) return null;
    return Task.fromDoc(doc);
  }

  /// Toggle task completion status
  Future<void> toggleComplete(String uid, String taskId, bool value) async {
    final updates = <String, dynamic>{
      'completed': value,
    };
    
    if (value) {
      updates['completedAt'] = FieldValue.serverTimestamp();
    } else {
      updates['completedAt'] = FieldValue.delete();
    }

    await tasksRef(uid).doc(taskId).update(updates);
  }

  /// Delete a task
  Future<void> deleteTask(String uid, String taskId) async {
    await tasksRef(uid).doc(taskId).delete();
  }

  /// Update task
  Future<void> updateTask({
    required String uid,
    required String taskId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    int? estimatedMinutes,
    String? category,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (dueDate != null) {
      updates['dueDate'] = Timestamp.fromDate(dueDate);
    } else if (dueDate == null && updates.containsKey('dueDate')) {
      updates['dueDate'] = FieldValue.delete();
    }
    if (priority != null) updates['priority'] = priority;
    if (estimatedMinutes != null) updates['estimatedMinutes'] = estimatedMinutes;
    if (category != null) updates['category'] = category;

    if (updates.isNotEmpty) {
      await tasksRef(uid).doc(taskId).update(updates);
    }
  }

  /// Update AI data blob for a task (used for subtask completion updates)
  /// Keeps backend schema intact by updating only the `ai` field.
  Future<void> updateAIData({
    required String uid,
    required String taskId,
    required Map<String, dynamic> ai,
  }) async {
    if (uid.isEmpty) {
      throw Exception('UID cannot be empty - user must be authenticated');
    }
    await tasksRef(uid).doc(taskId).update({
      'ai': ai,
    });
  }

  /// Explicitly trigger AI planning for a task (FastAPI /plan-task).
  /// This is a thin wrapper around the existing AIPlanningService.
  Future<void> planTask(String taskId) async {
    try {
      await _aiService.planTask(taskId);
    } catch (e) {
      // Keep silent failures from breaking UI flows
      print('planTask error: $e');
    }
  }

  /// Toggle a microtask inside `ai.schedule[*].microtasks[index]` for a given date.
  /// Persists the completion state back to Firestore.
  Future<void> toggleMicrotask({
    required String uid,
    required String taskId,
    required String date,
    required int index,
    required bool completed,
  }) async {
    final ref = tasksRef(uid).doc(taskId);
    final snap = await ref.get();
    final data = snap.data() as Map<String, dynamic>?;
    final aiMap = Map<String, dynamic>.from((data?['ai'] ?? {}) as Map);
    final schedList = List<dynamic>.from((aiMap['schedule'] ?? []) as List);

    for (int i = 0; i < schedList.length; i++) {
      final day = Map<String, dynamic>.from(schedList[i] as Map);
      if (day['date'] == date) {
        final microtasks = List<dynamic>.from((day['microtasks'] ?? []) as List);
        if (index < microtasks.length) {
          final mt = Map<String, dynamic>.from(microtasks[index] as Map);
          mt['completed'] = completed;
          microtasks[index] = mt;
        }
        day['microtasks'] = microtasks;
        schedList[i] = day;
        break;
      }
    }

    aiMap['schedule'] = schedList;
    await ref.update({'ai': aiMap});
  }
}

