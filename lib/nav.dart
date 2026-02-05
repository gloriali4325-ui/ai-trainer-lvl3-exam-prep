import 'package:go_router/go_router.dart';
import 'package:ai_coach/screens/auth_gate.dart';
import 'package:ai_coach/screens/login_screen.dart';
import 'package:ai_coach/screens/register_screen.dart';
import 'package:ai_coach/screens/question_drilling_screen.dart';
import 'package:ai_coach/screens/categorized_training_screen.dart';
import 'package:ai_coach/screens/category_practice_screen.dart';
import 'package:ai_coach/screens/operational_skills_screen.dart';
import 'package:ai_coach/screens/operational_skills_drilling_screen.dart';
import 'package:ai_coach/screens/mock_exam_screen.dart';
import 'package:ai_coach/screens/exam_result_screen.dart';
import 'package:ai_coach/screens/mistake_notebook_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AuthGate(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.drilling,
        name: 'drilling',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: QuestionDrillingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.drillingOperational,
        name: 'drilling-operational',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: OperationalSkillsDrillingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.categorized,
        name: 'categorized',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: CategorizedTrainingScreen(),
        ),
      ),
      GoRoute(
        path: '/category/:id',
        name: 'category-practice',
        pageBuilder: (context, state) {
          final categoryId = state.pathParameters['id']!;
          return NoTransitionPage(
            child: CategoryPracticeScreen(categoryId: categoryId),
          );
        },
      ),
      GoRoute(
        path: '/operational-skills/:id',
        name: 'operational-skills',
        pageBuilder: (context, state) {
          final categoryId = state.pathParameters['id']!;
          return NoTransitionPage(
            child: OperationalSkillsScreen(categoryId: categoryId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.mockExam,
        name: 'mock-exam',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: MockExamScreen(),
        ),
      ),
      GoRoute(
        path: '/exam-result/:id',
        name: 'exam-result',
        pageBuilder: (context, state) {
          final resultId = state.pathParameters['id']!;
          return NoTransitionPage(
            child: ExamResultScreen(resultId: resultId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.mistakes,
        name: 'mistakes',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: MistakeNotebookScreen(),
        ),
      ),
    ],
  );
}

class AppRoutes {
  static const String home = '/';
  static const String drilling = '/drilling';
  static const String drillingOperational = '/drilling-operational';
  static const String categorized = '/categorized';
  static const String mockExam = '/mock-exam';
  static const String mistakes = '/mistakes';
  static const String login = '/login';
  static const String register = '/register';
}
