import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_coach/models/question.dart';
import 'package:ai_coach/services/python_runner.dart';
import 'package:ai_coach/theme.dart';

class CodeRunner extends StatefulWidget {
  final CodeQuestion question;
  final String? initialCode;
  final ValueChanged<String> onCodeChanged;

  const CodeRunner({
    super.key,
    required this.question,
    required this.initialCode,
    required this.onCodeChanged,
  });

  @override
  State<CodeRunner> createState() => _CodeRunnerState();
}

class _CodeRunnerState extends State<CodeRunner> {
  late final TextEditingController _controller;
  String? _output;
  bool _isRunning = false;
  static const String _placeholder = '_____________';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void didUpdateWidget(CodeRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _controller.text = widget.initialCode ?? '';
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runCode() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _output = '请输入代码后再运行。';
      });
      return;
    }

    final build = _buildRunnableCode(input);
    if (build.missingCount > 0) {
      setState(() {
        _output = '还有 ${build.missingCount} 处空未填，无法运行。';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _output = null;
    });

    final code = build.code;
    final csvManifest = _buildCsvManifest(code);
    final result = await PythonRunner.run(code, csvManifest: csvManifest);
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _output = result;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) {
      setState(() {
        _output = '剪贴板为空。';
      });
      return;
    }
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    final build = _buildRunnableCode(text);
    widget.onCodeChanged(build.code);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💻 输入你的代码：',
          style: context.textStyles.titleMedium?.semiBold,
        ),
        AppSpacing.sm.verticalSpace,
        TextField(
          controller: _controller,
          minLines: 8,
          maxLines: null,
          onChanged: (value) {
            final build = _buildRunnableCode(value);
            widget.onCodeChanged(build.code);
          },
          decoration: InputDecoration(
            hintText: '在此输入代码...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          style: context.textStyles.bodyMedium?.copyWith(fontFamily: 'monospace'),
        ),
        AppSpacing.md.verticalSpace,
        Row(
          children: [
            FilledButton.icon(
              onPressed: _isRunning ? null : _runCode,
              icon: const Icon(Icons.play_arrow),
              label: Text(_isRunning ? '运行中...' : '运行代码'),
            ),
            AppSpacing.sm.horizontalSpace,
            OutlinedButton.icon(
              onPressed: _isRunning ? null : _pasteFromClipboard,
              icon: const Icon(Icons.paste),
              label: const Text('粘贴'),
            ),
            AppSpacing.md.horizontalSpace,
            if (kIsWeb)
              Text(
                '首次运行需加载Python环境',
                style: context.textStyles.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (_output != null) ...[
          AppSpacing.md.verticalSpace,
          Text(
            '运行输出：',
            style: context.textStyles.labelLarge,
          ),
          AppSpacing.sm.verticalSpace,
          Container(
            width: double.infinity,
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: SelectableText(
              _output ?? '',
              style: context.textStyles.bodyMedium?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ],
    );
  }

  _BuildResult _buildRunnableCode(String input) {
    if (!widget.question.codeTemplate.contains(_placeholder)) {
      return _BuildResult(code: input, missingCount: 0);
    }

    if (input.contains(_placeholder)) {
      return _BuildResult(code: input, missingCount: _countPlaceholders(input));
    }

    if (_looksLikeFullCode(input)) {
      return _BuildResult(code: input, missingCount: 0);
    }

    final parts = input
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    var index = 0;
    var missing = 0;
    final merged = widget.question.codeTemplate.replaceAllMapped(
      RegExp(RegExp.escape(_placeholder)),
      (_) {
        if (index >= parts.length) {
          missing += 1;
          return _placeholder;
        }
        final value = parts[index];
        index += 1;
        return value;
      },
    );

    return _BuildResult(code: merged, missingCount: missing);
  }

  int _countPlaceholders(String text) {
    final matcher = RegExp(RegExp.escape(_placeholder));
    return matcher.allMatches(text).length;
  }

  bool _looksLikeFullCode(String input) {
    final normalized = input.trimLeft();
    return normalized.startsWith('import ') || normalized.startsWith('from ');
  }

  String _buildCsvManifest(String code) {
    final regex = RegExp(r'''['"]([^'"\n]+?\.csv)['"]''');
    final matches = regex.allMatches(code);
    final entries = <Map<String, Object>>[];
    final seen = <String>{};
    const roots = [
      'assets/operational_skills/1.1.1/',
      'assets/operational_skills/1.1.2/',
      'assets/operational_skills/',
      'assets/',
    ];

    for (final match in matches) {
      final raw = match.group(1);
      if (raw == null || raw.isEmpty) continue;
      final name = raw.split('/').last;
      if (seen.contains(name)) continue;
      seen.add(name);

      final urls = <String>[];
      if (raw.contains('/')) {
        urls.add(Uri.base.resolve(raw).toString());
      }
      for (final root in roots) {
        urls.add(Uri.base.resolve('$root$name').toString());
      }

      entries.add({
        'name': name,
        'urls': urls,
      });
    }

    if (entries.isEmpty) {
      return '';
    }
    return const JsonEncoder().convert(entries);
  }
}

extension on double {
  Widget get horizontalSpace => SizedBox(width: this);
  Widget get verticalSpace => SizedBox(height: this);
}

class _BuildResult {
  final String code;
  final int missingCount;

  const _BuildResult({
    required this.code,
    required this.missingCount,
  });
}
