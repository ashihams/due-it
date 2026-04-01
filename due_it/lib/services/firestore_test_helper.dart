import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

/// Helper class to test and verify Firestore operations
/// 
/// Use this to verify that data is being stored correctly in Firestore.
class FirestoreTestHelper {
  final FirestoreService _service = FirestoreService();

  /// Test creating a task and verify it exists
  /// 
  /// Returns a map with test results
  Future<Map<String, dynamic>> testCreateTask() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'success': false,
        'error': 'No user logged in',
      };
    }

    try {
      // Create a test task
      final taskId = await _service.createTask(
        uid: user.uid,
        title: '🧪 Test Task - ${DateTime.now().toString()}',
        description: 'This is a test task to verify Firestore is working',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: 'high',
      );

      // Wait a moment for Firestore to process
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify the task exists
      final taskDoc = await _service.getTask(user.uid, taskId);
      
      if (taskDoc.exists) {
        final data = taskDoc.data() as Map<String, dynamic>;
        return {
          'success': true,
          'taskId': taskId,
          'data': data,
          'message': '✅ Task created and verified in Firestore!',
          'path': 'users/${user.uid}/tasks/$taskId',
        };
      } else {
        return {
          'success': false,
          'error': 'Task was created but not found',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get all tasks for current user (for verification)
  Future<Map<String, dynamic>> testGetTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'success': false,
        'error': 'No user logged in',
      };
    }

    try {
      final snapshot = await _service.tasksRef(user.uid).get();
      final tasks = snapshot.docs.map((doc) => {
        'id': doc.id,
        'data': doc.data(),
      }).toList();

      return {
        'success': true,
        'count': tasks.length,
        'tasks': tasks,
        'message': '✅ Found ${tasks.length} task(s) in Firestore',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Test user document creation
  Future<Map<String, dynamic>> testCreateUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'success': false,
        'error': 'No user logged in',
      };
    }

    try {
      await _service.createOrUpdateUser(
        uid: user.uid,
        email: user.email ?? 'unknown@example.com',
      );

      await Future.delayed(const Duration(milliseconds: 500));

      final userDoc = await _service.getUser(user.uid);
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return {
          'success': true,
          'data': data,
          'message': '✅ User document created in Firestore!',
          'path': 'users/${user.uid}',
        };
      } else {
        return {
          'success': false,
          'error': 'User document was created but not found',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Print current Firestore structure (for debugging)
  Future<void> printFirestoreStructure() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    print('\n📊 Firestore Structure for user: ${user.uid}');
    print('=' * 60);

    // Check user document
    final userDoc = await _service.getUser(user.uid);
    if (userDoc.exists) {
      print('✅ User document exists: users/${user.uid}');
      print('   Data: ${userDoc.data()}');
    } else {
      print('❌ User document does NOT exist: users/${user.uid}');
    }

    // Check tasks
    final tasksSnapshot = await _service.tasksRef(user.uid).get();
    print('\n📝 Tasks subcollection: users/${user.uid}/tasks');
    print('   Count: ${tasksSnapshot.docs.length}');

    for (var doc in tasksSnapshot.docs) {
      print('   - Task ID: ${doc.id}');
      print('     Data: ${doc.data()}');
    }

    print('=' * 60);
  }
}

