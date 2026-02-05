import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_coach/models/mistake_record.dart';
import 'package:ai_coach/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MistakeNotebookService extends ChangeNotifier {
  static const String _mistakeMode = 'mistake_notebook';
  static const String _answerKey = 'answer';
  static const String _attemptCountKey = 'attempt_count';
  static const String _reviewedKey = 'reviewed';
  static const String _statusKey = 'status';
  static const String _mistakeTypeKey = 'mistake_type';

  List<MistakeRecord> _mistakes = [];
  bool _isLoading = false;
  SupabaseClient get _client => Supabase.instance.client;
  final AuthService _authService = AuthService();

  List<MistakeRecord> get mistakes => _mistakes;
  List<MistakeRecord> get unreviewedMistakes => _mistakes.where((m) => !m.reviewed).toList();
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        _mistakes = [];
        return;
      }
      await _loadFromDatabase(userId);
    } catch (e) {
      debugPrint('Failed to load mistakes: $e');
      _mistakes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromDatabase(String userId) async {
    final response = await _client
        .from('user_attempts')
        .select('id,user_id,question_id,user_answer,answered_at,mode,is_correct')
        .eq('user_id', userId)
        .eq('mode', _mistakeMode)
        .order('answered_at', ascending: false);

    final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
    final Map<String, MistakeRecord> deduped = {};
    for (final row in rows) {
      final record = _mistakeFromRow(row);
      deduped.putIfAbsent(record.questionId, () => record);
    }
    _mistakes = deduped.values.toList();
  }

  Future<void> addMistake({
    required String userId,
    required String questionId,
    required dynamic userAnswer,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();
    
    // 自动识别错题类型：userAnswer 为 null 表示未作答
    final mistakeType = userAnswer == null ? MistakeType.unanswered : MistakeType.wrongAnswer;

    final existingIndex = _mistakes.indexWhere(
      (m) => m.userId == userId && m.questionId == questionId,
    );

    if (existingIndex != -1) {
      final updated = _mistakes[existingIndex].copyWith(
        userAnswer: userAnswer,
        attemptedAt: now,
        attemptCount: _mistakes[existingIndex].attemptCount + 1,
        reviewed: false,
        mistakeType: mistakeType,
        status: MistakeStatus.reviewing,
        updatedAt: now,
      );
      _mistakes[existingIndex] = updated;
      await _updateAttemptRow(
        id: updated.id,
        userAnswer: _buildUserAnswerPayload(updated),
        answeredAt: now,
      );
    } else {
      final mistake = MistakeRecord(
        id: uuid.v4(),
        userId: userId,
        questionId: questionId,
        userAnswer: userAnswer,
        attemptedAt: now,
        mistakeType: mistakeType,
        createdAt: now,
        updatedAt: now,
      );
      final insertedId = await _insertAttemptRow(
        userId: userId,
        questionId: questionId,
        userAnswer: _buildUserAnswerPayload(mistake),
        answeredAt: now,
      );
      final stored = mistake.copyWith(id: insertedId ?? mistake.id);
      _mistakes.insert(0, stored);
    }

    notifyListeners();
  }

  Future<void> markAsReviewed(String mistakeId) async {
    final index = _mistakes.indexWhere((m) => m.id == mistakeId);
    if (index != -1) {
      final updated = _mistakes[index].copyWith(
        reviewed: true,
        updatedAt: DateTime.now(),
      );
      _mistakes[index] = updated;
      await _updateAttemptRow(
        id: updated.id,
        userAnswer: _buildUserAnswerPayload(updated),
        answeredAt: updated.attemptedAt,
      );
      notifyListeners();
    }
  }

  /// 标记为已掌握（将从错题本移出或降低出现频率）
  Future<void> markAsMastered(String mistakeId) async {
    final index = _mistakes.indexWhere((m) => m.id == mistakeId);
    if (index != -1) {
      final updated = _mistakes[index].copyWith(
        status: MistakeStatus.mastered,
        reviewed: true,
        updatedAt: DateTime.now(),
      );
      _mistakes[index] = updated;
      await _updateAttemptRow(
        id: updated.id,
        userAnswer: _buildUserAnswerPayload(updated),
        answeredAt: updated.attemptedAt,
      );
      notifyListeners();
    }
  }

  /// 标记为继续复习（保留在错题本）
  Future<void> markAsContinued(String mistakeId) async {
    final index = _mistakes.indexWhere((m) => m.id == mistakeId);
    if (index != -1) {
      final updated = _mistakes[index].copyWith(
        status: MistakeStatus.continued,
        updatedAt: DateTime.now(),
      );
      _mistakes[index] = updated;
      await _updateAttemptRow(
        id: updated.id,
        userAnswer: _buildUserAnswerPayload(updated),
        answeredAt: updated.attemptedAt,
      );
      notifyListeners();
    }
  }

  /// 标记为加入再练（进入强化练习）
  Future<void> markForReinforcement(String mistakeId) async {
    final index = _mistakes.indexWhere((m) => m.id == mistakeId);
    if (index != -1) {
      final updated = _mistakes[index].copyWith(
        status: MistakeStatus.reinforced,
        updatedAt: DateTime.now(),
      );
      _mistakes[index] = updated;
      await _updateAttemptRow(
        id: updated.id,
        userAnswer: _buildUserAnswerPayload(updated),
        answeredAt: updated.attemptedAt,
      );
      notifyListeners();
    }
  }

  /// 获取特定状态的错题
  List<MistakeRecord> getMistakesByStatus(MistakeStatus status) =>
      _mistakes.where((m) => m.status == status).toList();

  /// 获取未掌握的错题（用于复习列表）
  List<MistakeRecord> getUnmasteredMistakes() =>
      _mistakes.where((m) => m.status != MistakeStatus.mastered).toList();

  /// 记录强化/复习时的作答结果
  Future<void> recordReviewAttempt({
    required String mistakeId,
    required dynamic userAnswer,
    required bool isCorrect,
  }) async {
    final index = _mistakes.indexWhere((m) => m.id == mistakeId);
    if (index == -1) return;

    final now = DateTime.now();
    final updated = _mistakes[index].copyWith(
      userAnswer: userAnswer,
      attemptedAt: now,
      attemptCount: _mistakes[index].attemptCount + 1,
      reviewed: true,
      status: isCorrect ? MistakeStatus.mastered : MistakeStatus.reinforced,
      updatedAt: now,
    );
    _mistakes[index] = updated;
    await _updateAttemptRow(
      id: updated.id,
      userAnswer: _buildUserAnswerPayload(updated),
      answeredAt: now,
    );
    notifyListeners();
  }

  Future<void> removeMistake(String mistakeId) async {
    _mistakes.removeWhere((m) => m.id == mistakeId);
    await _client.from('user_attempts').delete().eq('id', mistakeId);
    notifyListeners();
  }

  Future<void> clearAllMistakes() async {
    _mistakes.clear();
    final userId = _authService.getCurrentUserId();
    if (userId != null) {
      await _client
          .from('user_attempts')
          .delete()
          .eq('user_id', userId)
          .eq('mode', _mistakeMode);
    }
    notifyListeners();
  }

  List<MistakeRecord> getMistakesByUser(String userId) =>
      _mistakes.where((m) => m.userId == userId).toList();

  MistakeRecord? getMistakeByQuestion(String userId, String questionId) =>
      _mistakes.cast<MistakeRecord?>().firstWhere(
            (m) => m?.userId == userId && m?.questionId == questionId,
            orElse: () => null,
          );

  Map<String, dynamic> _buildUserAnswerPayload(MistakeRecord record) => {
        _answerKey: record.userAnswer,
        _attemptCountKey: record.attemptCount,
        _reviewedKey: record.reviewed,
        _mistakeTypeKey: record.mistakeType.name,
        _statusKey: record.status.name,
      };

  MistakeRecord _mistakeFromRow(Map<String, dynamic> row) {
    final userAnswerRaw = row['user_answer'];
    dynamic answer = userAnswerRaw;
    int attemptCount = 1;
    bool reviewed = false;
    MistakeType mistakeType;
    MistakeStatus status = MistakeStatus.reviewing;

    if (userAnswerRaw is Map) {
      final map = Map<String, dynamic>.from(userAnswerRaw);
      answer = map[_answerKey];
      final countValue = map[_attemptCountKey];
      if (countValue is num) {
        attemptCount = countValue.toInt();
      } else {
        attemptCount = (countValue as int?) ?? 1;
      }
      reviewed = (map[_reviewedKey] as bool?) ?? false;
      mistakeType = _parseMistakeType(map[_mistakeTypeKey] as String?);
      status = _parseMistakeStatus(map[_statusKey] as String?);
    } else {
      mistakeType = answer == null ? MistakeType.unanswered : MistakeType.wrongAnswer;
    }

    final answeredAt = _parseDbDate(row['answered_at']) ?? DateTime.now();
    return MistakeRecord(
      id: row['id']?.toString() ?? Uuid().v4(),
      userId: row['user_id']?.toString() ?? '',
      questionId: row['question_id']?.toString() ?? '',
      userAnswer: answer,
      attemptedAt: answeredAt,
      attemptCount: attemptCount,
      reviewed: reviewed,
      mistakeType: mistakeType,
      status: status,
      createdAt: answeredAt,
      updatedAt: answeredAt,
    );
  }

  DateTime? _parseDbDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  MistakeType _parseMistakeType(String? value) {
    if (value == null) return MistakeType.wrongAnswer;
    if (value.contains('unanswered')) return MistakeType.unanswered;
    return MistakeType.wrongAnswer;
  }

  MistakeStatus _parseMistakeStatus(String? value) {
    if (value == null) return MistakeStatus.reviewing;
    if (value.contains('mastered')) return MistakeStatus.mastered;
    if (value.contains('continued')) return MistakeStatus.continued;
    if (value.contains('reinforced')) return MistakeStatus.reinforced;
    return MistakeStatus.reviewing;
  }

  Future<String?> _insertAttemptRow({
    required String userId,
    required String questionId,
    required Map<String, dynamic> userAnswer,
    required DateTime answeredAt,
  }) async {
    try {
      final response = await _client.from('user_attempts').insert({
        'user_id': userId,
        'question_id': questionId,
        'mode': _mistakeMode,
        'user_answer': userAnswer,
        'is_correct': false,
        'answered_at': answeredAt.toIso8601String(),
      }).select('id');

      if (response is List && response.isNotEmpty) {
        return response.first['id']?.toString();
      }
    } catch (e) {
      debugPrint('Failed to insert mistake attempt: $e');
    }
    return null;
  }

  Future<void> _updateAttemptRow({
    required String id,
    required Map<String, dynamic> userAnswer,
    required DateTime answeredAt,
  }) async {
    try {
      await _client.from('user_attempts').update({
        'user_answer': userAnswer,
        'is_correct': false,
        'answered_at': answeredAt.toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      debugPrint('Failed to update mistake attempt: $e');
    }
  }
}
