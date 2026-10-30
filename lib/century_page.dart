// Tab 2: Century - kai players ka scoreboard (har naam ke saath uska score).
import 'dart:async';

import 'package:flutter/material.dart';

import 'century_start_page.dart';
import 'db.dart';
import 'history_page.dart';
import 'utils.dart';
import 'widgets.dart';

class CenturyPage extends StatefulWidget {
  const CenturyPage({
    super.key,
    required this.db,
    required this.initialGameId,
    required this.onGameSelected,
  });
  final Db db;
  final int? initialGameId;
  final ValueChanged<int?> onGameSelected;

  @override
  State<CenturyPage> createState() => _CenturyPageState();
}

class _CenturyPageState extends State<CenturyPage> {
  List<CenturyGame> _games = [];
  int? _gid;
  List<Player> _players = [];
  List<ScoreEvent> _events = [];
  final Set<String> _announced = {};
  String _note = '';
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _gid = widget.initialGameId;
    _loadGames();
    // Guzra waqt aur "ab tak ka charge" har 30 second baad taaza hota hai
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  CenturyGame? get _game {
    for (final g in _games) {
      if (g.id == _gid) return g;
    }
    return null;
  }

  Future<void> _loadGames({int? select}) async {
    final games = await widget.db.activeGames();
    if (!mounted) return;
    int? gid = select ?? _gid;
    final exists = gid != null && games.any((g) => g.id == gid);
    if (!exists) gid = games.isEmpty ? null : games.first.id;
    _games = games;
    _gid = gid;
    widget.onGameSelected(gid);
    await _loadBoard();
  }

  Future<void> _loadBoard() async {
    final gid = _gid;
    var players = <Player>[];
    var events = <ScoreEvent>[];
    if (gid != null) {
      players = await widget.db.playersWithScores(gid);
      events = await widget.db.recentEvents(gid, 8);
    }
    if (!mounted) return;
    setState(() {
      _players = players;
      _events = events;
      _loading = false;
    });
  }

  void _error(Object e) {
    if (!mounted) return;
    snack(context, e is AppError ? e.message : 'Kuch masla aa gaya: $e');
  }

  // ------------------------------------------------------------ scoring
  Future<void> _add(Player p, int pts) async {
    try {
      final total = await widget.db.addScore(p.id, pts);
      _note = '';
      await _loadBoard();
      final g = _game;
      if (g != null && pts > 0 && total >= g.target && _announced.add('${g.id}:${p.id}')) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Target poora!'),
            content: Text('${p.name} ne ${g.target} ka target poora kar liya ($total).\n\n'
                'Game khatam karna ho to "Finish" dabao.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Theek hai'))],
          ),
        );
      }
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _custom(Player p) async {
    final v = await askFields(
      context,
      '${p.name} ke points',
      const [FieldSpec('Points (minus bhi chalega, foul ke liye -4)', keyboard: kSignedIntKeyboard)],
      okText: 'Add',
      validate: (v) {
        final n = int.tryParse(v[0].trim());
        if (n == null || n == 0) return 'Zero se alag poora number likho.';
        return null;
      },
    );
    if (v == null) return;
    final n = int.tryParse(v[0].trim());
    if (n == null || n == 0) return;
    await _add(p, n);
  }

  Future<void> _undo() async {
    final gid = _gid;
    if (gid == null) return;
    try {
      final u = await widget.db.undoLast(gid);
      _note = u == null
          ? 'wapas karne ko kuch nahi'
          : 'wapas: ${u.name} ${u.points > 0 ? '+' : ''}${u.points}';
      await _loadBoard();
    } catch (e) {
      _error(e);
    }
  }

  // ------------------------------------------------------------ game actions
  Future<void> _startGame() async {
    final customers = await widget.db.listCustomers();
    final target = int.tryParse(await widget.db.getSetting('century_target', '100')) ?? 100;
    final charge = double.tryParse(await widget.db.getSetting('century_hourly_rate', '300')) ?? 300;
    if (!mounted) return;
    final res = await Navigator.of(context).push<StartResult>(
      MaterialPageRoute<StartResult>(
        builder: (_) => CenturyStartPage(
          names: customers.map((c) => c.name).toList(),
          defaultTarget: target,
          defaultCharge: charge,
        ),
      ),
    );
    if (res == null) return;
    try {
      final gid = await widget.db.createCentury(res.tableNo, res.target, res.charge, res.names);
      await _loadGames(select: gid);
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _addPlayer() async {
    final gid = _gid;
    if (gid == null) {
      snack(context, 'Pehle koi century game shuru karo.');
      return;
    }
    final v = await askFields(
      context,
      'Player Add',
      const [FieldSpec('Naya player ka naam')],
      okText: 'Add',
      validate: (v) => cleanName(v[0]).isEmpty ? 'Naam likho.' : null,
    );
    if (v == null) return;
    try {
      await widget.db.addPlayer(gid, v[0]);
      await _loadGames(select: gid);
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _finish() async {
    final g = _game;
    if (g == null) {
      snack(context, 'Pehle koi century game shuru karo.');
      return;
    }
    final choice = await showDialog<_FinishChoice>(
      context: context,
      builder: (_) => _FinishDialog(game: g, players: _players),
    );
    if (choice == null) return;
    try {
      final r = await widget.db.finishCentury(g.id, choice.mode, choice.amount);
      var msg = 'Winner: ${r.winners.join(', ')} (${r.top})';
      if (r.payers.isNotEmpty) {
        msg += '\n\nKhata mein likha gaya: ${r.payers.join(', ')}\nHar ek ke ${money(r.share)}';
      }
      await _loadGames();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Century khatam'),
          content: Text(msg),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Theek hai'))],
        ),
      );
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _cancel() async {
    final gid = _gid;
    if (gid == null) return;
    final ok = await confirm(
      context,
      'Game Cancel',
      'Ye game cancel ho jayega aur kisi ke khata mein kuch nahi likha jayega.\n\nPakka?',
      okText: 'Cancel Game',
    );
    if (!ok) return;
    await widget.db.cancelCentury(gid);
    await _loadGames();
  }

  void _history() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => HistoryPage(db: widget.db)),
    );
  }

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startGame,
        icon: const Icon(Icons.add),
        label: const Text('Naya Century'),
      ),
      body: _game == null ? _empty() : _board(_game!),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Abhi koi century game nahi chal raha.\n\n"Naya Century" dabao aur players chuno.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _history,
              icon: const Icon(Icons.history),
              label: const Text('Purani games (History)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board(CenturyGame g) {
    var top = 0;
    for (final p in _players) {
      if (p.score > top) top = p.score;
    }
    final leaders = _players.where((p) => top > 0 && p.score == top).map((p) => p.name).toList();
    final left = g.target - top;
    var status = leaders.isEmpty
        ? 'Abhi tak koi score nahi.'
        : 'Aage: ${leaders.join(', ')} ($top)  -  ${left > 0 ? 'target mein $left baaki' : 'TARGET POORA!'}';
    if (_note.isNotEmpty) status += '   [$_note]';

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                value: _gid,
                items: [
                  for (final x in _games)
                    DropdownMenuItem<int>(
                      value: x.id,
                      child: Text('Table ${x.tableNo}  -  Game #${x.id}  (${x.nPlayers} players)'),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  _gid = id;
                  widget.onGameSelected(id);
                  _loadBoard();
                },
              ),
            ),
            IconButton(tooltip: 'History', onPressed: _history, icon: const Icon(Icons.history)),
          ],
        ),
        Text(
          'Target: ${g.target}   |   Players: ${_players.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        _timeInfo(g),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
                onPressed: _addPlayer,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Player Add')),
            FilledButton.icon(
                onPressed: _finish, icon: const Icon(Icons.flag), label: const Text('Finish')),
            OutlinedButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.close, color: kRed),
                label: const Text('Cancel Game')),
          ],
        ),
        const SizedBox(height: 8),
        for (final p in _players) _playerCard(p, g, top),
        const SizedBox(height: 4),
        Row(
          children: [
            OutlinedButton.icon(
                onPressed: _undo, icon: const Icon(Icons.undo), label: const Text('Undo')),
            const SizedBox(width: 10),
            Expanded(child: Text(status, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        if (_events.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Aakhri scores', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final e in _events)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(e.name),
              subtitle: Text(fmtTime(e.createdAt)),
              trailing: Text('${e.points > 0 ? '+' : ''}${e.points}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: e.points > 0 ? kGreen : kRed)),
            ),
        ],
      ],
    );
  }

  Widget _timeInfo(CenturyGame g) {
    final start = DateTime.tryParse(g.startedAt);
    final now = DateTime.now();
    final elapsed = start == null ? Duration.zero : now.difference(start);
    final due = start == null ? 0.0 : timeCharge(start, now, g.hourlyRate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shuru: ${fmtTime(g.startedAt)}   |   Guzra waqt: ${fmtDuration(elapsed)}'),
            Text(
              'Rate: ${money(g.hourlyRate)} per ghanta   |   Ab tak: ${money(due)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerCard(Player p, CenturyGame g, int top) {
    final lead = top > 0 && p.score == top;
    return Card(
      shape: lead
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: kGreen, width: 2))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                if (p.score >= g.target)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Text('TARGET POORA',
                        style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
                  ),
                Text('${p.score}',
                    style: TextStyle(
                        fontSize: 34, fontWeight: FontWeight.bold, color: lead ? kGreen : null)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final b in kBalls)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: b.color,
                        foregroundColor: b.textColor,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => _add(p, b.points),
                      child: Text('${b.points}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                OutlinedButton(onPressed: () => _custom(p), child: const Text('Custom')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ finish dialog
class _FinishChoice {
  _FinishChoice(this.mode, this.amount);
  final String mode;
  final double amount;
}

class _FinishDialog extends StatefulWidget {
  const _FinishDialog({required this.game, required this.players});
  final CenturyGame game;
  final List<Player> players;

  @override
  State<_FinishDialog> createState() => _FinishDialogState();
}

class _FinishDialogState extends State<_FinishDialog> {
  late final TextEditingController _amount;
  late final DateTime _start;
  late final Duration _elapsed;
  late final double _calc;
  String _mode = 'loser';
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime.tryParse(widget.game.startedAt) ?? now;
    _elapsed = now.difference(_start);
    _calc = timeCharge(_start, now, widget.game.hourlyRate);
    _amount = TextEditingController(text: fmtNum(_calc));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Widget _option(String value, String label) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_mode == value ? Icons.radio_button_checked : Icons.radio_button_unchecked),
      title: Text(label),
      onTap: () => setState(() => _mode = value),
    );
  }

  void _submit() {
    final amount = parseAmount(_amount.text, allowZero: true);
    if (amount == null) {
      setState(() => _error = 'Charge sahi likho.');
      return;
    }
    Navigator.pop(context, _FinishChoice(_mode, amount));
  }

  @override
  Widget build(BuildContext context) {
    final ranked = List<Player>.from(widget.players)..sort((a, b) => b.score.compareTo(a.score));
    return AlertDialog(
      title: Text('Table ${widget.game.tableNo} - Final scores'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < ranked.length; i++)
              Text('${i + 1}.  ${ranked[i].name}  -  ${ranked[i].score}',
                  style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text('Shuru: ${fmtTime(widget.game.startedAt)}   |   Guzra waqt: ${fmtDuration(_elapsed)}'),
            Text('Rate: ${money(widget.game.hourlyRate)} per ghanta  =  ${money(_calc)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _amount,
              keyboardType: kDecimalKeyboard,
              decoration: const InputDecoration(labelText: 'Century ka charge (Rs) - badal bhi sakte ho'),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 8),
            _option('loser', 'Haarne wala (sab se kam score) bhare'),
            _option('all', 'Sab players barabar taqseem karein'),
            _option('none', 'Khata mein kuch na likho (sirf record)'),
            if (_error != null) Text(_error!, style: const TextStyle(color: kRed)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Khatam Karo')),
      ],
    );
  }
}
