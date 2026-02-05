import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/services/user_progress_service.dart';
import 'package:ai_coach/screens/home_screen.dart';
import 'package:ai_coach/screens/login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final userService = context.read<UserProgressService>();
    await userService.initialize();
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProgressService>(
      builder: (context, userService, _) {
        if (!_initialized || userService.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userService.currentUser == null) {
          return const LoginScreen();
        }

        return const HomePage();
      },
    );
  }
}
