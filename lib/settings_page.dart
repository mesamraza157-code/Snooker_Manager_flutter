// Tab 4: Settings - game ke rates, century defaults, club ka naam.
import 'package:flutter/material.dart';

import 'db.dart';
import 'utils.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.db, required this.onClubChanged});
  final Db db;
  final VoidCallback onClubChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _club = TextEditingController();
  final _target = TextEditingController();
  final _charge = TextEditingController();
  List<GameType> _types = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _club.dispose();
    _target.dispose();
    _charge.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final club = await widget.db.getSetting('club_name', 'Snooker Club');
    final target = await widget.db.getSetting('century_target', '100');
    final charge = await widget.db.getSetting('century_hourly_rate', '300');
    final types = await widget.db.listGameTypes();
    if (!mounted) return;
    setState(() {
      _club.text = club;
      _target.text = target;
      _charge.text = fmtNum(double.tryParse(charge) ?? 300);
      _types = types;
      _loading = false;
    });
  }

  Future<void> _save() async {
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
    final club = cleanName(_club.text).isEmpty ? 'Snooker Club' : cleanName(_club.text);
    await widget.db.setSetting('century_target', target.toString());
    await widget.db.setSetting('century_hourly_rate', fmtNum(charge));
    await widget.db.setSetting('club_name', club);
    widget.onClubChanged();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    snack(context, 'Settings save ho gayin.');
  }

  Future<void> _editType({GameType? type}) async {
    final v = await askFields(
      context,
      type == null ? 'Nayi Game' : 'Game Edit',
      [
        FieldSpec('Game ka naam (jaise Snooker Frame)', initial: type?.name ?? ''),
        FieldSpec('Rate (Rs per game)',
            initial: type == null ? '' : fmtNum(type.rate), keyboard: kDecimalKeyboard),
      ],
      okText: 'Save',
      validate: (v) {
        if (cleanName(v[0]).isEmpty) return 'Naam likho.';
        if (parseAmount(v[1], allowZero: true) == null) return 'Rate sahi likho.';
        return null;
      },
    );
    if (v == null) return;
    final rate = parseAmount(v[1], allowZero: true);
    if (rate == null) return;
    try {
      await widget.db.saveGameType(v[0], rate, id: type?.id);
    } on AppError catch (e) {
      if (!mounted) return;
      snack(context, e.message);
      return;
    }
    await _load();
  }

  Future<void> _deleteType(GameType t) async {
    final ok = await confirm(
      context,
      'Game Delete',
      "'${t.name}' list se hata den?\n(Purani entries par asar nahi parega.)",
      okText: 'Delete',
    );
    if (!ok) return;
    await widget.db.deleteGameType(t.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text('Club aur Century',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        TextField(controller: _club, decoration: const InputDecoration(labelText: 'Club ka naam')),
        TextField(
          controller: _target,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Century default target'),
        ),
        TextField(
          controller: _charge,
          keyboardType: kDecimalKeyboard,
          decoration: const InputDecoration(labelText: 'Century rate per ghanta (Rs)'),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _save, child: const Text('Save Karo')),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text('Game ke rates',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            OutlinedButton.icon(
              onPressed: () => _editType(),
              icon: const Icon(Icons.add),
              label: const Text('Nayi Game'),
            ),
          ],
        ),
        if (_types.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('Koi game nahi. "Nayi Game" dabao.')),
        for (final t in _types)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.name),
            subtitle: Text('Rs ${fmtNum(t.rate, grouping: true)} per game'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: () => _editType(type: t), icon: const Icon(Icons.edit)),
                IconButton(
                    onPressed: () => _deleteType(t),
                    icon: const Icon(Icons.delete_outline, color: kRed)),
              ],
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'Data is phone ke andar hi save hota hai. App uninstall karne se sara data ud jata hai, '
          'is liye Report tab se baqaya copy karke kahin bhej dete raho.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
