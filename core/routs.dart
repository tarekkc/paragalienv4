import 'package:flutter/material.dart';
import 'package:paragalien/views/admin/admin_home.dart';
import 'package:paragalien/views/auth/login_screen.dart';
import 'package:paragalien/views/client/client_home.dart';

class AppRoutes {
  // Removed signup route
  static const String login = '/login';
  static const String adminHome = '/admin';
  static const String clientHome = '/client';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case adminHome:
        return MaterialPageRoute(builder: (_) => const AdminHome());
      case clientHome:
        return MaterialPageRoute(builder: (_) => const ClientHome());
      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Page not found!')),
      ),
    );
  }

  // Simplified route map
  static final Map<String, WidgetBuilder> all = {
    login: (context) => const LoginScreen(),
    adminHome: (context) => const AdminHome(),
    clientHome: (context) => const ClientHome(),
  };
}

