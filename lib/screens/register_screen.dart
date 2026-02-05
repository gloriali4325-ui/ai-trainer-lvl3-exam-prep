import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_coach/services/user_progress_service.dart';
import 'package:ai_coach/theme.dart';
import 'package:ai_coach/nav.dart';
import 'package:ai_coach/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorText = '请输入有效邮箱';
      });
      return;
    }
    final password = _passwordController.text;
    if (password != _confirmController.text) {
      setState(() {
        _errorText = '两次输入的密码不一致';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    final authService = AuthService();
    try {
      final authResult = await authService.signUp(
        email: email,
        password: password,
        nickname: _displayNameController.text.isNotEmpty
            ? _displayNameController.text
            : _usernameController.text,
      );

      if (!mounted) return;

      final userService = context.read<UserProgressService>();
      await userService.loadUserForId(
        authResult.user?.id ?? '',
        fallbackName: _displayNameController.text.isNotEmpty
            ? _displayNameController.text
            : _usernameController.text,
      );

      setState(() {
        _isSubmitting = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注册成功，请登录')),
      );
      context.go(AppRoutes.login);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = '注册失败，请稍后重试';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('注册账号'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSpacing.md.verticalSpace,
              Text(
                '创建新账号',
                style: context.textStyles.headlineSmall?.bold,
              ),
              AppSpacing.sm.verticalSpace,
              Text(
                '填写信息后即可开始练习',
                style: context.textStyles.bodyMedium?.withColor(
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.xl.verticalSpace,
              TextField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '用户名',
                ),
              ),
              AppSpacing.md.verticalSpace,
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '邮箱',
                ),
              ),
              AppSpacing.md.verticalSpace,
              TextField(
                controller: _displayNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '昵称（可选）',
                ),
              ),
              AppSpacing.md.verticalSpace,
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '密码',
                ),
              ),
              AppSpacing.md.verticalSpace,
              TextField(
                controller: _confirmController,
                obscureText: true,
                onSubmitted: (_) => _handleRegister(),
                decoration: const InputDecoration(
                  labelText: '确认密码',
                ),
              ),
              if (_errorText != null) ...[
                AppSpacing.md.verticalSpace,
                Text(
                  _errorText!,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              AppSpacing.lg.verticalSpace,
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _handleRegister,
                  child: Text(_isSubmitting ? '注册中...' : '注册'),
                ),
              ),
              AppSpacing.md.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '已有账号？',
                    style: context.textStyles.bodySmall,
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('登录'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
extension on double {
  Widget get verticalSpace => SizedBox(height: this);
}
