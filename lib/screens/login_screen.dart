import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_coach/services/user_progress_service.dart';
import 'package:ai_coach/theme.dart';
import 'package:ai_coach/nav.dart';
import 'package:ai_coach/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting) return;
    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    final authService = AuthService();
    try {
      final authResult = await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final userService = context.read<UserProgressService>();
      await userService.loadUserForId(
        authResult.user?.id ?? '',
        fallbackName: _emailController.text.trim(),
      );

      setState(() {
        _isSubmitting = false;
      });

      context.go(AppRoutes.home);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = '登录失败，请稍后重试';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSpacing.lg.verticalSpace,
              Text(
                '欢迎回来',
                style: context.textStyles.headlineMedium?.bold,
              ),
              AppSpacing.sm.verticalSpace,
              Text(
                '登录以继续使用训练系统',
                style: context.textStyles.bodyMedium?.withColor(
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.xl.verticalSpace,
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
                controller: _passwordController,
                obscureText: true,
                onSubmitted: (_) => _handleLogin(),
                decoration: const InputDecoration(
                  labelText: '密码',
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
                  onPressed: _isSubmitting ? null : _handleLogin,
                  child: Text(_isSubmitting ? '登录中...' : '登录'),
                ),
              ),
              AppSpacing.md.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '还没有账号？',
                    style: context.textStyles.bodySmall,
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.register),
                    child: const Text('注册'),
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
