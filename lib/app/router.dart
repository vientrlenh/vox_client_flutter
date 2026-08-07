import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/teacher_exam/presentation/teacher_exam_list_screen.dart';
import '../app/main_shell.dart';


class AppRouter {
  static const String shell = "/";
  static const String login = "/login";
  static const String profile = "/profile";
  static const String teacherExams = "/teacher/exams";

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case login: 
      return MaterialPageRoute(
        builder: (_) => const LoginScreen()
      );
    case shell:
      return MaterialPageRoute(
        builder: (_) => const MainShell()
      );
    case profile:
      return MaterialPageRoute(
        builder: (_) => const ProfileScreen() 
      );
    case teacherExams:
      return MaterialPageRoute(
        builder: (_) => const TeacherExamListScreen()
      );
    default: 
      return MaterialPageRoute(
        builder: (_) => const LoginScreen()
      );
  }
}
}

