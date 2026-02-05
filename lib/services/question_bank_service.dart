import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/models/category.dart' as cat;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TheoryLoadResult {
  final List<TheoryQuestion> theoryQuestions;
  final List<cat.Category> categories;
  final Map<String, String> categoryIdByName;

  _TheoryLoadResult({
    required this.theoryQuestions,
    required this.categories,
    required this.categoryIdByName,
  });
}

class _OperationalLoadResult {
  final List<CodeQuestion> codeQuestions;
  final Set<String> categoryNames;
  final List<cat.Category> categories;

  _OperationalLoadResult({
    required this.codeQuestions,
    required this.categoryNames,
    required this.categories,
  });
}

class QuestionBankService extends ChangeNotifier {
  static const String _categoriesKey = 'categories';
  static const String _theoryQuestionsKey = 'theory_questions';
  static const String _codeQuestionsKey = 'code_questions';
  List<cat.Category> _categories = [];
  List<TheoryQuestion> _theoryQuestions = [];
  List<CodeQuestion> _codeQuestions = [];
  bool _isLoading = false;
  SupabaseClient get _client => Supabase.instance.client;

  List<cat.Category> get categories => _categories;
  List<TheoryQuestion> get theoryQuestions => _theoryQuestions;
  List<CodeQuestion> get codeQuestions => _codeQuestions;
  bool get isLoading => _isLoading;

  List<Question> get allQuestions => [..._theoryQuestions, ..._codeQuestions];

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[QuestionBank] Loading theory questions from database...');
      final theoryResult = await _loadTheoryQuestionsFromDatabase();
      debugPrint('[QuestionBank] Loaded theory from database - Categories: ${theoryResult.categories.length}, Theory Questions: ${theoryResult.theoryQuestions.length}');

      debugPrint('[QuestionBank] Loading operational questions from asset...');
      final operationalResult = await _loadOperationalQuestionsFromAsset(
        categoryIdByName: Map<String, String>.from(theoryResult.categoryIdByName),
        categories: List<cat.Category>.from(theoryResult.categories),
      );
      debugPrint('[QuestionBank] Loaded operational from asset - Code Questions: ${operationalResult.codeQuestions.length}');

      _theoryQuestions = theoryResult.theoryQuestions;
      _codeQuestions = operationalResult.codeQuestions;
      _categories = operationalResult.categories;

      await _saveData();
    } catch (e) {
      debugPrint('[QuestionBank] Initialize failed: $e');
      await _loadData();
      if (_theoryQuestions.isEmpty && _codeQuestions.isEmpty) {
        debugPrint('[QuestionBank] Cache empty, fallback to asset...');
        await _initializeFromOfficialAsset();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final categoriesJson = prefs.getString(_categoriesKey);
      if (categoriesJson != null) {
        final List<dynamic> decoded = json.decode(categoriesJson);
        _categories = decoded.map((item) => cat.Category.fromJson(item)).toList();
      }

      final theoryJson = prefs.getString(_theoryQuestionsKey);
      if (theoryJson != null) {
        final List<dynamic> decoded = json.decode(theoryJson);
        _theoryQuestions = decoded.map((item) => TheoryQuestion.fromJson(item)).toList();
      }

      final codeJson = prefs.getString(_codeQuestionsKey);
      if (codeJson != null) {
        final List<dynamic> decoded = json.decode(codeJson);
        _codeQuestions = decoded.map((item) => CodeQuestion.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Failed to load questions: $e');
    }
  }

  Future<_TheoryLoadResult> _loadTheoryQuestionsFromDatabase() async {
    final now = DateTime.now();
    final response = await _client
        .from('question_bank')
        .select('question_id,type,category,question,options,correct_answer,explanation,created_at')
        .order('question_id');

    final rows = (response as List<dynamic>).cast<Map<String, dynamic>>();
    final Set<String> categoryNames = rows
        .map((e) => (e['category'] as String?) ?? 'General')
        .toSet();

    final Map<String, bool> hasSingleChoice = {};
    final Map<String, bool> hasMultipleChoice = {};

    for (final row in rows) {
      final categoryName = (row['category'] as String?) ?? 'General';
      final typeStr = (row['type'] as String?)?.toLowerCase() ?? 'single_choice';
      final qType = _mapType(typeStr);
      if (qType == QuestionType.singleChoice) {
        hasSingleChoice[categoryName] = true;
      } else if (qType == QuestionType.multipleChoice) {
        hasMultipleChoice[categoryName] = true;
      }
    }

    final Map<String, String> categoryIdByName = {};
    final List<cat.Category> allCategories = [];

    for (final name in categoryNames) {
      final baseId = _slugify(name);
      final hasSingle = hasSingleChoice[name] == true;
      final hasMultiple = hasMultipleChoice[name] == true;

      if (hasSingle && hasMultiple) {
        final singleId = '$baseId-single';
        categoryIdByName['$name-single'] = singleId;
        allCategories.add(cat.Category(
          id: singleId,
          name: '$name - 单选题',
          description: '$name - 单选题',
          icon: 'check_circle',
          createdAt: now,
          updatedAt: now,
        ));

        final multipleId = '$baseId-multiple';
        categoryIdByName['$name-multiple'] = multipleId;
        allCategories.add(cat.Category(
          id: multipleId,
          name: '$name - 多选题',
          description: '$name - 多选题',
          icon: 'done_all',
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        categoryIdByName[name] = baseId;
        allCategories.add(cat.Category(
          id: baseId,
          name: name,
          description: name,
          icon: 'book',
          createdAt: now,
          updatedAt: now,
        ));
      }
    }

    final theoryQuestions = rows.map<TheoryQuestion>((row) {
      final id = row['question_id'].toString();
      final typeStr = (row['type'] as String?)?.toLowerCase() ?? 'single_choice';
      final categoryName = (row['category'] as String?) ?? 'General';
      final qType = _mapType(typeStr);

      final hasSingle = hasSingleChoice[categoryName] == true;
      final hasMultiple = hasMultipleChoice[categoryName] == true;
      String categoryId;
      if (hasSingle && hasMultiple) {
        if (qType == QuestionType.singleChoice) {
          categoryId = categoryIdByName['$categoryName-single'] ?? _slugify('$categoryName-single');
        } else if (qType == QuestionType.multipleChoice) {
          categoryId = categoryIdByName['$categoryName-multiple'] ?? _slugify('$categoryName-multiple');
        } else {
          categoryId = categoryIdByName[categoryName] ?? _slugify(categoryName);
        }
      } else {
        categoryId = categoryIdByName[categoryName] ?? _slugify(categoryName);
      }

      final options = (row['options'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      final explanation = (row['explanation'] as String?) ?? '';
      final text = (row['question'] as String?) ?? '';
      final rawAnswer = row['correct_answer']?.toString();
      final correct = _parseCorrectAnswerFromDb(rawAnswer, options, qType);
      final createdAt = _parseDbDate(row['created_at']) ?? now;

      return TheoryQuestion(
        id: id,
        categoryId: categoryId,
        type: qType,
        text: text,
        explanation: explanation,
        options: options,
        correctAnswer: correct,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    }).toList();

    return _TheoryLoadResult(
      theoryQuestions: theoryQuestions,
      categories: allCategories,
      categoryIdByName: categoryIdByName,
    );
  }

  Future<_OperationalLoadResult> _loadOperationalQuestionsFromAsset({
    required Map<String, String> categoryIdByName,
    required List<cat.Category> categories,
  }) async {
    final now = DateTime.now();
    List<dynamic> operationalDecoded = [];
    try {
      final operationalJsonStr = await rootBundle.loadString('assets/operational_skills.json');
      operationalDecoded = json.decode(operationalJsonStr) as List<dynamic>? ?? [];
    } catch (e) {
      debugPrint('Failed to load operational skills asset: $e');
    }

    final Set<String> operationalCategoryNames = operationalDecoded
        .map((e) => (e as Map<String, dynamic>)['category'] as String? ?? 'General')
        .toSet();

    for (final name in operationalCategoryNames) {
      final baseId = _slugify(name);
      if (!categoryIdByName.containsKey(name)) {
        categoryIdByName[name] = baseId;
        categories.add(cat.Category(
          id: baseId,
          name: name,
          description: name,
          icon: 'code',
          createdAt: now,
          updatedAt: now,
        ));
      }
    }

    final codeQuestions = operationalDecoded.map<CodeQuestion>((raw) {
      final m = raw as Map<String, dynamic>;
      final id = m['id'].toString();
      final categoryName = (m['category'] as String?) ?? 'General';
      final categoryId = categoryIdByName[categoryName] ?? _slugify(categoryName);
      final text = (m['question'] as String?) ?? (m['title'] as String?) ?? '';
      final explanation = (m['explanation'] as String?) ?? '';
      final codeTemplate = (m['codeTemplate'] as String?) ?? '';
      final correctKeywords = (m['correctKeywords'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      final correctCode = (m['correctCode'] as String?) ?? '';
      final dataFiles = (m['dataFiles'] as List?)?.map((e) => e.toString()).toList();

      return CodeQuestion(
        id: id,
        categoryId: categoryId,
        text: text,
        explanation: explanation,
        codeTemplate: codeTemplate,
        correctKeywords: correctKeywords,
        correctCode: correctCode,
        dataFiles: dataFiles,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();

    return _OperationalLoadResult(
      codeQuestions: codeQuestions,
      categoryNames: operationalCategoryNames,
      categories: categories,
    );
  }

  Future<void> _initializeFromOfficialAsset() async {
    final now = DateTime.now();
    try {
      // Load theory questions from main asset
      final jsonStr = await rootBundle.loadString('assets/ai_trainer_bank_v2.json');
      final List<dynamic> decoded = json.decode(jsonStr);

      // Load operational skill questions from asset
      List<dynamic> operationalDecoded = [];
      try {
        final operationalJsonStr = await rootBundle.loadString('assets/operational_skills.json');
        operationalDecoded = json.decode(operationalJsonStr) as List<dynamic>? ?? [];
      } catch (e) {
        debugPrint('Failed to load operational skills asset: $e');
      }

      // Build categories from unique category names
      final Set<String> categoryNames = decoded
          .map((e) => (e as Map<String, dynamic>)['category'] as String? ?? 'General')
          .toSet();
      
      // Add operational skill categories
      final Set<String> operationalCategoryNames = operationalDecoded
          .map((e) => (e as Map<String, dynamic>)['category'] as String? ?? 'General')
          .toSet();
      categoryNames.addAll(operationalCategoryNames);
      
      final Map<String, String> categoryIdByName = {};
      
      // Create base categories and sub-categories for choice questions
      final List<cat.Category> allCategories = [];
      for (final name in categoryNames) {
        final baseId = _slugify(name);

        // Check if this category has both single and multiple choice questions
        final categoryQuestions = decoded
            .where((e) => (e as Map<String, dynamic>)['category'] == name)
            .toList();
        
        // Skip if this category only contains operational questions
        if (categoryQuestions.isEmpty) {
          continue;
        }
        categoryIdByName[name] = baseId;
        
        final hasSingleChoice = categoryQuestions.any((q) {
          final typeStr = (q['type'] as String?)?.toLowerCase() ?? 'single_choice';
          return _mapType(typeStr) == QuestionType.singleChoice;
        });
        
        final hasMultipleChoice = categoryQuestions.any((q) {
          final typeStr = (q['type'] as String?)?.toLowerCase() ?? 'single_choice';
          return _mapType(typeStr) == QuestionType.multipleChoice;
        });
        
        // If both single and multiple choice exist, only create sub-categories
        // Otherwise create the base category
        if (hasSingleChoice && hasMultipleChoice) {
          // Only create sub-categories, not the base category
          final singleId = '$baseId-single';
          categoryIdByName['$name-single'] = singleId;
          allCategories.add(cat.Category(
            id: singleId,
            name: '$name - 单选题',
            description: '$name - 单选题',
            icon: 'check_circle',
            createdAt: now,
            updatedAt: now,
          ));
          
          final multipleId = '$baseId-multiple';
          categoryIdByName['$name-multiple'] = multipleId;
          allCategories.add(cat.Category(
            id: multipleId,
            name: '$name - 多选题',
            description: '$name - 多选题',
            icon: 'done_all',
            createdAt: now,
            updatedAt: now,
          ));
        } else {
          // Only one type or no specific type, create base category
          allCategories.add(cat.Category(
            id: baseId,
            name: name,
            description: name,
            icon: 'book',
            createdAt: now,
            updatedAt: now,
          ));
        }
      }
      
      // Add operational skill categories
      for (final name in operationalCategoryNames) {
        final baseId = _slugify(name);
        if (!categoryIdByName.containsKey(name)) {
          categoryIdByName[name] = baseId;
          allCategories.add(cat.Category(
            id: baseId,
            name: name,
            description: name,
            icon: 'code',
            createdAt: now,
            updatedAt: now,
          ));
        }
      }
      _categories = allCategories;

      // Map questions
      _theoryQuestions = decoded.map<TheoryQuestion>((raw) {
        final m = raw as Map<String, dynamic>;
        final id = m['id'].toString();
        final typeStr = (m['type'] as String?)?.toLowerCase() ?? 'single_choice';
        final categoryName = (m['category'] as String?) ?? 'General';
        final qType = _mapType(typeStr);
        
        // Determine category ID based on question type
        String categoryId;
        if (qType == QuestionType.singleChoice) {
          categoryId = categoryIdByName['$categoryName-single'] ?? _slugify('$categoryName-single');
        } else if (qType == QuestionType.multipleChoice) {
          categoryId = categoryIdByName['$categoryName-multiple'] ?? _slugify('$categoryName-multiple');
        } else {
          categoryId = categoryIdByName[categoryName] ?? _slugify(categoryName);
        }
        
        final options = (m['options'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        final explanation = (m['explanation'] as String?) ?? '';
        final text = (m['question'] as String?) ?? '';
        final answerRaw = m['answer'];
        final correct = _mapAnswerToOptionText(answerRaw, options, qType);

        return TheoryQuestion(
          id: id,
          categoryId: categoryId,
          type: qType,
          text: text,
          explanation: explanation,
          options: options,
          correctAnswer: correct,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      // Map operational skill questions
      _codeQuestions = operationalDecoded.map<CodeQuestion>((raw) {
        final m = raw as Map<String, dynamic>;
        final id = m['id'].toString();
        final categoryName = (m['category'] as String?) ?? 'General';
        final categoryId = categoryIdByName[categoryName] ?? _slugify(categoryName);
        final text = (m['question'] as String?) ?? (m['title'] as String?) ?? '';
        final explanation = (m['explanation'] as String?) ?? '';
        final codeTemplate = (m['codeTemplate'] as String?) ?? '';
        final correctKeywords = (m['correctKeywords'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        final correctCode = (m['correctCode'] as String?) ?? '';
        final dataFiles = (m['dataFiles'] as List?)?.map((e) => e.toString()).toList();

        return CodeQuestion(
          id: id,
          categoryId: categoryId,
          text: text,
          explanation: explanation,
          codeTemplate: codeTemplate,
          correctKeywords: correctKeywords,
          correctCode: correctCode,
          dataFiles: dataFiles,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      await _saveData();
    } catch (e) {
      debugPrint('Failed to initialize from official asset: $e');
      // Fallback to empty if asset load fails
      _categories = [];
      _theoryQuestions = [];
      _codeQuestions = [];
    }
  }

  dynamic _parseCorrectAnswerFromDb(String? raw, List<String> options, QuestionType type) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    dynamic parsed = trimmed;
    if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
        (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
      try {
        parsed = json.decode(trimmed);
      } catch (_) {
        parsed = trimmed;
      }
    }
    return _mapAnswerToOptionText(parsed, options, type);
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

  // Helper: map type strings from dataset to enum
  QuestionType _mapType(String typeStr) {
    switch (typeStr) {
      case 'true_false':
      case 'truefalse':
      case 'tf':
        return QuestionType.trueFalse;
      case 'multiple_choice':
      case 'multiple':
      case 'mcq':
        return QuestionType.multipleChoice;
      case 'single_choice':
      case 'single':
      default:
        return QuestionType.singleChoice;
    }
  }

  // Helper: map answers like 'T'/'F', 'A', 'B', ['A','C'] or direct text to option text(s)
  dynamic _mapAnswerToOptionText(dynamic answer, List<String> options, QuestionType type) {
    // Map letters to indices
    String? indexToText(String s) {
      final upper = s.toUpperCase().trim();
      if (upper == 'T' || upper == 'F') {
        // True/False mapping: assume first option is True-like
        if (options.isNotEmpty) {
          return upper == 'T' ? options.first : options.length > 1 ? options[1] : options.first;
        }
      }
      if (upper.length == 1 && upper.codeUnitAt(0) >= 65 && upper.codeUnitAt(0) <= 90) {
        final idx = upper.codeUnitAt(0) - 65; // A->0
        if (idx >= 0 && idx < options.length) return options[idx];
      }
      // If direct text matches an option, return it
      final match = options.firstWhere(
        (o) => o.trim() == s.trim(),
        orElse: () => '',
      );
      return match.isNotEmpty ? match : s;
    }

    if (answer is List) {
      final mapped = answer.map((e) => indexToText(e.toString())).whereType<String>().toList();
      return mapped;
    } else if (answer is String) {
      // Handle comma-separated like "A,C" or letters like "ABCE"
      if (type == QuestionType.multipleChoice) {
        final parts = answer.contains(',')
            ? answer.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : answer.split('').where((e) => e.trim().isNotEmpty).toList();
        
        if (parts.isNotEmpty && parts.length > 1) {
          return parts.map((p) => indexToText(p)!).toList();
        }
      }
      return indexToText(answer) ?? answer;
    } else {
      return answer;
    }
  }

  String _slugify(String input) {
    final lower = input.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final trimmed = replaced.replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    if (trimmed.isEmpty) {
      return 'cat-${_fnv1a32Hex(input)}';
    }
    return trimmed;
  }

  String _fnv1a32Hex(String input) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811c9dc5;
    final bytes = utf8.encode(input);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final categoriesJson = json.encode(_categories.map((c) => c.toJson()).toList());
      await prefs.setString(_categoriesKey, categoriesJson);

      final theoryJson = json.encode(_theoryQuestions.map((q) => q.toJson()).toList());
      await prefs.setString(_theoryQuestionsKey, theoryJson);

      final codeJson = json.encode(_codeQuestions.map((q) => q.toJson()).toList());
      await prefs.setString(_codeQuestionsKey, codeJson);
    } catch (e) {
      debugPrint('Failed to save questions: $e');
    }
  }

  List<Question> getQuestionsByCategory(String categoryId) =>
      allQuestions.where((q) => q.categoryId == categoryId).toList();

  List<Question> getQuestionsBySection(QuestionSection section) =>
      allQuestions.where((q) => q.section == section).toList();

  Question? getQuestionById(String id) {
    try {
      return allQuestions.firstWhere((q) => q.id == id);
    } catch (e) {
      return null;
    }
  }

  cat.Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // 清除缓存，强制重新加载题库
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_categoriesKey);
      await prefs.remove(_theoryQuestionsKey);
      await prefs.remove(_codeQuestionsKey);
      debugPrint('Question bank cache cleared');
    } catch (e) {
      debugPrint('Failed to clear cache: $e');
    }
  }
}
