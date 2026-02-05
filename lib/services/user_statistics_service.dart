import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_coach/services/auth_service.dart';

/// 用户统计数据服务
/// 负责持久化保存用户的学习统计数据（已答题目、正确率、模拟考试等）
/// 数据在用户退出后仍然保留，直到用户主动重置或参加新的学习活动更新统计
class UserStatisticsService extends ChangeNotifier {
  static const String _statisticsKeyPrefix = 'user_statistics_';

  late SharedPreferences _prefs;

  int _totalQuestionsAttempted = 0;
  int _totalQuestionsCorrect = 0;
  int _mockExamsTaken = 0;
  DateTime? _lastUpdateTime;

  int get totalQuestionsAttempted => _totalQuestionsAttempted;
  int get totalQuestionsCorrect => _totalQuestionsCorrect;
  int get mockExamsTaken => _mockExamsTaken;
  double get accuracyRate =>
      _totalQuestionsAttempted > 0 ? (_totalQuestionsCorrect / _totalQuestionsAttempted) * 100 : 0;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// 初始化服务，从本地存储加载统计数据
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadStatistics();
  }

  /// 从本地存储加载统计数据
  Future<void> _loadStatistics() async {
    try {
      final userId = AuthService().getCurrentUserId();
      if (userId == null) {
        _resetStatistics();
        return;
      }

      final key = '$_statisticsKeyPrefix$userId';
      final statisticsJson = _prefs.getString(key);

      if (statisticsJson != null) {
        final data = json.decode(statisticsJson);
        _totalQuestionsAttempted = data['totalQuestionsAttempted'] as int? ?? 0;
        _totalQuestionsCorrect = data['totalQuestionsCorrect'] as int? ?? 0;
        _mockExamsTaken = data['mockExamsTaken'] as int? ?? 0;
        _lastUpdateTime = data['lastUpdateTime'] != null
            ? DateTime.parse(data['lastUpdateTime'] as String)
            : null;
        debugPrint(
            '[UserStatistics] Loaded statistics for user $userId: attempted=$_totalQuestionsAttempted, correct=$_totalQuestionsCorrect, exams=$_mockExamsTaken');
      } else {
        _resetStatistics();
      }
    } catch (e) {
      debugPrint('Failed to load statistics: $e');
      _resetStatistics();
    }

    notifyListeners();
  }

  /// 记录一次答题
  Future<void> recordQuestionAttempt(bool correct) async {
    _totalQuestionsAttempted++;
    if (correct) {
      _totalQuestionsCorrect++;
    }
    _lastUpdateTime = DateTime.now();
    await _saveStatistics();
    notifyListeners();
  }

  /// 记录一次模拟考试
  Future<void> recordMockExam() async {
    _mockExamsTaken++;
    _lastUpdateTime = DateTime.now();
    await _saveStatistics();
    notifyListeners();
  }

  /// 批量更新统计数据（用于与服务器同步）
  Future<void> updateStatistics({
    required int totalQuestionsAttempted,
    required int totalQuestionsCorrect,
    required int mockExamsTaken,
  }) async {
    _totalQuestionsAttempted = totalQuestionsAttempted;
    _totalQuestionsCorrect = totalQuestionsCorrect;
    _mockExamsTaken = mockExamsTaken;
    _lastUpdateTime = DateTime.now();
    await _saveStatistics();
    notifyListeners();
  }

  /// 清空统计数据（用户主动重置）
  Future<void> clearStatistics() async {
    _resetStatistics();
    await _saveStatistics();
    notifyListeners();
  }

  /// 重置内部数据
  void _resetStatistics() {
    _totalQuestionsAttempted = 0;
    _totalQuestionsCorrect = 0;
    _mockExamsTaken = 0;
    _lastUpdateTime = null;
  }

  /// 保存统计数据到本地存储
  Future<void> _saveStatistics() async {
    try {
      final userId = AuthService().getCurrentUserId();
      if (userId == null) return;

      final key = '$_statisticsKeyPrefix$userId';
      final data = {
        'totalQuestionsAttempted': _totalQuestionsAttempted,
        'totalQuestionsCorrect': _totalQuestionsCorrect,
        'mockExamsTaken': _mockExamsTaken,
        'lastUpdateTime': _lastUpdateTime?.toIso8601String(),
      };

      await _prefs.setString(key, json.encode(data));
      debugPrint('[UserStatistics] Saved statistics for user $userId');
    } catch (e) {
      debugPrint('Failed to save statistics: $e');
    }
  }

  /// 检查是否需要与服务器同步（最后修改时间距现在超过1小时）
  bool shouldSyncWithServer() {
    if (_lastUpdateTime == null) return false;
    final difference = DateTime.now().difference(_lastUpdateTime!);
    return difference.inHours >= 1;
  }

  /// 清除当前用户的所有统计数据（在用户退出时调用）
  Future<void> clearCurrentUserData() async {
    try {
      final userId = AuthService().getCurrentUserId();
      if (userId != null) {
        final key = '$_statisticsKeyPrefix$userId';
        await _prefs.remove(key);
      }
      _resetStatistics();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to clear user data: $e');
    }
  }
}
