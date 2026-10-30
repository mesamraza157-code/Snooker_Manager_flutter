// Database layer (SQLite via sqflite). Sara hisaab-kitaab yahan hota hai.
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'utils.dart';

class AppError implements Exception {
  AppError(this.message);
  final String message;
  @override
  String toString() => message;
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0.0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

// ---------------------------------------------------------------- models
class Customer {
  Customer(this.id, this.name, this.phone, this.balance);
  final int id;
  final String name;
  final String phone;
  final double balance;
}

class LedgerEntry {
  LedgerEntry(this.id, this.customerId, this.kind, this.description, this.amount, this.createdAt);
  final int id;
  final int customerId;
  final String kind;
  final String description;
  final double amount; // + udhaar/charge, - payment
  final String createdAt;
}

class GameType {
  GameType(this.id, this.name, this.rate);
  final int id;
  final String name;
  final double rate;
}

class CenturyGame {
  CenturyGame(this.id, this.tableNo, this.target, this.tableCharge, this.status,
      this.startedAt, this.finishedAt, this.nPlayers, this.hourlyRate);
  final int id;
  final String tableNo;
  final int target;
  final double tableCharge;
  final String status;
  final String startedAt;
  final String? finishedAt;
  final int nPlayers;
  final double hourlyRate; // century ka rate per ghanta
}

class Player {
  Player(this.id, this.name, this.customerId, this.score);
  final int id;
  final String name;
  final int? customerId;
  final int score;
}

class ScoreEvent {
  ScoreEvent(this.id, this.name, this.points, this.createdAt);
  final int id;
  final String name;
  final int points;
  final String createdAt;
}

class FinishResult {
  FinishResult(this.winners, this.top, this.payers, this.share);
  final List<String> winners;
  final int top;
  final List<String> payers;
  final double share;
}

class HistoryGame {
  HistoryGame(this.id, this.tableNo, this.finishedAt, this.target, this.tableCharge,
      this.players, this.winners, this.startedAt);
  final int id;
  final String tableNo;
  final String finishedAt;
  final int target;
  final double tableCharge;
  final List<Player> players; // score ke hisaab se
  final List<String> winners;
  final String startedAt;
}

class Summary {
  Summary(this.charges, this.payments, this.entries, this.byKind);
  final double charges;
  final double payments;
  final int entries;
  final Map<String, double> byKind;
}

class ReportRow {
  ReportRow(this.createdAt, this.name, this.kind, this.description, this.amount);
  final String createdAt;
  final String name;
  final String kind;
  final String description;
  final double amount;
}

// ---------------------------------------------------------------- database
class Db {
  Db._(this.db);
  final Database db;

  static const List<String> _schema = [
    '''CREATE TABLE customers (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         name TEXT NOT NULL UNIQUE COLLATE NOCASE,
         phone TEXT NOT NULL DEFAULT '',
         created_at TEXT NOT NULL)''',
    '''CREATE TABLE ledger (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
         kind TEXT NOT NULL DEFAULT 'game',
         description TEXT NOT NULL DEFAULT '',
         amount REAL NOT NULL,
         created_at TEXT NOT NULL)''',
    'CREATE INDEX idx_ledger_customer ON ledger(customer_id)',
    '''CREATE TABLE game_types (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         name TEXT NOT NULL UNIQUE COLLATE NOCASE,
         rate REAL NOT NULL)''',
    '''CREATE TABLE settings (
         key TEXT PRIMARY KEY,
         value TEXT NOT NULL)''',
    '''CREATE TABLE century_games (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         table_no TEXT NOT NULL DEFAULT '',
         target INTEGER NOT NULL DEFAULT 100,
         table_charge REAL NOT NULL DEFAULT 0,
         hourly_rate REAL NOT NULL DEFAULT 0,
         status TEXT NOT NULL DEFAULT 'active',
         started_at TEXT NOT NULL,
         finished_at TEXT)''',
    '''CREATE TABLE century_players (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         game_id INTEGER NOT NULL REFERENCES century_games(id) ON DELETE CASCADE,
         customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
         name TEXT NOT NULL)''',
    '''CREATE TABLE century_events (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         game_id INTEGER NOT NULL REFERENCES century_games(id) ON DELETE CASCADE,
         player_id INTEGER NOT NULL REFERENCES century_players(id) ON DELETE CASCADE,
         points INTEGER NOT NULL,
         created_at TEXT NOT NULL)''',
  ];

  static Future<Db> open([String name = 'snooker_manager.db']) async {
    final path = p.join(await getDatabasesPath(), name);
    final database = await openDatabase(
      path,
      version: 2,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (d, version) async {
        for (final stmt in _schema) {
          await d.execute(stmt);
        }
        await d.insert('settings', {'key': 'club_name', 'value': 'Snooker Club'});
        await d.insert('settings', {'key': 'century_target', 'value': '100'});
        await d.insert('settings', {'key': 'century_hourly_rate', 'value': '300'});
        await d.insert('game_types', {'name': 'Snooker Frame', 'rate': 200});
        await d.insert('game_types', {'name': 'Pool Frame', 'rate': 150});
      },
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await d.execute(
              'ALTER TABLE century_games ADD COLUMN hourly_rate REAL NOT NULL DEFAULT 0');
          await d.insert('settings', {'key': 'century_hourly_rate', 'value': '300'},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      },
    );
    return Db._(database);
  }

  // ------------------------------------------------------------ settings
  Future<String> getSetting(String key, String fallback) async {
    final r = await db.rawQuery('SELECT value FROM settings WHERE key = ?', [key]);
    return r.isEmpty ? fallback : (r.first['value'] as String? ?? fallback);
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ------------------------------------------------------------ customers
  Customer _cust(Map<String, Object?> r) => Customer(
      _i(r['id']), r['name'] as String, (r['phone'] as String?) ?? '', _d(r['balance']));

  Future<int> addCustomer(String name, [String phone = '']) async {
    final n = cleanName(name);
    if (n.isEmpty) throw AppError('Naam khali nahi ho sakta.');
    final exists = await db.rawQuery('SELECT id FROM customers WHERE name = ?', [n]);
    if (exists.isNotEmpty) throw AppError("'$n' pehle se khata mein maujood hai.");
    return db.insert('customers', {'name': n, 'phone': phone.trim(), 'created_at': nowStr()});
  }

  Future<int> getOrCreateCustomer(String name) async {
    final n = cleanName(name);
    if (n.isEmpty) throw AppError('Naam khali nahi ho sakta.');
    final r = await db.rawQuery('SELECT id FROM customers WHERE name = ?', [n]);
    if (r.isNotEmpty) return _i(r.first['id']);
    return addCustomer(n);
  }

  Future<String?> customerName(int id) async {
    final r = await db.rawQuery('SELECT name FROM customers WHERE id = ?', [id]);
    return r.isEmpty ? null : r.first['name'] as String?;
  }

  Future<Customer?> getCustomer(int id) async {
    final r = await db.rawQuery(
        'SELECT c.id, c.name, c.phone, COALESCE(SUM(l.amount), 0) AS balance '
        'FROM customers c LEFT JOIN ledger l ON l.customer_id = c.id '
        'WHERE c.id = ? GROUP BY c.id',
        [id]);
    return r.isEmpty ? null : _cust(r.first);
  }

  Future<void> updateCustomer(int id, String name, String phone) async {
    final n = cleanName(name);
    if (n.isEmpty) throw AppError('Naam khali nahi ho sakta.');
    final dup = await db.rawQuery('SELECT id FROM customers WHERE name = ? AND id <> ?', [n, id]);
    if (dup.isNotEmpty) throw AppError("'$n' naam ka doosra customer pehle se maujood hai.");
    await db.update('customers', {'name': n, 'phone': phone.trim()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCustomer(int id) async {
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Customer>> listCustomers({String search = '', bool byBalance = false}) async {
    final esc = search
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final like = '%$esc%';
    final order = byBalance ? 'balance DESC, c.name' : 'c.name';
    final r = await db.rawQuery(
        'SELECT c.id, c.name, c.phone, COALESCE(SUM(l.amount), 0) AS balance '
        'FROM customers c LEFT JOIN ledger l ON l.customer_id = c.id '
        "WHERE c.name LIKE ? ESCAPE '\\' OR c.phone LIKE ? ESCAPE '\\' "
        'GROUP BY c.id ORDER BY $order',
        [like, like]);
    return r.map(_cust).toList();
  }

  // ------------------------------------------------------------ ledger (khata)
  LedgerEntry _entry(Map<String, Object?> r) => LedgerEntry(
      _i(r['id']),
      _i(r['customer_id']),
      (r['kind'] as String?) ?? 'game',
      (r['description'] as String?) ?? '',
      _d(r['amount']),
      (r['created_at'] as String?) ?? '');

  Future<void> addCharge(int cid, String kind, String description, double amount) async {
    if (amount <= 0) throw AppError('Charge zero se zyada hona chahiye.');
    await db.insert('ledger', {
      'customer_id': cid,
      'kind': kind,
      'description': description,
      'amount': amount,
      'created_at': nowStr(),
    });
  }

  Future<void> addPayment(int cid, double amount, [String description = 'Payment wasool']) async {
    if (amount <= 0) throw AppError('Payment zero se zyada honi chahiye.');
    await db.insert('ledger', {
      'customer_id': cid,
      'kind': 'payment',
      'description': description,
      'amount': -amount,
      'created_at': nowStr(),
    });
  }

  Future<List<LedgerEntry>> listLedger(int cid) async {
    final r = await db.rawQuery(
        'SELECT * FROM ledger WHERE customer_id = ? ORDER BY created_at, id', [cid]);
    return r.map(_entry).toList();
  }

  Future<void> updateEntry(int entryId, String description, double amount) async {
    if (amount <= 0) throw AppError('Raqam zero se zyada honi chahiye.');
    final r = await db.rawQuery('SELECT amount FROM ledger WHERE id = ?', [entryId]);
    if (r.isEmpty) throw AppError('Ye entry maujood nahi.');
    final signed = _d(r.first['amount']) > 0 ? amount : -amount;
    await db.update('ledger', {'description': description, 'amount': signed},
        where: 'id = ?', whereArgs: [entryId]);
  }

  Future<void> deleteEntry(int entryId) async {
    await db.delete('ledger', where: 'id = ?', whereArgs: [entryId]);
  }

  // ------------------------------------------------------------ game types
  Future<List<GameType>> listGameTypes() async {
    final r = await db.rawQuery('SELECT id, name, rate FROM game_types ORDER BY name');
    return r.map((e) => GameType(_i(e['id']), e['name'] as String, _d(e['rate']))).toList();
  }

  Future<void> saveGameType(String name, double rate, {int? id}) async {
    final n = cleanName(name);
    if (n.isEmpty) throw AppError('Game ka naam likho.');
    if (rate < 0) throw AppError('Rate minus nahi ho sakta.');
    final dup = await db.rawQuery(
        'SELECT id FROM game_types WHERE name = ? AND id <> ?', [n, id ?? -1]);
    if (dup.isNotEmpty) throw AppError("'$n' naam ki game pehle se maujood hai.");
    if (id == null) {
      await db.insert('game_types', {'name': n, 'rate': rate});
    } else {
      await db.update('game_types', {'name': n, 'rate': rate}, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteGameType(int id) async {
    await db.delete('game_types', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------ century
  CenturyGame _game(Map<String, Object?> r) => CenturyGame(
      _i(r['id']),
      (r['table_no'] as String?) ?? '-',
      _i(r['target']),
      _d(r['table_charge']),
      (r['status'] as String?) ?? 'active',
      (r['started_at'] as String?) ?? '',
      r['finished_at'] as String?,
      _i(r['n_players']),
      _d(r['hourly_rate']));

  Future<int> createCentury(
      String tableNo, int target, double hourlyRate, List<String> names) async {
    final clean = <String>[];
    final seen = <String>{};
    for (final n in names) {
      final c = cleanName(n);
      if (c.isNotEmpty && seen.add(c.toLowerCase())) clean.add(c);
    }
    if (clean.length < 2) throw AppError('Century ke liye kam az kam 2 players chahiye.');
    if (target <= 0) throw AppError('Target score zero se zyada hona chahiye.');
    if (hourlyRate < 0) throw AppError('Rate minus nahi ho sakta.');

    final ids = <int>[];
    final real = <String>[];
    for (final n in clean) {
      final id = await getOrCreateCustomer(n);
      ids.add(id);
      real.add(await customerName(id) ?? n);
    }
    return db.transaction((txn) async {
      final gid = await txn.insert('century_games', {
        'table_no': cleanName(tableNo).isEmpty ? '-' : cleanName(tableNo),
        'target': target,
        'table_charge': 0,
        'hourly_rate': hourlyRate,
        'status': 'active',
        'started_at': nowStr(),
      });
      for (var i = 0; i < ids.length; i++) {
        await txn.insert('century_players',
            {'game_id': gid, 'customer_id': ids[i], 'name': real[i]});
      }
      return gid;
    });
  }

  Future<CenturyGame?> getGame(int gid) async {
    final r = await db.rawQuery(
        'SELECT g.*, (SELECT COUNT(*) FROM century_players p WHERE p.game_id = g.id) AS n_players '
        'FROM century_games g WHERE g.id = ?',
        [gid]);
    return r.isEmpty ? null : _game(r.first);
  }

  Future<List<CenturyGame>> activeGames() async {
    final r = await db.rawQuery(
        'SELECT g.*, (SELECT COUNT(*) FROM century_players p WHERE p.game_id = g.id) AS n_players '
        "FROM century_games g WHERE g.status = 'active' ORDER BY g.id");
    return r.map(_game).toList();
  }

  Future<List<Player>> playersWithScores(int gid) async {
    final r = await db.rawQuery(
        'SELECT p.id, p.name, p.customer_id, COALESCE(SUM(e.points), 0) AS score '
        'FROM century_players p LEFT JOIN century_events e ON e.player_id = p.id '
        'WHERE p.game_id = ? GROUP BY p.id ORDER BY p.id',
        [gid]);
    return r
        .map((e) => Player(_i(e['id']), e['name'] as String,
            e['customer_id'] == null ? null : _i(e['customer_id']), _i(e['score'])))
        .toList();
  }

  Future<void> addPlayer(int gid, String name) async {
    final game = await getGame(gid);
    if (game == null || game.status != 'active') throw AppError('Ye game chal nahi raha.');
    final n = cleanName(name);
    if (n.isEmpty) throw AppError('Naam khali nahi ho sakta.');
    final existing = await playersWithScores(gid);
    if (existing.any((p) => p.name.toLowerCase() == n.toLowerCase())) {
      throw AppError("'$n' pehle se is game mein hai.");
    }
    final cid = await getOrCreateCustomer(n);
    final real = await customerName(cid) ?? n;
    await db.insert('century_players', {'game_id': gid, 'customer_id': cid, 'name': real});
  }

  /// Naya total score wapas deta hai.
  Future<int> addScore(int playerId, int points) async {
    if (points == 0) throw AppError('Points zero nahi ho sakte.');
    final r = await db.rawQuery(
        'SELECT p.game_id AS game_id, g.status AS status FROM century_players p '
        'JOIN century_games g ON g.id = p.game_id WHERE p.id = ?',
        [playerId]);
    if (r.isEmpty) throw AppError('Player nahi mila.');
    if (r.first['status'] != 'active') throw AppError('Ye game khatam ho chuka hai.');
    await db.insert('century_events', {
      'game_id': _i(r.first['game_id']),
      'player_id': playerId,
      'points': points,
      'created_at': nowStr(),
    });
    final s = await db.rawQuery(
        'SELECT COALESCE(SUM(points), 0) AS s FROM century_events WHERE player_id = ?',
        [playerId]);
    return _i(s.first['s']);
  }

  Future<ScoreEvent?> undoLast(int gid) async {
    final r = await db.rawQuery(
        'SELECT e.id, e.points, e.created_at, p.name FROM century_events e '
        'JOIN century_players p ON p.id = e.player_id '
        'WHERE e.game_id = ? ORDER BY e.id DESC LIMIT 1',
        [gid]);
    if (r.isEmpty) return null;
    final ev = ScoreEvent(_i(r.first['id']), r.first['name'] as String,
        _i(r.first['points']), (r.first['created_at'] as String?) ?? '');
    await db.delete('century_events', where: 'id = ?', whereArgs: [ev.id]);
    return ev;
  }

  Future<List<ScoreEvent>> recentEvents(int gid, [int limit = 8]) async {
    final r = await db.rawQuery(
        'SELECT e.id, e.points, e.created_at, p.name FROM century_events e '
        'JOIN century_players p ON p.id = e.player_id '
        'WHERE e.game_id = ? ORDER BY e.id DESC LIMIT ?',
        [gid, limit]);
    return r
        .map((e) => ScoreEvent(_i(e['id']), e['name'] as String, _i(e['points']),
            (e['created_at'] as String?) ?? ''))
        .toList();
  }

  /// mode: 'loser' = sab se kam score wale (barabar hon to sab) bharen,
  ///       'all'   = sab barabar taqseem, 'none' = khata mein kuch na likho.
  Future<FinishResult> finishCentury(int gid, String mode, [double? amount]) async {
    if (mode != 'loser' && mode != 'all' && mode != 'none') throw AppError('Galat mode.');
    final game = await getGame(gid);
    if (game == null || game.status != 'active') throw AppError('Ye game chal nahi raha.');
    final players = await playersWithScores(gid);
    if (players.isEmpty) throw AppError('Game mein koi player nahi.');
    // amount na diya ho to guzre waqt ke hisaab se charge banta hai
    final amt = amount ??
        timeCharge(DateTime.tryParse(game.startedAt) ?? DateTime.now(), DateTime.now(),
            game.hourlyRate);
    if (amt < 0) throw AppError('Amount minus nahi ho sakta.');

    final scores = players.map((p) => p.score).toList();
    final top = scores.reduce((a, b) => math.max(a, b));
    final low = scores.reduce((a, b) => math.min(a, b));
    final winners = players.where((p) => p.score == top).map((p) => p.name).toList();

    List<Player> payers;
    if (mode == 'loser') {
      payers = players.where((p) => p.score == low).toList();
    } else if (mode == 'all') {
      payers = List<Player>.from(players);
    } else {
      payers = <Player>[];
    }
    final share =
        payers.isNotEmpty && amt > 0 ? (amt / payers.length * 100).round() / 100 : 0.0;

    final payerIds = <int>[];
    if (share > 0) {
      for (final p in payers) {
        var cid = p.customerId;
        if (cid == null || await getCustomer(cid) == null) {
          cid = await getOrCreateCustomer(p.name); // customer delete ho gaya ho to dobara bana lo
        }
        payerIds.add(cid);
      }
    }

    final when = nowStr();
    await db.transaction((txn) async {
      final desc = 'Century (Table ${game.tableNo}, Game #$gid)';
      for (final cid in payerIds) {
        await txn.insert('ledger', {
          'customer_id': cid,
          'kind': 'century',
          'description': desc,
          'amount': share,
          'created_at': when,
        });
      }
      await txn.update(
          'century_games', {'status': 'finished', 'finished_at': when, 'table_charge': amt},
          where: 'id = ?', whereArgs: [gid]);
    });
    return FinishResult(winners, top, payers.map((p) => p.name).toList(), share);
  }

  Future<void> cancelCentury(int gid) async {
    await db.delete('century_games',
        where: "id = ? AND status = 'active'", whereArgs: [gid]);
  }

  Future<List<HistoryGame>> historyGames([int limit = 100]) async {
    final games = await db.rawQuery(
        "SELECT * FROM century_games WHERE status = 'finished' "
        'ORDER BY finished_at DESC, id DESC LIMIT ?',
        [limit]);
    final out = <HistoryGame>[];
    for (final g in games) {
      final id = _i(g['id']);
      final players = await playersWithScores(id);
      players.sort((a, b) => b.score.compareTo(a.score));
      final top = players.isEmpty ? 0 : players.first.score;
      out.add(HistoryGame(
          id,
          (g['table_no'] as String?) ?? '-',
          (g['finished_at'] as String?) ?? '',
          _i(g['target']),
          _d(g['table_charge']),
          players,
          players.where((p) => p.score == top).map((p) => p.name).toList(),
          (g['started_at'] as String?) ?? ''));
    }
    return out;
  }

  // ------------------------------------------------------------ reports
  Future<Summary> summary(String start, String end) async {
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(CASE WHEN amount > 0 THEN amount END), 0) AS charges, '
        'COALESCE(SUM(CASE WHEN amount < 0 THEN -amount END), 0) AS payments, '
        'COUNT(*) AS entries FROM ledger WHERE date(created_at) BETWEEN ? AND ?',
        [start, end]);
    final k = await db.rawQuery(
        'SELECT kind, SUM(amount) AS total FROM ledger '
        'WHERE amount > 0 AND date(created_at) BETWEEN ? AND ? GROUP BY kind',
        [start, end]);
    final byKind = <String, double>{};
    for (final row in k) {
      byKind[(row['kind'] as String?) ?? ''] = _d(row['total']);
    }
    return Summary(_d(r.first['charges']), _d(r.first['payments']), _i(r.first['entries']), byKind);
  }

  Future<List<ReportRow>> ledgerBetween(String start, String end) async {
    final r = await db.rawQuery(
        'SELECT l.created_at, c.name, l.kind, l.description, l.amount '
        'FROM ledger l JOIN customers c ON c.id = l.customer_id '
        'WHERE date(l.created_at) BETWEEN ? AND ? ORDER BY l.created_at DESC, l.id DESC',
        [start, end]);
    return r
        .map((e) => ReportRow((e['created_at'] as String?) ?? '', e['name'] as String,
            (e['kind'] as String?) ?? '', (e['description'] as String?) ?? '', _d(e['amount'])))
        .toList();
  }

  Future<double> outstandingTotal() async {
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(b), 0) AS t FROM ('
        'SELECT SUM(amount) AS b FROM ledger GROUP BY customer_id HAVING SUM(amount) > 0.005)');
    return _d(r.first['t']);
  }

  Future<List<Customer>> topDebtors([int limit = 10]) async {
    final r = await db.rawQuery(
        'SELECT c.id, c.name, c.phone, SUM(l.amount) AS balance '
        'FROM customers c JOIN ledger l ON l.customer_id = c.id '
        'GROUP BY c.id HAVING SUM(l.amount) > 0.005 ORDER BY balance DESC LIMIT ?',
        [limit]);
    return r.map(_cust).toList();
  }
}
