import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> stories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      final data = await ApiService.getStories();
      setState(() {
        stories = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading stories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stories Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/create'),
          )
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : stories.isEmpty 
          ? const Center(child: Text("No stories yet. Click + to create one."))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                return Card(
                  elevation: 4,
                  child: InkWell(
                    onTap: () => context.go('/workspace'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            color: Colors.deepPurple.shade800,
                            child: const Icon(Icons.book, size: 64, color: Colors.white54),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            story['title'] ?? 'Untitled',
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Text(
                            '${story['genre']} • ${story['tone']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create'),
        label: const Text('New Story'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
