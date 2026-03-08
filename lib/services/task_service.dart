import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_planning_service.dart';

/// Task service for Firestore CRUD operations
/// 
/// This service handles all task-related Firestore operations.
/// Keeps UI separate from Firestore implementation.
class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AIPlanningService _aiService = AIPlanningService();

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
}

