import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_coach/theme.dart';
import 'package:ai_coach/nav.dart';
import 'package:ai_coach/services/user_progress_service.dart';
import 'package:ai_coach/services/user_statistics_service.dart';
import 'package:ai_coach/services/question_bank_service.dart';
import 'package:ai_coach/services/mistake_notebook_service.dart';
import 'package:ai_coach/services/exam_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // ignore: avoid_print
  print('Supabase initialized. currentSession=${Supabase.instance.client.auth.currentSession}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProgressService()),
        ChangeNotifierProvider(create: (_) => UserStatisticsService()),
        ChangeNotifierProvider(create: (_) => QuestionBankService()),
        ChangeNotifierProvider(create: (_) => MistakeNotebookService()),
        ChangeNotifierProvider(create: (_) => ExamService()),
      ],
      child: MaterialApp.router(
        title: 'AI Trainer Exam Prep',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
