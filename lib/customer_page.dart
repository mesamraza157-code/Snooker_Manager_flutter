// Ek customer ka khata: games, payments, baqaya.
import 'package:flutter/material.dart';

import 'db.dart';
import 'utils.dart';
import 'widgets.dart';

class _Row {
  _Row(this.entry, this.running);
  final LedgerEntry entry;
  final double running;
}

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key, required this.db, required this.customerId});
  final Db db;
  final int customerId;

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  Customer? _cust;
  List<_Row> _rows = [];
  double _charges = 0;
  double _payments = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await widget.db.getCustomer(widget.customerId);
    final entries = await widget.db.listLedger(widget.customerId);
    if (!mounted) return;
    var run = 0.0;
    var ch = 0.0;
    var pay = 0.0;
    final rows = <_Row>[];
    for (final e in entries) {
      run += e.amount;
      if (e.amount > 0) {
        ch += e.amount;
      } else {
        pay += -e.amount;
      }
      rows.add(_Row(e, run));
    }
    setState(() {
      _cust = c;
      _rows = rows.reversed.toList(); // nayi entry upar
      _charges = ch;
      _payments = pay;
      _loading = false;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on AppError catch (e) {
      if (!mounted) return;
      snack(context, e.message);
      return;
    }
    if (!mounted) return;
    await _load();
  }

  Future<void> _addGame() async {
    final types = await widget.db.listGameTypes();
    if (!mounted) return;
    final res = await showDialog<GameChargeResult>(
      context: context,
      builder: (_) => GameChargeDialog(types: types),
    );
    if (res == null) return;
    await _run(() => widget.db.addCharge(widget.customerId, 'game', res.description, res.total));
  }

  Future<void> _addPayment() async {
    final bal = _cust?.balance ?? 0;
    final v = await askFields(
      context,
      'Payment Wasool',
      [
        FieldSpec('Kitni payment mili? (Rs)',
            initial: bal > 0.005 ? fmtNum(bal) : '', keyboard: kDecimalKeyboard),
      ],
      okText: 'Jama karo',
      validate: (v) => parseAmount(v[0]) == null ? 'Sahi raqam likho (zero se zyada).' : null,
    );
    if (v == null) return;
    final amount = parseAmount(v[0]);
    if (amount == null) return;
    await _run(() => widget.db.addPayment(widget.customerId, amount));
  }

  Future<void> _addOther() async {
    final v = await askFields(
      context,
      'Aur Charge',
      const [
        FieldSpec('Kis cheez ka? (Chai, Cold drink...)'),
        FieldSpec('Paise (Rs)', keyboard: kDecimalKeyboard),
      ],
      okText: 'Khata mein likho',
      validate: (v) {
        if (v[0].trim().isEmpty) return 'Cheez ka naam likho.';
        if (parseAmount(v[1]) == null) return 'Sahi raqam likho (zero se zyada).';
        return null;
      },
    );
    if (v == null) return;
    final amount = parseAmount(v[1]);
    if (amount == null) return;
    await _run(() => widget.db.addCharge(widget.customerId, 'other', v[0].trim(), amount));
  }

  Future<void> _editEntry(LedgerEntry e) async {
    final v = await askFields(
      context,
      'Entry Edit',
      [
        FieldSpec('Detail', initial: e.description),
        FieldSpec('Raqam (Rs)', initial: fmtNum(e.amount.abs()), keyboard: kDecimalKeyboard),
      ],
      okText: 'Save',
      validate: (v) => parseAmount(v[1]) == null ? 'Sahi raqam likho (zero se zyada).' : null,
    );
    if (v == null) return;
    final amount = parseAmount(v[1]);
    if (amount == null) return;
    await _run(() => widget.db.updateEntry(e.id, v[0].trim(), amount));
  }

  Future<void> _deleteEntry(LedgerEntry e) async {
    if (!await confirm(context, 'Entry Delete', 'Ye entry delete kar den?\n\n${e.description}',
        okText: 'Delete')) {
      return;
    }
    await _run(() => widget.db.deleteEntry(e.id));
  }

  void _entryMenu(LedgerEntry e) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _editEntry(e);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: kRed),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteEntry(e);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCustomer() async {
    final c = _cust;
    if (c == null) return;
    final v = await askFields(
      context,
      'Customer Edit',
      [
        FieldSpec('Naam', initial: c.name),
        FieldSpec('Phone', initial: c.phone, keyboard: TextInputType.phone),
      ],
      okText: 'Save',
      validate: (v) => cleanName(v[0]).isEmpty ? 'Naam likho.' : null,
    );
    if (v == null) return;
    await _run(() => widget.db.updateCustomer(c.id, v[0], v[1]));
  }

  Future<void> _deleteCustomer() async {
    final c = _cust;
    if (c == null) return;
    final extra = c.balance.abs() > 0.005 ? '\n\nIs ka baqaya ${money(c.balance)} hai.' : '';
    final ok = await confirm(
      context,
      'Customer Delete',
      "'${c.name}' aur is ka poora khata hamesha ke liye delete ho jayega.$extra\n\nPakka?",
      okText: 'Delete',
    );
    if (!ok) return;
    await widget.db.deleteCustomer(c.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = _cust;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.name ?? 'Khata'),
        actions: [
          IconButton(onPressed: c == null ? null : _editCustomer, icon: const Icon(Icons.edit)),
          IconButton(
              onPressed: c == null ? null : _deleteCustomer,
              icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : c == null
              ? const Center(child: Text('Customer nahi mila.'))
              : Column(
                  children: [
                    _header(c),
                    const Divider(height: 1),
                    Expanded(
                      child: _rows.isEmpty
                          ? const Center(child: Text('Abhi koi entry nahi.'))
                          : ListView.separated(
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) => _entryTile(_rows[i]),
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: c == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _addGame,
                        icon: const Icon(Icons.sports_bar),
                        label: const Text('Game'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _addPayment,
                        icon: const Icon(Icons.payments),
                        label: const Text('Payment'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addOther,
                        icon: const Icon(Icons.local_cafe),
                        label: const Text('Aur'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _header(Customer c) {
    final owes = c.balance > 0.005;
    final adv = c.balance < -0.005;
    final String label = owes ? 'Baqaya (udhaar)' : (adv ? 'Advance jama' : 'Hisaab saaf');
    final Color? color = owes ? kRed : (adv ? kGreen : null);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.phone.isNotEmpty) Text(c.phone),
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            money(c.balance.abs()),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text('Kul udhaar likha: ${money(_charges)}   |   Kul payment mili: ${money(_payments)}',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _entryTile(_Row r) {
    final e = r.entry;
    final isCharge = e.amount > 0;
    return ListTile(
      title: Text(e.description),
      subtitle: Text('${fmtDt(e.createdAt)}   |   baqaya: ${fmtNum(r.running, grouping: true)}'),
      trailing: Text(
        '${isCharge ? '+' : '-'}${fmtNum(e.amount.abs(), grouping: true)}',
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: isCharge ? kRed : kGreen),
      ),
      onTap: () => _entryMenu(e),
    );
  }
}
