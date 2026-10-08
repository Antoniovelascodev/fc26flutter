import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/head_to_head_screen.dart';
import 'screens/history_screen.dart';
import 'screens/new_match_screen.dart';
import 'screens/ranking_screen.dart';
import 'theme.dart';

void main() {
  runApp(const MegaLigueApp());
}

class MegaLigueApp extends StatelessWidget {
  const MegaLigueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FC26 MegaLigue',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['MegaLigue', 'New match', 'Head to head', 'History'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (demoMode)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Demo data',
                    style: TextStyle(fontSize: 12, color: AppColors.textDim),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          RankingScreen(),
          NewMatchScreen(),
          HeadToHeadScreen(),
          HistoryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Table',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: 'New match',
          ),
          NavigationDestination(
            icon: Icon(Icons.compare_arrows),
            label: 'Head to head',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
