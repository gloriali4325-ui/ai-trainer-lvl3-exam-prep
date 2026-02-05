import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/services/question_bank_service.dart';
import 'package:ai_coach/services/mistake_notebook_service.dart';
import 'package:ai_coach/services/user_statistics_service.dart';
import 'package:ai_coach/theme.dart';
import 'package:ai_coach/widgets/code_runner.dart';

class OperationalSkillsScreen extends StatefulWidget {
  final String categoryId;

  const OperationalSkillsScreen({
    super.key,
    required this.categoryId,
  });

  @override
  State<OperationalSkillsScreen> createState() => _OperationalSkillsScreenState();
}

class _OperationalSkillsScreenState extends State<OperationalSkillsScreen> {
  late List<CodeQuestion> _questions;
  int _currentIndex = 0;
  late Map<String, bool> _submittedStates;
  late Map<String, String> _userAnswers;
  late Map<String, bool> _isCorrectStates;

  Future<void> _submitAnswer(CodeQuestion question, String userCode) async {
    // 检查答案是否包含所有关键词
    final userCodeNormalized = userCode.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final isCorrect = question.correctKeywords.every((keyword) {
      final keywordNormalized = keyword.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      return userCodeNormalized.contains(keywordNormalized);
    });

    if (!mounted) return;

    // 在异步操作前获取 services
    final statisticsService = context.read<UserStatisticsService>();
    final mistakeService = context.read<MistakeNotebookService>();

    setState(() {
      _submittedStates[question.id] = true;
      _isCorrectStates[question.id] = isCorrect;
      _userAnswers[question.id] = userCode;
    });

    // 记录用户答题进度
    await statisticsService.recordQuestionAttempt(isCorrect);

    // 如果答案错误，加入错题本
    if (!isCorrect) {
      await mistakeService.addMistake(
        userId: 'current_user', // 实际应该从用户管理获取
        questionId: question.id,
        userAnswer: userCode,
      );
    }

  }

  void _loadQuestions() {
    final questionBank = context.read<QuestionBankService>();
    _questions = questionBank.codeQuestions;
    
    _submittedStates = {};
    _userAnswers = {};
    _isCorrectStates = {};
    
    if (widget.categoryId.isNotEmpty) {
      final index = _questions.indexWhere((q) => q.categoryId == widget.categoryId);
      if (index >= 0) {
        _currentIndex = index;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('操作技能练习')),
        body: Center(
          child: Text(
            '此类别下没有操作技能题目',
            style: context.textStyles.bodyLarge,
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentIndex];
    final isSubmitted = _submittedStates[currentQuestion.id] ?? false;
    final userCode = _userAnswers[currentQuestion.id] ?? currentQuestion.codeTemplate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('操作技能练习'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '第 ${_currentIndex + 1}/${_questions.length} 题',
                      style: context.textStyles.labelLarge,
                    ),
                  ],
                ),
                AppSpacing.sm.verticalSpace,
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _questions.length,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  _buildQuestionSection(currentQuestion),
                  if (currentQuestion.dataFiles?.isNotEmpty ?? false)
                    _buildDataAttachmentSection(currentQuestion),
                  _buildCodeEditorSection(currentQuestion, userCode),
                  if (isSubmitted)
                    _buildExplanationSection(currentQuestion),
                ],
              ),
            ),
          ),
          _buildBottomBar(currentQuestion, isSubmitted, userCode),
        ],
      ),
    );
  }

  Widget _buildQuestionSection(CodeQuestion question) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '题目说明',
            style: context.textStyles.titleMedium?.semiBold,
          ),
          AppSpacing.sm.verticalSpace,
          Text(
            question.text,
            style: context.textStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDataAttachmentSection(CodeQuestion question) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.md.verticalSpace,
          Text(
            '📎 数据附件',
            style: context.textStyles.titleMedium?.semiBold,
          ),
          AppSpacing.sm.verticalSpace,
          Column(
            children: question.dataFiles!
                .map((fileName) => _buildDataFileCard(fileName))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataFileCard(String fileName) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(
          Icons.description,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          fileName,
          style: context.textStyles.bodyMedium?.semiBold,
        ),
        subtitle: Text(
          'CSV 数据文件',
          style: context.textStyles.labelSmall,
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _showDataPreview(fileName);
        },
      ),
    );
  }

  void _showDataPreview(String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('数据预览: $fileName'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '📋 字段说明',
                style: context.textStyles.titleSmall?.semiBold,
              ),
              AppSpacing.md.verticalSpace,
              _buildFileFieldsInfo(fileName),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileFieldsInfo(String fileName) {
    final fieldsInfo = _getDataFileFields(fileName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fieldsInfo.entries
          .map((e) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${e.key}',
                      style: context.textStyles.bodySmall?.semiBold,
                    ),
                    Text(
                      e.value,
                      style: context.textStyles.labelSmall?.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Map<String, String> _getDataFileFields(String fileName) {
    if (fileName.contains('patient')) {
      return {
        'PatientID': '患者ID',
        'Age': '年龄',
        'BMI': '体重指数',
        'BloodPressure': '血压',
        'Cholesterol': '胆固醇水平',
        'DaysInHospital': '住院天数',
      };
    } else if (fileName.contains('sensor')) {
      return {
        'SensorID': '传感器ID',
        'Timestamp': '时间戳',
        'SensorType': '传感器类型',
        'Value': '传感器读数',
        'Location': '传感器安装位置',
      };
    }
    return {};
  }

  Widget _buildCodeEditorSection(CodeQuestion question, String userCode) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: CodeRunner(
        question: question,
        initialCode: userCode,
        onCodeChanged: (code) {
          setState(() {
            _userAnswers[question.id] = code;
          });
        },
      ),
    );
  }

  Widget _buildExplanationSection(CodeQuestion question) {
    return Container(
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
      padding: AppSpacing.paddingMd,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.md.verticalSpace,
            Text(
              '✓ 答案解析',
              style: context.textStyles.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.md.verticalSpace,
            // 参考代码区域已移除：仅保留用户输入的代码编辑区域
            Text(
              '📚 知识点解析',
              style: context.textStyles.titleSmall?.semiBold,
            ),
            AppSpacing.sm.verticalSpace,
            Text(
              question.explanation,
              style: context.textStyles.bodySmall?.withColor(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.md.verticalSpace,
            Text(
              '🔑 关键词要求',
              style: context.textStyles.titleSmall?.semiBold,
            ),
            AppSpacing.sm.verticalSpace,
            Wrap(
              spacing: 8,
              children: question.correctKeywords
                  .map((keyword) => Chip(
                        label: Text(keyword),
                        backgroundColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                      ))
                  .toList(),
            ),
            AppSpacing.md.verticalSpace,
            Text(
              '✓ 完整正确代码',
              style: context.textStyles.titleSmall?.semiBold,
            ),
            AppSpacing.sm.verticalSpace,
            Container(
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: SelectableText(
                question.correctCode,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(CodeQuestion question, bool isSubmitted, String userCode) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isSubmitted)
            FilledButton.icon(
              onPressed: () => _submitAnswer(question, userCode),
              icon: const Icon(Icons.check),
              label: const Text('提交答案'),
            )
          else
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _submittedStates[question.id] = false;
                });
              },
              icon: const Icon(Icons.edit),
              label: const Text('重新作答'),
            ),
          AppSpacing.sm.verticalSpace,
          // 显示答案正确/错误的提示
          if (isSubmitted && _isCorrectStates[question.id] == true)
            Container(
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  AppSpacing.sm.horizontalSpace,
                  const Expanded(
                    child: Text(
                      '✓ 答案正确！',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else if (isSubmitted && _isCorrectStates[question.id] == false)
            Container(
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.red),
                  AppSpacing.sm.horizontalSpace,
                  const Expanded(
                    child: Text(
                      '✗ 答案错误，已加入错题本',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          AppSpacing.md.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _currentIndex > 0
                    ? () {
                        setState(() => _currentIndex--);
                      }
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('上一题'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_questions.length}',
                  style: context.textStyles.labelMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _currentIndex < _questions.length - 1
                    ? () {
                        setState(() => _currentIndex++);
                      }
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('下一题'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on double {
  Widget get verticalSpace => SizedBox(height: this);
  Widget get horizontalSpace => SizedBox(width: this);
}
