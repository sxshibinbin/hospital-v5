import 'package:dio/dio.dart';

import '../providers/auth_provider.dart';
import 'api_service.dart';

class HighFreqQuestion {
  final int id;
  final String question;
  final String answerTemplate;
  final String? category;
  final bool isTop;
  final int clickCount;

  HighFreqQuestion({
    required this.id,
    required this.question,
    required this.answerTemplate,
    this.category,
    required this.isTop,
    required this.clickCount,
  });

  factory HighFreqQuestion.fromJson(Map<String, dynamic> json) {
    return HighFreqQuestion(
      id: json['id'] as int,
      question: json['question'] as String,
      answerTemplate: json['answer_template'] as String,
      category: json['category'] as String?,
      isTop: json['is_top'] as bool,
      clickCount: json['click_count'] as int,
    );
  }
}

class QuestionService {
  final ApiService _apiService;

  QuestionService({AuthProvider? authProvider})
      : _apiService = ApiService();

  Future<List<HighFreqQuestion>> getPublicQuestions() async {
    try {
      final response = await _apiService.dio.get('/api/public/questions');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => HighFreqQuestion.fromJson(json)).toList();
      }
      throw Exception('Failed to load high frequency questions');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> recordClick(int questionId) async {
    try {
      await _apiService.dio.post('/api/public/questions/$questionId/click');
    } catch (e) {
      // Fire and forget, don't throw if recording click fails
    }
  }
}
