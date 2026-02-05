import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_coach/models/user.dart';
import 'package:ai_coach/services/auth_service.dart';

class UserProgressService extends ChangeNotifier {
  static const String _userProfileKeyPrefix = 'user_profile_';
  static const String _categoryProgressKey = 'category_progress_'; // prefix for category progress
  static const String _drillingProgressKey = 'drilling_progress_'; // prefix for drilling progress
  static const String _operationalDrillingProgressKey = 'operational_drilling_progress_';

  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadCurrentUser();
    } catch (e) {
      debugPrint('Failed to initialize user: $e');
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUserId = AuthService().getCurrentUserId();
      if (currentUserId == null) {
        _currentUser = null;
        return;
      }
      await loadUserForId(currentUserId);
    } catch (e) {
      debugPrint('Failed to load user: $e');
      _currentUser = null;
    }
  }

  Future<void> _createUserWithId({
    required String userId,
    required String name,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();

    _currentUser = User(
      id: userId.isEmpty ? uuid.v4() : userId,
      name: name.isEmpty ? 'AI Trainer Student' : name,
      createdAt: now,
      updatedAt: now,
    );

    await _saveUser();
  }

  Future<void> loadUserForId(String userId, {String? fallbackName}) async {
    try {
      if (userId.isEmpty) {
        _currentUser = null;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('$_userProfileKeyPrefix$userId');
      if (userJson != null) {
        final decoded = json.decode(userJson);
        _currentUser = User.fromJson(decoded);
        notifyListeners();
        return;
      }
      await _createUserWithId(
        userId: userId,
        name: fallbackName?.trim().isNotEmpty == true ? fallbackName!.trim() : 'AI Trainer Student',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load user by id: $e');
      _currentUser = null;
    }
  }

  /// 清除本地用户信息（仅清除会话数据，不清除统计数据）
  /// 统计数据在新用户登录时通过 UserStatisticsService 独立加载
  Future<void> clearLocalUser() async {
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _saveUser() async {
    if (_currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = json.encode(_currentUser!.toJson());
      await prefs.setString('$_userProfileKeyPrefix${_currentUser!.id}', userJson);
    } catch (e) {
      debugPrint('Failed to save user: $e');
    }
  }

  /// 记录答题 - 现在由 UserStatisticsService 处理
  /// 保留此方法以保持向后兼容性
  Future<void> recordQuestionAttempt(bool correct) async {
    if (_currentUser == null) return;
    // 统计数据已由 UserStatisticsService 持久化管理
    _currentUser = _currentUser!.copyWith(
      updatedAt: DateTime.now(),
    );
    await _saveUser();
    notifyListeners();
  }

  /// 记录模拟考试 - 现在由 UserStatisticsService 处理
  /// 保留此方法以保持向后兼容性
  Future<void> recordMockExam() async {
    if (_currentUser == null) return;
    // 统计数据已由 UserStatisticsService 持久化管理
    _currentUser = _currentUser!.copyWith(
      updatedAt: DateTime.now(),
    );
    await _saveUser();
    notifyListeners();
  }

  Future<void> updateUserName(String name) async {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      name: name,
      updatedAt: DateTime.now(),
    );

    await _saveUser();
    notifyListeners();
  }

  // 保存分类练习的当前题目索引
  Future<void> saveCategoryProgress(String categoryId, int questionIndex, {String? categoryName}) async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_categoryProgressKey${_currentUser!.id}_$categoryId';
      await prefs.setInt(key, questionIndex);
      if (categoryName != null && categoryName.trim().isNotEmpty) {
        final nameKey = '${_categoryProgressKey}name_${_currentUser!.id}_$categoryName';
        await prefs.setInt(nameKey, questionIndex);
      }
      debugPrint('[UserProgress] Saved category $categoryId progress for user ${_currentUser!.id}: $questionIndex');
    } catch (e) {
      debugPrint('Failed to save category progress: $e');
    }
  }

  // 读取分类练习的当前题目索引
  Future<int> getCategoryProgress(String categoryId, {String? categoryName}) async {
    if (_currentUser == null) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_categoryProgressKey${_currentUser!.id}_$categoryId';
      int? progress = prefs.getInt(key);
      if (progress == null && categoryName != null && categoryName.trim().isNotEmpty) {
        final nameKey = '${_categoryProgressKey}name_${_currentUser!.id}_$categoryName';
        progress = prefs.getInt(nameKey);
      }
      final resolved = progress ?? 0;
      debugPrint('[UserProgress] Loaded category $categoryId progress for user ${_currentUser!.id}: $resolved');
      return resolved;
    } catch (e) {
      debugPrint('Failed to load category progress: $e');
      return 0;
    }
  }

  // 清除分类练习的进度
  Future<void> clearCategoryProgress(String categoryId, {String? categoryName}) async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_categoryProgressKey${_currentUser!.id}_$categoryId';
      await prefs.remove(key);
      // 同时清除完整的分类练习状态
      await prefs.remove('${_categoryProgressKey}state_${_currentUser!.id}_$categoryId');
      if (categoryName != null && categoryName.trim().isNotEmpty) {
        final nameKey = '${_categoryProgressKey}name_${_currentUser!.id}_$categoryName';
        await prefs.remove(nameKey);
        await prefs.remove('${_categoryProgressKey}state_name_${_currentUser!.id}_$categoryName');
      }
      debugPrint('[UserProgress] Cleared category $categoryId progress for user ${_currentUser!.id}');
    } catch (e) {
      debugPrint('Failed to clear category progress: $e');
    }
  }

  // 保存完整的分类练习状态（题目顺序、当前索引、答题状态、答案、解释状态）
  Future<void> saveCategoryState({
    required String categoryId,
    String? categoryName,
    required List<String> questionIds,
    required int currentIndex,
    required List<String> seenQuestionIds,
    required Map<String, String> questionStatusMap,
    required Map<String, dynamic> questionAnswers,
    required Map<String, bool> questionShowExplanation,
  }) async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_categoryProgressKey}state_${_currentUser!.id}_$categoryId';

      final stateData = {
        'questionIds': questionIds,
        'currentIndex': currentIndex,
        'seenQuestionIds': seenQuestionIds,
        'questionStatusMap': questionStatusMap,
        'questionAnswers': questionAnswers,
        'questionShowExplanation': questionShowExplanation,
      };

      final jsonString = json.encode(stateData);
      await prefs.setString(key, jsonString);
      if (categoryName != null && categoryName.trim().isNotEmpty) {
        final nameKey = '${_categoryProgressKey}state_name_${_currentUser!.id}_$categoryName';
        await prefs.setString(nameKey, jsonString);
      }
      debugPrint('[UserProgress] Saved category $categoryId state for user ${_currentUser!.id}');
    } catch (e) {
      debugPrint('Failed to save category state: $e');
    }
  }

  // 读取完整的分类练习状态
  /// 注意：此方法已改进以支持可选的 userId 参数，避免依赖 _currentUser
  /// 如果不提供 userId，会使用 _currentUser.id（仅用于向后兼容）
  Future<Map<String, dynamic>?> getCategoryState(
    String categoryId, {
    String? categoryName,
    String? userId,  // 新增参数，用于避免依赖 _currentUser
  }) async {
    final effectiveUserId = userId ?? _currentUser?.id;
    if (effectiveUserId == null) {
      debugPrint('[UserProgress] Cannot get category state: userId is null');
      return null;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_categoryProgressKey}state_${effectiveUserId}_$categoryId';
      String? jsonString = prefs.getString(key);
      
      if (jsonString == null && categoryName != null && categoryName.trim().isNotEmpty) {
        final nameKey = '${_categoryProgressKey}state_name_${effectiveUserId}_$categoryName';
        jsonString = prefs.getString(nameKey);
      }

      if (jsonString == null) {
        debugPrint('[UserProgress] No saved state for category $categoryId and user $effectiveUserId');
        return null;
      }

      final Map<String, dynamic> stateData = json.decode(jsonString);
      debugPrint('[UserProgress] Loaded category $categoryId state for user $effectiveUserId');
      return stateData;
    } catch (e) {
      debugPrint('Failed to load category state: $e');
      return null;
    }
  }

  // 保存随机训练的当前题目索引
  Future<void> saveDrillingProgress(int questionIndex) async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_drillingProgressKey${_currentUser!.id}';
      await prefs.setInt(key, questionIndex);
      debugPrint('[UserProgress] Saved drilling progress for user ${_currentUser!.id}: $questionIndex');
    } catch (e) {
      debugPrint('Failed to save drilling progress: $e');
    }
  }

  // 读取随机训练的当前题目索引
  Future<int> getDrillingProgress() async {
    if (_currentUser == null) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_drillingProgressKey${_currentUser!.id}';
      final progress = prefs.getInt(key) ?? 0;
      debugPrint('[UserProgress] Loaded drilling progress for user ${_currentUser!.id}: $progress');
      return progress;
    } catch (e) {
      debugPrint('Failed to load drilling progress: $e');
      return 0;
    }
  }

  // 清除随机训练的进度
  Future<void> clearDrillingProgress() async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_drillingProgressKey${_currentUser!.id}';
      await prefs.remove(key);
      // 同时清除完整的随机训练状态
      await prefs.remove('${_drillingProgressKey}state_${_currentUser!.id}');
      debugPrint('[UserProgress] Cleared drilling progress for user ${_currentUser!.id}');
    } catch (e) {
      debugPrint('Failed to clear drilling progress: $e');
    }
  }

  // 保存完整的随机训练状态（题目顺序、当前索引、已见题目、答题状态、答案、解释状态）
  Future<void> saveDrillingState({
    required List<String> questionIds,
    required int currentIndex,
    required List<String> seenQuestionIds,
    required Map<String, String> questionStatusMap,
    required Map<String, dynamic> questionAnswers,
    required Map<String, bool> questionShowExplanation,
  }) async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_drillingProgressKey}state_${_currentUser!.id}';

      final stateData = {
        'questionIds': questionIds,
        'currentIndex': currentIndex,
        'seenQuestionIds': seenQuestionIds,
        'questionStatusMap': questionStatusMap,
        'questionAnswers': questionAnswers,
        'questionShowExplanation': questionShowExplanation,
      };

      final jsonString = json.encode(stateData);
      await prefs.setString(key, jsonString);
      debugPrint('[UserProgress] Saved drilling state for user ${_currentUser!.id}');
    } catch (e) {
      debugPrint('Failed to save drilling state: $e');
    }
  }

  // 读取完整的随机训练状态
  /// 已改进：支持可选的 userId 参数，避免依赖 _currentUser
  Future<Map<String, dynamic>?> getDrillingState({String? userId}) async {
    final effectiveUserId = userId ?? _currentUser?.id;
    if (effectiveUserId == null) {
      debugPrint('[UserProgress] Cannot get drilling state: userId is null');
      return null;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_drillingProgressKey}state_${effectiveUserId}';
      final jsonString = prefs.getString(key);

      if (jsonString == null) {
        debugPrint('[UserProgress] No saved drilling state for user $effectiveUserId');
        return null;
      }

      final Map<String, dynamic> stateData = json.decode(jsonString);
      debugPrint('[UserProgress] Loaded drilling state for user $effectiveUserId');
      return stateData;
    } catch (e) {
      debugPrint('Failed to load drilling state: $e');
      return null;
    }
  }

  Future<void> saveOperationalDrillingState({
    required List<String> questionIds,
    required int currentIndex,
    required List<String> seenQuestionIds,
    required Map<String, String> questionStatusMap,
    required Map<String, dynamic> questionAnswers,
    required Map<String, bool> submittedStates,
    required Map<String, bool> isCorrectStates,
  }) async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_operationalDrillingProgressKey}state_${_currentUser!.id}';
      final stateData = {
        'questionIds': questionIds,
        'currentIndex': currentIndex,
        'seenQuestionIds': seenQuestionIds,
        'questionStatusMap': questionStatusMap,
        'questionAnswers': questionAnswers,
        'submittedStates': submittedStates,
        'isCorrectStates': isCorrectStates,
      };
      final jsonString = json.encode(stateData);
      await prefs.setString(key, jsonString);
      debugPrint('[UserProgress] Saved operational drilling state for user ${_currentUser!.id}');
    } catch (e) {
      debugPrint('Failed to save operational drilling state: $e');
    }
  }

  Future<Map<String, dynamic>?> getOperationalDrillingState({String? userId}) async {
    final effectiveUserId = userId ?? _currentUser?.id;
    if (effectiveUserId == null) {
      debugPrint('[UserProgress] Cannot get operational drilling state: userId is null');
      return null;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_operationalDrillingProgressKey}state_${effectiveUserId}';
      final jsonString = prefs.getString(key);

      if (jsonString == null) {
        debugPrint('[UserProgress] No saved operational drilling state for user $effectiveUserId');
        return null;
      }

      final Map<String, dynamic> stateData = json.decode(jsonString);
      debugPrint('[UserProgress] Loaded operational drilling state for user $effectiveUserId');
      return stateData;
    } catch (e) {
      debugPrint('Failed to load operational drilling state: $e');
      return null;
    }
  }
}
