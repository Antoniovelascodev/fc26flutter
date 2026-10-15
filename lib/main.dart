import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
import 'screens/head_to_head_screen.dart';
import 'screens/players_screen.dart';
import 'screens/league_screen.dart';
import 'screens/new_match_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/squads_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.loadKey();
  Api.warmUp(); // not awaited: just wakes the server up while the UI loads
  runApp(const MegaLigueApp());
}

class MegaLigueApp extends StatelessWidget {
  const MegaLigueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Artillería League',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121C42), AppColors.ink, Color(0xFF080D1E)],
            stops: [0, 0.45, 1],
          ),
        ),
        child: child,
      ),
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _restoreTab();
  }

  /// If the browser reloads the page, come back to the screen you were on.
  Future<void> _restoreTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('tab_index');
      if (saved != null && saved >= 0 && saved < _titles.length && mounted) {
        setState(() => _index = saved);
      }
    } catch (_) {
      // Not important.
    }
  }

  void _go(int index) {
    _go(index);
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setInt('tab_index', index))
        .catchError((_) => true);
  }

  static const _titles = [
    'Artillería League',
    'New match',
    'Head to head',
    'Leagues',
    'Squads',
    'Players',
  ];

  Future<void> _editKey() async {
    final controller = TextEditingController(text: Api.apiKey);
    final adminController = TextEditingController(text: Api.adminKey);
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Group access key', style: displayStyle(size: 28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Only needed to delete things (matches, leagues, squads). Everything else works without it.',
              style: TextStyle(color: AppColors.textDim, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Access key'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: adminController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin key (only the owner, optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await Api.saveAdminKey(adminController.text);
              if (ctx.mounted) Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('Save key'),
          ),
        ],
      ),
    );
    if (key == null) return;
    await Api.saveKey(key);
    if (!mounted) return;
    setState(() {});
    notifyDataChanged();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Access key saved')));
  }

  Future<void> _backup() async {
    if (!Api.hasKey) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Set the access key first (key icon) to download a backup.')));
      return;
    }
    String json;
    try {
      json = await Api.exportBackup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final filename = 'fc26-backup-${now.year}-${two(now.month)}-${two(now.day)}.json';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Backup ready', style: displayStyle(size: 28)),
        content: Text(
          canDownloadFile
              ? 'Save the file somewhere safe (your PC, a private cloud folder). '
                  'Do it every week or after a big session.'
              : 'Copy the backup and paste it into a file named $filename. '
                  'Keep it somewhere safe.',
          style: const TextStyle(color: AppColors.textDim, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (canDownloadFile)
            TextButton(
              onPressed: () {
                downloadTextFile(filename, json);
                Navigator.pop(ctx);
              },
              child: const Text('Download file'),
            )
          else
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Copy backup'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (!demoMode)
            IconButton(
              tooltip: 'Download backup',
              icon: const Icon(Icons.download_outlined, color: AppColors.textDim),
              onPressed: _backup,
            ),
          if (!demoMode)
            IconButton(
              tooltip: 'Access key',
              icon: Icon(
                Api.hasKey ? Icons.vpn_key : Icons.vpn_key_outlined,
                color: Api.hasKey ? AppColors.text : AppColors.textDim,
              ),
              onPressed: _editKey,
            ),
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
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: waking,
            builder: (context, isWaking, _) => isWaking
                ? Container(
                    width: double.infinity,
                    color: AppColors.surfaceHi,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Waking up the server, this can take up to a minute...',
                            style: TextStyle(fontSize: 13, color: AppColors.textDim),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                RankingScreen(),
                NewMatchScreen(),
                HeadToHeadScreen(),
                LeagueScreen(),
                SquadsScreen(),
                PlayersScreen(),
              ],
            ),
          ),
        ],
      ),
      // Only the two screens used all the time live in the bottom bar; the rest are in the drawer.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index == 0 ? 0 : (_index == 1 ? 1 : 2),
        onDestinationSelected: (i) {
          if (i == 2) {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            _go(i);
          }
        },
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
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu_open),
            label: 'Menu',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    Widget item(int index, IconData icon, String label) => ListTile(
          leading: Icon(icon, color: _index == index ? AppColors.text : AppColors.textDim),
          title: Text(label,
              style: TextStyle(
                  fontWeight: _index == index ? FontWeight.w800 : FontWeight.w500)),
          selected: _index == index,
          selectedTileColor: AppColors.surfaceHi,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: () {
            Navigator.pop(context);
            setState(() => _index = index);
          },
        );
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
              child: Text('Artillería League', style: displayStyle(size: 34)),
            ),
            item(0, Icons.leaderboard, 'Table'),
            item(1, Icons.sports_soccer, 'New match'),
            item(3, Icons.emoji_events, 'Leagues'),
            item(4, Icons.groups, 'Squads'),
            item(5, Icons.person_search, 'Players'),
            item(2, Icons.compare_arrows, 'Head to head'),
            if (!demoMode) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined, color: AppColors.textDim),
                title: const Text('Download backup'),
                onTap: () {
                  Navigator.pop(context);
                  _backup();
                },
              ),
              ListTile(
                leading: Icon(Api.hasKey ? Icons.vpn_key : Icons.vpn_key_outlined,
                    color: AppColors.textDim),
                title: const Text('Access key'),
                onTap: () {
                  Navigator.pop(context);
                  _editKey();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
