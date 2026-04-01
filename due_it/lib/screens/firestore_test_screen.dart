import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_test_helper.dart';

/// Test screen to verify Firestore is working
/// 
/// This screen helps you verify that data is being stored in Firestore.
/// You can access it temporarily to test your Firestore setup.
class FirestoreTestScreen extends StatefulWidget {
  const FirestoreTestScreen({super.key});

  @override
  State<FirestoreTestScreen> createState() => _FirestoreTestScreenState();
}

class _FirestoreTestScreenState extends State<FirestoreTestScreen> {
  final FirestoreTestHelper _helper = FirestoreTestHelper();
  String _status = 'Ready to test';
  bool _isLoading = false;
  Map<String, dynamic>? _lastResult;

  Future<void> _testCreateTask() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating test task...';
    });

    final result = await _helper.testCreateTask();
    
    setState(() {
      _isLoading = false;
      _lastResult = result;
      _status = result['message'] ?? result['error'] ?? 'Unknown result';
    });

    // Also print to console
    print('\n🧪 TEST RESULT:');
    print(result);
    if (result['success'] == true) {
      print('✅ Task stored at: ${result['path']}');
      print('📋 Task data: ${result['data']}');
    }
  }

  Future<void> _testGetTasks() async {
    setState(() {
      _isLoading = true;
      _status = 'Fetching tasks...';
    });

    final result = await _helper.testGetTasks();
    
    setState(() {
      _isLoading = false;
      _lastResult = result;
      _status = result['message'] ?? result['error'] ?? 'Unknown result';
    });

    print('\n🧪 GET TASKS RESULT:');
    print(result);
  }

  Future<void> _testCreateUser() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating user document...';
    });

    final result = await _helper.testCreateUser();
    
    setState(() {
      _isLoading = false;
      _lastResult = result;
      _status = result['message'] ?? result['error'] ?? 'Unknown result';
    });

    print('\n🧪 CREATE USER RESULT:');
    print(result);
  }

  Future<void> _printStructure() async {
    await _helper.printFirestoreStructure();
    setState(() {
      _status = 'Structure printed to console (check debug output)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Firestore Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current User:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(user?.email ?? 'Not logged in'),
                    Text(
                      'UID: ${user?.uid ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_isLoading) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testCreateUser,
              icon: const Icon(Icons.person_add),
              label: const Text('Test: Create User Document'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testCreateTask,
              icon: const Icon(Icons.add_task),
              label: const Text('Test: Create Task'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testGetTasks,
              icon: const Icon(Icons.list),
              label: const Text('Test: Get All Tasks'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _printStructure,
              icon: const Icon(Icons.print),
              label: const Text('Print Structure to Console'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 How to Verify:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Click "Test: Create Task"'),
                    const Text('2. Check the status message'),
                    const Text('3. Open Firebase Console:'),
                    const Text(
                      '   https://console.firebase.google.com',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const Text('4. Go to Firestore Database'),
                    const Text('5. Look for: users/{uid}/tasks/{taskId}'),
                    const SizedBox(height: 8),
                    const Text(
                      '💡 Tip: Check the debug console for detailed output!',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),

            // Last result
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  color: Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last Result:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _lastResult.toString(),
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

