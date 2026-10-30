// Khatam ho chuki century games ki history.
import 'package:flutter/material.dart';

import 'db.dart';
import 'utils.dart';

String _duration(HistoryGame g) {
  final a = DateTime.tryParse(g.startedAt);
  final b = DateTime.tryParse(g.finishedAt);
  if (a == null || b == null) return '';
  return fmtDuration(b.difference(a));
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.db});
  final Db db;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryGame> _games = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await widget.db.historyGames(100);
    if (!mounted) return;
    setState(() {
      _games = g;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Century History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _games.isEmpty
              ? const Center(child: Text('Abhi koi khatam hui game nahi.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: _games.length,
                  itemBuilder: (context, i) {
                    final g = _games[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Table ${g.tableNo}   |   ${fmtDt(g.finishedAt)}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Winner: ${g.winners.join(', ')}',
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(g.players.map((p) => '${p.name} ${p.score}').join('   |   ')),
                            const SizedBox(height: 4),
                            Text(
                                'Shuru ${fmtTime(g.startedAt)}  -  Khatam ${fmtTime(g.finishedAt)}  '
                                '(${_duration(g)})   |   Charge: ${money(g.tableCharge)}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
