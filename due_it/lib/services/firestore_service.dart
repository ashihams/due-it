import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore service for managing user data and tasks
/// 
/// This service provides a clean API layer for Firestore operations.
/// All data is organized under users/{uid}/tasks/{taskId} structure.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // ✅ REFERENCE HELPERS
  // ============================================================

  /// Reference to user document
  DocumentReference userRef(String uid) {
    return _db.collection('users').doc(uid);
  }

  /// Reference to user's tasks subcollection
  CollectionReference tasksRef(String uid) {
    return _db.collection('users').doc(uid).collection('tasks');
  }

  /// Reference to a specific task
  DocumentReference taskRef(String uid, String taskId) {
    return _db.collection('users').doc(uid).collection('tasks').doc(taskId);
  }

  // ============================================================
  // ✅ USER OPERATIONS
  // ============================================================

  /// Create or update user document
  Future<void> createOrUpdateUser({
    required String uid,
    required String email,
    Map<String, dynamic>? preferences,
  }) async {
    final userData = {
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'preferences': preferences ?? {
        'aiEnabled': true,
        'theme': 'dark',
      },
    };
    
    await userRef(uid).set(userData, SetOptions(merge: true));
    
    print('✅ Firestore: User document created/updated');
    print('   Path: users/$uid');
    print('   Data: $userData');
  }

  /// Get user document
  Future<DocumentSnapshot> getUser(String uid) async {
    return await userRef(uid).get();
  }

  // ============================================================
  // ✅ TASK OPERATIONS (CRUD)
  // ============================================================

  /// Create a new task
  /// 
  /// Creates a task in users/{uid}/tasks/{taskId}
  Future<String> createTask({
    required String uid,
    required String title,
    String description = '',
    DateTime? dueDate,
    String priority = 'medium',
  }) async {
    final taskData = {
      'title': title,
      'description': description,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'completed': false,
      'priority': priority, // 'low', 'medium', 'high'
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await tasksRef(uid).add(taskData);

    // Debug logging
    print('✅ Firestore: Task created');
    print('   Path: users/$uid/tasks/${docRef.id}');
    print('   Data: $taskData');

    return docRef.id;
  }

  /// Get tasks stream (real-time updates)
  /// 
  /// Returns a stream that automatically updates when tasks change.
  /// Ordered by createdAt descending (newest first).
  Stream<QuerySnapshot> getTasks(String uid) {
    return tasksRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get tasks stream filtered by completion status
  Stream<QuerySnapshot> getTasksByStatus(String uid, bool completed) {
    return tasksRef(uid)
        .where('completed', isEqualTo: completed)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get a single task
  Future<DocumentSnapshot> getTask(String uid, String taskId) async {
    return await taskRef(uid, taskId).get();
  }

  /// Update task completion status
  Future<void> completeTask(String uid, String taskId) async {
    await taskRef(uid, taskId).update({
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ Firestore: Task completed');
    print('   Path: users/$uid/tasks/$taskId');
  }

  /// Mark task as incomplete
  Future<void> uncompleteTask(String uid, String taskId) async {
    await taskRef(uid, taskId).update({
      'completed': false,
      'completedAt': FieldValue.delete(),
    });
  }

  /// Toggle task completion status
  Future<void> toggleTaskCompletion(String uid, String taskId) async {
    final taskDoc = await taskRef(uid, taskId).get();
    if (taskDoc.exists) {
      final data = taskDoc.data() as Map<String, dynamic>;
      final isCompleted = data['completed'] ?? false;
      
      if (isCompleted) {
        await uncompleteTask(uid, taskId);
      } else {
        await completeTask(uid, taskId);
      }
    }
  }

  /// Update task fields
  Future<void> updateTask({
    required String uid,
    required String taskId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
  }) async {
    final Map<String, dynamic> updates = {};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (dueDate != null) updates['dueDate'] = Timestamp.fromDate(dueDate);
    if (priority != null) updates['priority'] = priority;

    if (updates.isNotEmpty) {
      await taskRef(uid, taskId).update(updates);
    }
  }

  /// Delete a task
  Future<void> deleteTask(String uid, String taskId) async {
    await taskRef(uid, taskId).delete();
    
    print('✅ Firestore: Task deleted');
    print('   Path: users/$uid/tasks/$taskId');
  }

  /// Delete all completed tasks
  Future<void> deleteCompletedTasks(String uid) async {
    final completedTasks = await tasksRef(uid)
        .where('completed', isEqualTo: true)
        .get();

    final batch = _db.batch();
    for (var doc in completedTasks.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ============================================================
  // ✅ QUERY HELPERS
  // ============================================================

  /// Get tasks due on a specific date
  Stream<QuerySnapshot> getTasksByDate(String uid, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return tasksRef(uid)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('dueDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('dueDate')
        .snapshots();
  }

  /// Get tasks by priority
  Stream<QuerySnapshot> getTasksByPriority(String uid, String priority) {
    return tasksRef(uid)
        .where('priority', isEqualTo: priority)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get overdue tasks
  Stream<QuerySnapshot> getOverdueTasks(String uid) {
    final now = Timestamp.now();
    return tasksRef(uid)
        .where('dueDate', isLessThan: now)
        .where('completed', isEqualTo: false)
        .orderBy('dueDate')
        .snapshots();
  }
}

