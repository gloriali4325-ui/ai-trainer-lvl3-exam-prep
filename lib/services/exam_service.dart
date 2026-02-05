import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_coach/models/exam_result.dart';
import 'package:ai_coach/models/question.dart';

class ExamService extends ChangeNotifier {
  static const String _resultsKey = 'exam_results';

  List<ExamResult> _examResults = [];
  bool _isLoading = false;

  List<ExamResult> get examResults => _examResults;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final resultsJson = prefs.getString(_resultsKey);

      if (resultsJson != null) {
        final List<dynamic> decoded = json.decode(resultsJson);
        _examResults = decoded.map((item) => ExamResult.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Failed to load exam results: $e');
      _examResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resultsJson = json.encode(_examResults.map((r) => r.toJson()).toList());
      await prefs.setString(_resultsKey, resultsJson);
    } catch (e) {
      debugPrint('Failed to save exam results: $e');
    }
  }

  List<Question> generateMockExam(
    List<Question> allQuestions, {
    int totalQuestions = 30,
    int trueFalseCount = 0,
    int singleChoiceCount = 0,
    int multipleChoiceCount = 0,
  }) {
    final random = Random();

    // 如果指定了题目类型数量，按类型选择
    if (trueFalseCount > 0 || singleChoiceCount > 0 || multipleChoiceCount > 0) {
      final trueFalseQuestions = allQuestions
          .where((q) => q is TheoryQuestion && q.type == QuestionType.trueFalse)
          .toList();
      final singleChoiceQuestions = allQuestions
          .where((q) => q is TheoryQuestion && q.type == QuestionType.singleChoice)
          .toList();
      final multipleChoiceQuestions = allQuestions
          .where((q) => q is TheoryQuestion && q.type == QuestionType.multipleChoice)
          .toList();

      trueFalseQuestions.shuffle(random);
      singleChoiceQuestions.shuffle(random);
      multipleChoiceQuestions.shuffle(random);

      final selectedTrueFalse = trueFalseQuestions.take(min(trueFalseCount, trueFalseQuestions.length)).toList();
      final selectedSingleChoice = singleChoiceQuestions.take(min(singleChoiceCount, singleChoiceQuestions.length)).toList();
      final selectedMultipleChoice = multipleChoiceQuestions.take(min(multipleChoiceCount, multipleChoiceQuestions.length)).toList();

      final exam = [...selectedTrueFalse, ...selectedSingleChoice, ...selectedMultipleChoice];
      exam.shuffle(random);
      return exam;
    }

    // 否则按原有逻辑（按理论/实践比例）
    double theoryRatio = 0.7;
    final theoryCount = (totalQuestions * theoryRatio).round();
    final operationalCount = totalQuestions - theoryCount;

    final theoryQuestions = allQuestions.where((q) => q.section == QuestionSection.theoretical).toList();
    final operationalQuestions = allQuestions.where((q) => q.section == QuestionSection.operational).toList();

    theoryQuestions.shuffle(random);
    operationalQuestions.shuffle(random);

    final selectedTheory = theoryQuestions.take(min(theoryCount, theoryQuestions.length)).toList();
    final selectedOperational = operationalQuestions.take(min(operationalCount, operationalQuestions.length)).toList();

    return [...selectedTheory, ...selectedOperational]..shuffle(random);
  }

  Future<ExamResult> saveExamResult({
    required String userId,
    required int totalQuestions,
    required double totalScore,
    required double maxScore,
    required int durationSeconds,
    required Map<String, dynamic> questionResults,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();

    final result = ExamResult(
      id: uuid.v4(),
      userId: userId,
      examDate: now,
      totalQuestions: totalQuestions,
      totalScore: totalScore,
      maxScore: maxScore,
      duration: durationSeconds,
      questionResults: questionResults,
      createdAt: now,
      updatedAt: now,
    );

    _examResults.insert(0, result);
    await _saveData();
    notifyListeners();

    return result;
  }

  List<ExamResult> getResultsByUser(String userId) =>
      _examResults.where((r) => r.userId == userId).toList();

  ExamResult? getLatestResult(String userId) {
    final userResults = getResultsByUser(userId);
    return userResults.isNotEmpty ? userResults.first : null;
  }

  double getAverageScore(String userId) {
    final userResults = getResultsByUser(userId);
    if (userResults.isEmpty) return 0.0;

    final totalScore = userResults.fold(0.0, (sum, result) => sum + result.scorePercentage);
    return totalScore / userResults.length;
  }
}
