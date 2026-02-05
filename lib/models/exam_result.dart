class ExamResult {
  final String id;
  final String userId;
  final DateTime examDate;
  final int totalQuestions;
  final double totalScore; // 改为双精度浮点数以支持小数分
  final double maxScore; // 最高分数
  final int duration;
  final Map<String, dynamic> questionResults;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamResult({
    required this.id,
    required this.userId,
    required this.examDate,
    required this.totalQuestions,
    required this.totalScore,
    required this.maxScore,
    required this.duration,
    required this.questionResults,
    required this.createdAt,
    required this.updatedAt,
  });

  double get scorePercentage => (totalScore / maxScore) * 100;

  bool get passed => scorePercentage >= 60;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'examDate': examDate.toIso8601String(),
        'totalQuestions': totalQuestions,
        'totalScore': totalScore,
        'maxScore': maxScore,
        'duration': duration,
        'questionResults': questionResults,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ExamResult.fromJson(Map<String, dynamic> json) => ExamResult(
        id: json['id'] as String,
        userId: json['userId'] as String,
        examDate: DateTime.parse(json['examDate'] as String),
        totalQuestions: json['totalQuestions'] as int,
        totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0.0,
        maxScore: (json['maxScore'] as num?)?.toDouble() ?? 100.0,
        duration: json['duration'] as int,
        questionResults: Map<String, dynamic>.from(json['questionResults'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  ExamResult copyWith({
    String? id,
    String? userId,
    DateTime? examDate,
    int? totalQuestions,
    double? totalScore,
    double? maxScore,
    int? duration,
    Map<String, dynamic>? questionResults,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ExamResult(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        examDate: examDate ?? this.examDate,
        totalQuestions: totalQuestions ?? this.totalQuestions,
        totalScore: totalScore ?? this.totalScore,
        maxScore: maxScore ?? this.maxScore,
        duration: duration ?? this.duration,
        questionResults: questionResults ?? this.questionResults,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
