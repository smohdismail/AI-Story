import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'community_feed_screen.dart';
import 'character_lounge_screen.dart';
import 'profile_studio_screen.dart';
import '../widgets/mini_audio_player.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    DashboardScreen(),
    CommunityFeedScreen(),
    CharacterLoungeScreen(),
    ProfileStudioScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent continuous audiobook player bar
          const MiniAudioPlayer(),
          // 4-section novel navigation bar
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book, color: Colors.amber),
                label: 'My Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore, color: Colors.cyanAccent),
                label: 'Discover',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum, color: Colors.pinkAccent),
                label: 'Lounge',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: Colors.purpleAccent),
                label: 'Studio',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
