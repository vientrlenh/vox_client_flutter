import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';



class AppRouter {
  static const String login = "/login";

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case login: 
      return MaterialPageRoute(
        builder: (_) => const LoginScreen()
      );
    default: 
      return MaterialPageRoute(
        builder: (_) => const LoginScreen()
      );
  }
}
}

