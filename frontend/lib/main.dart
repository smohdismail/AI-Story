import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/dashboard.dart';
import 'screens/creator.dart';
import 'screens/director.dart';
import 'screens/story_details.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final hasToken = prefs.getString('token') != null;

  final router = GoRouter(
    initialLocation: hasToken ? '/' : '/auth',
    routes: <RouteBase>[
      GoRoute(
        path: '/auth',
        builder: (BuildContext context, GoRouterState state) {
          return const AuthScreen();
        },
      ),
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
      path: '/story/:id',
      builder: (BuildContext context, GoRouterState state) {
        final storyId = state.pathParameters['id']!;
        return StoryDetailsScreen(storyId: storyId);
      },
    ),
    GoRoute(
      path: '/story/:id/director',
      builder: (BuildContext context, GoRouterState state) {
        final storyId = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>?;
        final chapterCount = extra?['chapterCount'] as int? ?? 0;
        return DirectorScreen(storyId: storyId, currentChapterCount: chapterCount);
      },
    ),
  ],
  );
  
  runApp(AiStoryGeneratorApp(router: router));
}

class AiStoryGeneratorApp extends StatelessWidget {
  final GoRouter router;
  
  const AiStoryGeneratorApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Uncensored AI Story Generator',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
