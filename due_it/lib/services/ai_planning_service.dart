import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Service to interact with the AI planning backend
/// 
/// This service calls the FastAPI backend to get AI-powered task planning.
class AIPlanningService {
  // Backend URL - Cloud Run deployment
  static const String baseUrl = 'https://due-it-ai-282811844705.asia-south1.run.app';

  /// Get Firebase ID token for authentication
  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    try {
      return await user.getIdToken();
    } catch (e) {
      print('❌ Error getting ID token: $e');
      return null;
    }
  }

  /// Call backend to plan a task using AI
  /// 
  /// This will:
  /// 1. Use Gemini to estimate task duration
  /// 2. Calculate pressure and risk scores
  /// 3. Update the task in Firestore with AI data
  /// 
  /// Returns true if successful, false otherwise
  Future<bool> planTask(String taskId) async {
    final token = await _getIdToken();
    if (token == null) {
      print('❌ No auth token available');
      return false;
    }

    try {
      final url = Uri.parse('$baseUrl/plan-task');
      
      print('🤖 Calling AI planning API for task: $taskId');
      print('   URL: $url');

      // Backend expects taskId as query parameter and authorization header
      final urlWithParams = Uri.parse('$baseUrl/plan-task?taskId=$taskId');
      
      final response = await http.post(
        urlWithParams,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ AI planning successful: $data');
        return true;
      } else {
        print('❌ AI planning failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error calling AI planning API: $e');
      return false;
    }
  }

  /// Health check to verify backend is accessible
  Future<bool> checkHealth() async {
    try {
      final url = Uri.parse('$baseUrl/health');
      final response = await http.post(url).timeout(
        const Duration(seconds: 10),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Health check failed: $e');
      return false;
    }
  }
}

