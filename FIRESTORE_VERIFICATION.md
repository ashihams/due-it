# 🔍 How to Verify Firestore is Storing Data

## Method 1: Use the Test Screen (Easiest)

1. **Add the test screen to your app temporarily:**

```dart
// In your app.dart or any screen, add a button:
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const FirestoreTestScreen()),
);
```

2. **Run the app and click "Test: Create Task"**
3. **Check the status message** - it will tell you if it worked
4. **Check the debug console** - you'll see detailed logs

## Method 2: Check Firebase Console (Visual Verification)

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com
   - Select your project: `due-it-16c4a`

2. **Navigate to Firestore Database:**
   - Click "Firestore Database" in the left sidebar
   - You should see your data structure:

```
users (collection)
 └── {your-user-id} (document)
      ├── email: "your@email.com"
      ├── createdAt: [timestamp]
      └── tasks (subcollection)
           └── {task-id} (document)
                ├── title: "Your task title"
                ├── description: "..."
                ├── dueDate: [timestamp]
                ├── completed: false
                ├── priority: "medium"
                └── createdAt: [timestamp]
```

3. **Real-time updates:**
   - Data appears immediately when you create/update tasks
   - Refresh the console to see latest data

## Method 3: Check Debug Console Logs

When you use `FirestoreService`, it automatically logs operations:

```
✅ Firestore: Task created
   Path: users/{uid}/tasks/{taskId}
   Data: {title: "...", description: "...", ...}
```

Look for these logs in your Flutter debug console.

## Method 4: Programmatic Verification

Use the test helper in your code:

```dart
import 'package:due_it/services/firestore_test_helper.dart';

final helper = FirestoreTestHelper();

// Test creating a task
final result = await helper.testCreateTask();
print(result); // Shows success/failure and data

// Print full structure
await helper.printFirestoreStructure();
```

## Quick Test Code

Add this to any screen to test:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:due_it/services/firestore_service.dart';

// Get current user
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final service = FirestoreService();
  
  // Create a test task
  final taskId = await service.createTask(
    uid: user.uid,
    title: 'Test Task',
    description: 'Testing Firestore',
  );
  
  print('✅ Task created with ID: $taskId');
  
  // Verify it exists
  final task = await service.getTask(user.uid, taskId);
  if (task.exists) {
    print('✅ Task verified in Firestore!');
    print('Data: ${task.data()}');
  }
}
```

## What to Look For

✅ **Success indicators:**
- No errors in console
- Status messages show "✅ Task created"
- Data appears in Firebase Console
- Logs show the correct Firestore path

❌ **Failure indicators:**
- Error messages in console
- "Permission denied" errors (check Firestore rules)
- Network errors
- Data doesn't appear in console

## Troubleshooting

**If data doesn't appear:**
1. Check Firestore Security Rules (must allow read/write)
2. Check internet connection
3. Verify Firebase is initialized correctly
4. Check user is authenticated
5. Look for error messages in console

**Firestore Rules (for testing):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /tasks/{taskId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```







