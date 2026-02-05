class User {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalQuestionsAttempted;
  final int totalQuestionsCorrect;
  final int mockExamsTaken;
  final DateTime lastSyncAt; // 最后同步时间

  User({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.totalQuestionsAttempted = 0,
    this.totalQuestionsCorrect = 0,
    this.mockExamsTaken = 0,
    DateTime? lastSyncAt,
  }) : lastSyncAt = lastSyncAt ?? DateTime.now();

  double get accuracyRate =>
      totalQuestionsAttempted > 0 ? (totalQuestionsCorrect / totalQuestionsAttempted) * 100 : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'totalQuestionsAttempted': totalQuestionsAttempted,
        'totalQuestionsCorrect': totalQuestionsCorrect,
        'mockExamsTaken': mockExamsTaken,
        'lastSyncAt': lastSyncAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        totalQuestionsAttempted: json['totalQuestionsAttempted'] as int? ?? 0,
        totalQuestionsCorrect: json['totalQuestionsCorrect'] as int? ?? 0,
        mockExamsTaken: json['mockExamsTaken'] as int? ?? 0,
        lastSyncAt: json['lastSyncAt'] != null ? DateTime.parse(json['lastSyncAt'] as String) : null,
      );

  User copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalQuestionsAttempted,
    int? totalQuestionsCorrect,
    int? mockExamsTaken,
    DateTime? lastSyncAt,
  }) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        totalQuestionsAttempted: totalQuestionsAttempted ?? this.totalQuestionsAttempted,
        totalQuestionsCorrect: totalQuestionsCorrect ?? this.totalQuestionsCorrect,
        mockExamsTaken: mockExamsTaken ?? this.mockExamsTaken,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );
}
