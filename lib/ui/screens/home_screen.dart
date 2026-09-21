import 'package:flutter/material.dart';
import 'capture_screen.dart';
import 'history_screen.dart';
import 'reflection_flow_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          TodayScreen(),
          HistoryScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const CaptureScreen(),
            fullscreenDialog: true,
          ));
        },
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Theme.of(context).colorScheme.surface,
        elevation: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.today, color: _currentIndex == 0 ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.onSurfaceVariant),
              onPressed: () => setState(() => _currentIndex = 0),
            ),
            IconButton(
              icon: Icon(Icons.history, color: _currentIndex == 1 ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.onSurfaceVariant),
              onPressed: () => setState(() => _currentIndex = 1),
            ),
          ],
        ),
      ),
    );
  }
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Your Reflection Cycle',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          // Placeholder for cycle status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('In Progress', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  Text('Capturing thoughts...', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReflectionFlowScreen(cycleId: 'current-cycle'),
                          ),
                        );
                      },
                      child: const Text('Begin Reflection'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
