import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/main_wrapper.dart';
import 'features/predict/scan_screen.dart';
import 'features/predict/result_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/assessment/assessment_form_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: const DFUApp(),
    ),
  );
}

class DFUApp extends StatelessWidget {
  const DFUApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DFU Screening',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/main-wrapper': (context) => const MainWrapper(),
        '/dashboard': (context) => const MainWrapper(),
        '/scan': (context) => const ScanScreen(),
        '/results': (context) => const ResultScreen(),
        '/assessment': (context) => const AssessmentFormScreen(),
      },
    );
  }
}
