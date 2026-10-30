// Naya century game shuru karne ki screen: table, target, charge aur players chunna.
import 'package:flutter/material.dart';

import 'utils.dart';
import 'widgets.dart';

class StartResult {
  StartResult(this.tableNo, this.target, this.charge, this.names);
  final String tableNo;
  final int target;
  final double charge;
  final List<String> names;
}

class CenturyStartPage extends StatefulWidget {
  const CenturyStartPage({
    super.key,
    required this.names,
    required this.defaultTarget,
    required this.defaultCharge,
  });
  final List<String> names;
  final int defaultTarget;
  final double defaultCharge;

  @override
  State<CenturyStartPage> createState() => _CenturyStartPageState();
}

class _CenturyStartPageState extends State<CenturyStartPage> {
  late final TextEditingController _table;
  late final TextEditingController _target;
  late final TextEditingController _charge;
  final _newName = TextEditingController();
  late final List<String> _names;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _table = TextEditingController(text: '1');
    _target = TextEditingController(text: widget.defaultTarget.toString());
    _charge = TextEditingController(text: fmtNum(widget.defaultCharge));
    _names = List<String>.from(widget.names);
  }

  @override
  void dispose() {
    _table.dispose();
    _target.dispose();
    _charge.dispose();
    _newName.dispose();
    super.dispose();
  }

  void _addName() {
    final n = cleanName(_newName.text);
    if (n.isEmpty) return;
    String? found;
    for (final e in _names) {
      if (e.toLowerCase() == n.toLowerCase()) found = e;
    }
    setState(() {
      if (found == null) {
        _names.add(n);
        _selected.add(n);
      } else {
        _selected.add(found);
      }
      _newName.clear();
    });
  }

  void _start() {
    if (_selected.length < 2) {
      snack(context, 'Kam az kam 2 players chuno.');
      return;
    }
    final target = int.tryParse(_target.text.trim());
    if (target == null || target <= 0) {
      snack(context, 'Target score sahi number hona chahiye (jaise 100).');
      return;
    }
    final charge = parseAmount(_charge.text, allowZero: true);
    if (charge == null) {
      snack(context, 'Rate sahi likho.');
      return;
    }
    // Chune hue players ko list ki tarteeb mein rakho
    final chosen = [for (final n in _names) if (_selected.contains(n)) n];
    Navigator.pop(context, StartResult(_table.text.trim(), target, charge, chosen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Naya Century Game')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _table,
                  decoration: const InputDecoration(labelText: 'Table number'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target score'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _charge,
                  keyboardType: kDecimalKeyboard,
                  decoration: const InputDecoration(labelText: 'Rate per ghanta (Rs)'),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Game shuru karte hi waqt note ho jata hai. Finish par guzre waqt ke hisaab se charge banega.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Naya player (khata mein na ho to)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addName(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _addName, child: const Text('+ Add')),
            ],
          ),
          const SizedBox(height: 12),
          Text('Players chuno  (${_selected.length} chune gaye)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (_names.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Abhi khata mein koi customer nahi. Upar se naam likh kar "+ Add" dabao.'),
            ),
          for (final n in _names)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(n, style: const TextStyle(fontSize: 17)),
              value: _selected.contains(n),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(n);
                } else {
                  _selected.remove(n);
                }
              }),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Game Shuru Karo'),
          ),
        ),
      ),
    );
  }
}
