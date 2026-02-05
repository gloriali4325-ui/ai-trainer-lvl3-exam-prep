// 错题类型枚举
enum MistakeType {
  wrongAnswer, // 答错题
  unanswered, // 未作答题
}

// 错题状态枚举
enum MistakeStatus {
  reviewing, // 复习中
  mastered, // 已掌握
  continued, // 继续复习
  reinforced, // 加入再练
}

class MistakeRecord {
  final String id;
  final String userId;
  final String questionId;
  final dynamic userAnswer;
  final DateTime attemptedAt;
  final int attemptCount;
  final bool reviewed;
  final MistakeType mistakeType; // 区分答错和未作答
  final MistakeStatus status; // 当前状态
  final DateTime createdAt;
  final DateTime updatedAt;

  MistakeRecord({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.userAnswer,
    required this.attemptedAt,
    this.attemptCount = 1,
    this.reviewed = false,
    required this.mistakeType,
    this.status = MistakeStatus.reviewing,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'questionId': questionId,
        'userAnswer': userAnswer,
        'attemptedAt': attemptedAt.toIso8601String(),
        'attemptCount': attemptCount,
        'reviewed': reviewed,
        'mistakeType': mistakeType.toString(),
        'status': status.toString(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MistakeRecord.fromJson(Map<String, dynamic> json) => MistakeRecord(
        id: json['id'] as String,
        userId: json['userId'] as String,
        questionId: json['questionId'] as String,
        userAnswer: json['userAnswer'],
        attemptedAt: DateTime.parse(json['attemptedAt'] as String),
        attemptCount: json['attemptCount'] as int? ?? 1,
        reviewed: json['reviewed'] as bool? ?? false,
        mistakeType: _parseMistakeType(json['mistakeType'] as String?),
        status: _parseMistakeStatus(json['status'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  static MistakeType _parseMistakeType(String? value) {
    if (value == null) return MistakeType.wrongAnswer;
    if (value.contains('unanswered')) return MistakeType.unanswered;
    return MistakeType.wrongAnswer;
  }

  static MistakeStatus _parseMistakeStatus(String? value) {
    if (value == null) return MistakeStatus.reviewing;
    if (value.contains('mastered')) return MistakeStatus.mastered;
    if (value.contains('continued')) return MistakeStatus.continued;
    if (value.contains('reinforced')) return MistakeStatus.reinforced;
    return MistakeStatus.reviewing;
  }

  MistakeRecord copyWith({
    String? id,
    String? userId,
    String? questionId,
    dynamic userAnswer,
    DateTime? attemptedAt,
    int? attemptCount,
    bool? reviewed,
    MistakeType? mistakeType,
    MistakeStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MistakeRecord(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        questionId: questionId ?? this.questionId,
        userAnswer: userAnswer ?? this.userAnswer,
        attemptedAt: attemptedAt ?? this.attemptedAt,
        attemptCount: attemptCount ?? this.attemptCount,
        reviewed: reviewed ?? this.reviewed,
        mistakeType: mistakeType ?? this.mistakeType,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
