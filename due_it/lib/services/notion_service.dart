import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Syncs tasks with Notion via the Cloud Run backend.
/// All methods return void and swallow errors — Notion failures
/// never crash or block the main app flow.
class NotionService {
  static const String _baseUrl =
      'https://due-it-ai-282811844705.asia-south1.run.app';

  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken();
    } catch (e) {
      print('❌ NotionService: error getting ID token: $e');
      return null;
    }
  }

  /// GET /notion-auth-url — returns the Notion OAuth URL to open in browser.
  Future<String?> getNotionAuthUrl(String uid) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/notion-auth-url?uid=$uid'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['auth_url'] as String?;
      } else {
        print('❌ NotionService: getNotionAuthUrl ${response.statusCode} — ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ NotionService: getNotionAuthUrl error: $e');
      return null;
    }
  }

  /// DELETE /disconnect-notion — revokes Notion access for this user.
  Future<bool> disconnectNotion(String uid) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/disconnect-notion'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': uid}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('✅ NotionService: disconnectNotion succeeded');
        return true;
      } else {
        print('❌ NotionService: disconnectNotion ${response.statusCode} — ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ NotionService: disconnectNotion error: $e');
      return false;
    }
  }

  /// POST /generate-doc — creates Notion launchpad / doc for a planned task.
  Future<void> generateDoc({
    required String taskId,
    required String title,
    required String deadline,
    required List<dynamic> schedule,
    String category = 'personal',
  }) async {
    print('🔵 generateDoc CALLED taskId: $taskId uid: ${FirebaseAuth.instance.currentUser?.uid}');
    print('🔵 generateDoc URL: $_baseUrl/generate-doc');
    final token = await _getIdToken();
    if (token == null) {
      print('DEBUG: generateDoc skipped — no ID token');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final body = jsonEncode({
      'taskId': taskId,
      'title': title,
      'deadline': deadline,
      'schedule': schedule,
      'category': category,
      'uid': uid,
    });
    print('DEBUG: calling /generate-doc with body: $body');
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/generate-doc'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode >= 400) {
        print('❌ NotionService: generateDoc ${response.statusCode} — ${response.body}');
      } else {
        print('✅ NotionService: generateDoc OK ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('🔴 generateDoc ERROR: $e');
      print('🔴 generateDoc STACK: $stackTrace');
    }
  }

  /// POST /sync-task-complete — syncs task completion status to Notion.
  Future<void> syncTaskComplete(String taskId) async {
    final token = await _getIdToken();
    if (token == null) return;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/sync-task-complete?taskId=$taskId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('✅ NotionService: syncTaskComplete succeeded for $taskId');
      } else {
        print('❌ NotionService: syncTaskComplete ${response.statusCode} — ${response.body}');
      }
    } catch (e) {
      print('❌ NotionService: syncTaskComplete error: $e');
    }
  }

  /// Stream of users/{uid} Firestore doc — watches notionConnected / notionWorkspace changes.
  Stream<DocumentSnapshot<Map<String, dynamic>>> notionStatusStream(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }
}
