import 'package:flutter/material.dart';

import '../services/question_service.dart';

class HotQuestionsProvider extends ChangeNotifier {
  final QuestionService _questionService;
  List<HighFreqQuestion> _questions = [];
  bool _isLoading = false;
  String? _error;

  HotQuestionsProvider({required QuestionService questionService})
      : _questionService = questionService {
    fetchQuestions();
  }

  List<HighFreqQuestion> get questions => _questions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchQuestions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _questions = await _questionService.getPublicQuestions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void recordClick(int questionId) {
    _questionService.recordClick(questionId);
  }
}
