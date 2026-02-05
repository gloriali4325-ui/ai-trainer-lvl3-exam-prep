enum QuestionType { trueFalse, singleChoice, multipleChoice, codeCompletion }

enum QuestionSection { theoretical, operational }

abstract class Question {
  final String id;
  final String categoryId;
  final QuestionType type;
  final QuestionSection section;
  final String text;
  final String explanation;
  final DateTime createdAt;
  final DateTime updatedAt;

  Question({
    required this.id,
    required this.categoryId,
    required this.type,
    required this.section,
    required this.text,
    required this.explanation,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson();
  bool checkAnswer(dynamic userAnswer);
}

class TheoryQuestion extends Question {
  final List<String> options;
  final dynamic correctAnswer;

  TheoryQuestion({
    required super.id,
    required super.categoryId,
    required super.type,
    required super.text,
    required super.explanation,
    required super.createdAt,
    required super.updatedAt,
    required this.options,
    required this.correctAnswer,
  }) : super(section: QuestionSection.theoretical);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'type': type.name,
        'section': section.name,
        'text': text,
        'explanation': explanation,
        'options': options,
        'correctAnswer': correctAnswer,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TheoryQuestion.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = QuestionType.values.firstWhere((e) => e.name == typeStr);

    return TheoryQuestion(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      type: type,
      text: json['text'] as String,
      explanation: json['explanation'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correctAnswer'],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool checkAnswer(dynamic userAnswer) {
    if (type == QuestionType.multipleChoice) {
      if (userAnswer is! List || correctAnswer is! List) return false;
      final userSet = (userAnswer).toSet();
      final correctSet = (correctAnswer as List).toSet();
      return userSet.length == correctSet.length && userSet.containsAll(correctSet);
    }
    return userAnswer == correctAnswer;
  }

  TheoryQuestion copyWith({
    String? id,
    String? categoryId,
    QuestionType? type,
    String? text,
    String? explanation,
    List<String>? options,
    dynamic correctAnswer,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      TheoryQuestion(
        id: id ?? this.id,
        categoryId: categoryId ?? this.categoryId,
        type: type ?? this.type,
        text: text ?? this.text,
        explanation: explanation ?? this.explanation,
        options: options ?? this.options,
        correctAnswer: correctAnswer ?? this.correctAnswer,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class CodeQuestion extends Question {
  final String codeTemplate;
  final List<String> correctKeywords;
  final String correctCode;
  final List<String>? dataFiles; // CSV files: ['patient_data.csv', 'sensor_data.csv']

  CodeQuestion({
    required super.id,
    required super.categoryId,
    required super.text,
    required super.explanation,
    required super.createdAt,
    required super.updatedAt,
    required this.codeTemplate,
    required this.correctKeywords,
    required this.correctCode,
    this.dataFiles,
  }) : super(type: QuestionType.codeCompletion, section: QuestionSection.operational);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'type': type.name,
        'section': section.name,
        'text': text,
        'explanation': explanation,
        'codeTemplate': codeTemplate,
        'correctKeywords': correctKeywords,
        'correctCode': correctCode,
        'dataFiles': dataFiles,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CodeQuestion.fromJson(Map<String, dynamic> json) => CodeQuestion(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        text: json['text'] as String,
        explanation: json['explanation'] as String,
        codeTemplate: json['codeTemplate'] as String,
        correctKeywords: List<String>.from(json['correctKeywords'] as List),
        correctCode: (json['correctCode'] as String?) ?? '',
        dataFiles: json['dataFiles'] != null
            ? List<String>.from(json['dataFiles'] as List)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  @override
  bool checkAnswer(dynamic userAnswer) {
    if (userAnswer is! String) return false;
    final userCode = userAnswer.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return correctKeywords.every((keyword) => userCode.contains(keyword.toLowerCase().replaceAll(RegExp(r'\s+'), '')));
  }

  CodeQuestion copyWith({
    String? id,
    String? categoryId,
    String? text,
    String? explanation,
    String? codeTemplate,
    List<String>? correctKeywords,
    String? correctCode,
    List<String>? dataFiles,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CodeQuestion(
        id: id ?? this.id,
        categoryId: categoryId ?? this.categoryId,
        text: text ?? this.text,
        explanation: explanation ?? this.explanation,
        codeTemplate: codeTemplate ?? this.codeTemplate,
        correctKeywords: correctKeywords ?? this.correctKeywords,
        correctCode: correctCode ?? this.correctCode,
        dataFiles: dataFiles ?? this.dataFiles,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
