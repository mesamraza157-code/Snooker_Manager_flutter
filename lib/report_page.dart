// Tab 3: Report - aaj / kal / hafta / mahina ka hisaab.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'db.dart';
import 'utils.dart';
import 'widgets.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.db});
  final Db db;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String _period = 'Aaj';
  bool _loading = true;
  Summary? _summary;
  List<ReportRow> _rows = [];
  List<Customer> _debtors = [];
  double _outstanding = 0;

  static const Map<String, String> _kindNames = {
    'game': 'Games',
    'century': 'Century',
    'other': 'Aur',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = periodRange(_period);
    final s = await widget.db.summary(r.start, r.end);
    final rows = await widget.db.ledgerBetween(r.start, r.end);
    final debtors = await widget.db.topDebtors(10);
    final out = await widget.db.outstandingTotal();
    if (!mounted) return;
    setState(() {
      _summary = s;
      _rows = rows;
      _debtors = debtors;
      _outstanding = out;
      _loading = false;
    });
  }

  Future<void> _copyBalances() async {
    final club = await widget.db.getSetting('club_name', 'Snooker Club');
    final list = await widget.db.listCustomers(byBalance: true);
    final sb = StringBuffer('$club - Baqaya hisaab (${dateStr(DateTime.now())})\n');
    var n = 0;
    for (final c in list) {
      if (c.balance.abs() > 0.005) {
        sb.writeln('${c.name}: ${fmtNum(c.balance, grouping: true)}');
        n++;
      }
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    snack(context, 'Copy ho gaya ($n customers). Ab WhatsApp / Notes mein paste kar sakte ho.');
  }

  Widget _card(String title, String value, {Color? color}) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final s = _summary;
    final kinds = s == null
        ? ''
        : s.byKind.entries
            .map((e) => '${_kindNames[e.key] ?? e.key}: ${money(e.value)}')
            .join('   |   ');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final p in kPeriods)
                ChoiceChip(
                  label: Text(p),
                  selected: _period == p,
                  onSelected: (_) {
                    _period = p;
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          _card('Is muddat ka udhaar / charges', money(s?.charges ?? 0)),
          _card('Is muddat ki payment wasool', money(s?.payments ?? 0), color: kGreen),
          _card('Abhi kul baqaya (sab customers)', money(_outstanding), color: kRed),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              'Charges ki tafseel -  ${kinds.isEmpty ? 'koi entry nahi' : kinds}   (${s?.entries ?? 0} entries)',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _copyBalances,
              icon: const Icon(Icons.copy),
              label: const Text('Sab ka baqaya copy karo'),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Sab se zyada udhaar (top 10)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (_debtors.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('Kisi ka udhaar baaqi nahi.')),
          for (final c in _debtors)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(c.name),
              trailing: Text(money(c.balance),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: kRed)),
            ),
          const SizedBox(height: 14),
          const Text('Entries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (_rows.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('Is muddat mein koi entry nahi.')),
          for (final r in _rows)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${r.name}  -  ${r.description}'),
              subtitle: Text(fmtDt(r.createdAt)),
              trailing: Text(
                '${r.amount > 0 ? '+' : '-'}${fmtNum(r.amount.abs(), grouping: true)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: r.amount > 0 ? kRed : kGreen),
              ),
            ),
        ],
      ),
    );
  }
}
