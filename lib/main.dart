// Snooker Manager - Khata, Century scoreboard, Report, Settings.
import 'package:flutter/material.dart';

import 'century_page.dart';
import 'db.dart';
import 'khata_page.dart';
import 'report_page.dart';
import 'settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await Db.open();
  runApp(SnookerApp(db: db));
}

class SnookerApp extends StatelessWidget {
  const SnookerApp({super.key, required this.db});
  final Db db;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snooker Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1B5E20), useMaterial3: true),
      home: HomeShell(db: db),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.db});
  final Db db;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int? _selectedGame;
  String _club = 'Snooker Club';

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  Future<void> _loadClub() async {
    final name = await widget.db.getSetting('club_name', 'Snooker Club');
    if (!mounted) return;
    setState(() => _club = name);
  }

  // Har tab badalne par page naye sire se banta hai, is liye data hamesha taaza dikhta hai.
  Widget _page() {
    switch (_index) {
      case 0:
        return KhataPage(key: const ValueKey('khata'), db: widget.db);
      case 1:
        return CenturyPage(
          key: const ValueKey('century'),
          db: widget.db,
          initialGameId: _selectedGame,
          onGameSelected: (id) => _selectedGame = id,
        );
      case 2:
        return ReportPage(key: const ValueKey('report'), db: widget.db);
      default:
        return SettingsPage(
          key: const ValueKey('settings'),
          db: widget.db,
          onClubChanged: _loadClub,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_club)),
      body: _page(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Khata'),
          NavigationDestination(icon: Icon(Icons.scoreboard), label: 'Century'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Report'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
