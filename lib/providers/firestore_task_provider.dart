import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';
import '../services/task_service.dart';

/// Task provider for Firestore-based tasks
/// 
/// This provider manages task state and Firestore operations.
/// UI should use this provider, not TaskService directly.
class FirestoreTaskProvider with ChangeNotifier {
  final TaskService _service = TaskService();
  String? _error;

  String? get error => _error;

  /// Get tasks stream (real-time)
  /// 
  /// Returns a stream that automatically updates when tasks change in Firestore.
  Stream<List<Task>> tasksStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _service.getTasks(user.uid).map(
      (snapshot) => snapshot.docs
          .map((doc) => Task.fromDoc(doc))
          .toList(),
    );
  }

  /// Add a new task (AI-ready)
  Future<void> addTask({
    required String title,
    String description = '',
    DateTime? dueDate,
    String priority = 'medium',
    int? estimatedMinutes,
    String? category,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      await _service.addTask(
        uid: user.uid,
        title: title,
        description: description,
        dueDate: dueDate,
        priority: priority,
        estimatedMinutes: estimatedMinutes,
        category: category,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Toggle task completion
  Future<void> toggleTask(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      await _service.toggleComplete(user.uid, task.id, !task.completed);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a task
  Future<void> deleteTask(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      await _service.deleteTask(user.uid, task.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update task
  Future<void> updateTask({
    required Task task,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    int? estimatedMinutes,
    String? category,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      await _service.updateTask(
        uid: user.uid,
        taskId: task.id,
        title: title,
        description: description,
        dueDate: dueDate,
        priority: priority,
        estimatedMinutes: estimatedMinutes,
        category: category,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}

