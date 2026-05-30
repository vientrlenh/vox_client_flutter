import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/profile/presentation/profile_screen.dart';



class AppRouter {
  static const String login = "/login";
  static const String profile = "/profile";

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case login: 
      return MaterialPageRoute(
        builder: (_) => const LoginScreen()
      );
    case profile:
      return MaterialPageRoute(
        builder: (_) => const ProfileScreen() 
      );
    default: 
      return MaterialPageRoute(
        builder: (_) => const LoginScreen()
      );
  }
}
}

