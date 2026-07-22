import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/dashboard.dart';
import 'screens/creator.dart';
import 'screens/director.dart';
import 'screens/story_details.dart';
import 'screens/edit_chapter.dart';
import 'screens/settings.dart';
import 'screens/zen_reader.dart';
import 'screens/character_chat.dart';
import 'screens/group_chat_screen.dart';
import 'screens/persona_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'screens/auth.dart';
import 'theme_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

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
    GoRoute(
      path: '/story/:id/edit_chapter',
      builder: (BuildContext context, GoRouterState state) {
        final storyId = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>;
        return EditChapterScreen(
          storyId: storyId,
          chapterNumber: extra['chapterNumber'] as int,
          chapterData: extra['chapterData'] as Map<String, dynamic>,
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (BuildContext context, GoRouterState state) {
        return const SettingsScreen();
      },
    ),
    GoRoute(
      path: '/persona',
      builder: (BuildContext context, GoRouterState state) {
        return PersonaScreen();
      },
    ),
    GoRoute(
      path: '/zen_reader',
      builder: (BuildContext context, GoRouterState state) {
        final extra = state.extra as Map<String, dynamic>;
        return ZenReaderScreen(
          title: extra['title'] as String,
          content: extra['content'] as String,
          backgroundImage: extra['backgroundImage'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/character_chat',
      builder: (BuildContext context, GoRouterState state) {
        final extra = state.extra as Map<String, dynamic>;
        return CharacterChatScreen(
          characterId: extra['characterId'] as String,
          characterName: extra['characterName'] as String,
          backgroundImage: extra['backgroundImage'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/group_chat',
      builder: (BuildContext context, GoRouterState state) {
        final extra = state.extra as Map<String, dynamic>;
        return GroupChatScreen(
          storyId: extra['storyId'] as String,
          sessionId: extra['sessionId'] as String,
        );
      },
    ),
  ],
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: AiStoryGeneratorApp(router: router),
    ),
  );
}

class AiStoryGeneratorApp extends StatelessWidget {
  final GoRouter router;
  
  const AiStoryGeneratorApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp.router(
          title: 'Uncensored AI Story Generator',
          theme: themeProvider.getThemeData(),
          routerConfig: router,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
          ],
        );
      },
    );
  }
}
