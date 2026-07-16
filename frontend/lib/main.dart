import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/dashboard.dart';
import 'screens/creator.dart';
import 'screens/workspace.dart';

void main() {
  runApp(const AiStoryGeneratorApp());
}

final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const DashboardScreen();
      },
    ),
    GoRoute(
      path: '/create',
      builder: (BuildContext context, GoRouterState state) {
        return const CreatorScreen();
      },
    ),
    GoRoute(
      path: '/workspace',
      builder: (BuildContext context, GoRouterState state) {
        return const WorkspaceScreen();
      },
    ),
  ],
);

class AiStoryGeneratorApp extends StatelessWidget {
  const AiStoryGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Uncensored AI Story Generator',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
