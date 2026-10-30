// Common dialogs aur chhote widgets.
import 'package:flutter/material.dart';

import 'db.dart';
import 'utils.dart';

const Color kRed = Color(0xFFB71C1C);
const Color kGreen = Color(0xFF2E7D32);

class BallSpec {
  const BallSpec(this.points, this.name, this.color, this.textColor);
  final int points;
  final String name;
  final Color color;
  final Color textColor;
}

const List<BallSpec> kBalls = [
  BallSpec(1, 'Red', Color(0xFFD32F2F), Colors.white),
  BallSpec(2, 'Yellow', Color(0xFFFDD835), Colors.black),
  BallSpec(3, 'Green', Color(0xFF2E7D32), Colors.white),
  BallSpec(4, 'Brown', Color(0xFF6D4C41), Colors.white),
  BallSpec(5, 'Blue', Color(0xFF1565C0), Colors.white),
  BallSpec(6, 'Pink', Color(0xFFF06292), Colors.black),
  BallSpec(7, 'Black', Color(0xFF212121), Colors.white),
];

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String okText = 'Haan'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(okText)),
      ],
    ),
  );
  return r ?? false;
}

// ------------------------------------------------------------ generic form dialog
class FieldSpec {
  const FieldSpec(this.label, {this.initial = '', this.keyboard = TextInputType.text});
  final String label;
  final String initial;
  final TextInputType keyboard;
}

const TextInputType kDecimalKeyboard = TextInputType.numberWithOptions(decimal: true);
const TextInputType kSignedIntKeyboard = TextInputType.numberWithOptions(signed: true);

/// Kai text fields wala dialog. Cancel par null; OK par fields ki values.
/// [validate] error ka message de to dialog band nahi hota.
Future<List<String>?> askFields(
  BuildContext context,
  String title,
  List<FieldSpec> fields, {
  String okText = 'OK',
  String? Function(List<String> values)? validate,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _FieldsDialog(title: title, fields: fields, okText: okText, validate: validate),
  );
}

class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog(
      {required this.title, required this.fields, required this.okText, this.validate});
  final String title;
  final List<FieldSpec> fields;
  final String okText;
  final String? Function(List<String> values)? validate;

  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  late final List<TextEditingController> _ctrls;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrls = [for (final f in widget.fields) TextEditingController(text: f.initial)];
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = [for (final c in _ctrls) c.text];
    final check = widget.validate;
    if (check != null) {
      final err = check(values);
      if (err != null) {
        setState(() => _error = err);
        return;
      }
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < widget.fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _ctrls[i],
                  autofocus: i == 0,
                  keyboardType: widget.fields[i].keyboard,
                  decoration: InputDecoration(labelText: widget.fields[i].label),
                  textInputAction:
                      i == widget.fields.length - 1 ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: (_) {
                    if (i == widget.fields.length - 1) _submit();
                  },
                ),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: kRed, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.okText)),
      ],
    );
  }
}

// ------------------------------------------------------------ game charge dialog
class GameChargeResult {
  GameChargeResult(this.description, this.total);
  final String description;
  final double total;
}

class GameChargeDialog extends StatefulWidget {
  const GameChargeDialog({super.key, required this.types});
  final List<GameType> types;

  @override
  State<GameChargeDialog> createState() => _GameChargeDialogState();
}

class _GameChargeDialogState extends State<GameChargeDialog> {
  GameType? _type;
  int _qty = 1;
  final _rate = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.types.isNotEmpty) {
      _type = widget.types.first;
      _rate.text = fmtNum(widget.types.first.rate);
    }
  }

  @override
  void dispose() {
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _total => (parseAmount(_rate.text, allowZero: true) ?? 0) * _qty;

  void _submit() {
    final rate = parseAmount(_rate.text);
    if (rate == null) {
      setState(() => _error = 'Rate sahi likho (zero se zyada).');
      return;
    }
    final name = _type?.name ?? 'Game';
    var desc = '$name x $_qty @ ${fmtNum(rate)}';
    final note = _note.text.trim();
    if (note.isNotEmpty) desc += ' ($note)';
    Navigator.pop(context, GameChargeResult(desc, rate * _qty));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Game Add Karo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.types.isNotEmpty)
              DropdownButton<GameType>(
                isExpanded: true,
                value: _type,
                items: [
                  for (final t in widget.types)
                    DropdownMenuItem<GameType>(
                        value: t, child: Text('${t.name}  (${fmtNum(t.rate)})')),
                ],
                onChanged: (t) {
                  if (t == null) return;
                  setState(() {
                    _type = t;
                    _rate.text = fmtNum(t.rate);
                  });
                },
              ),
            Row(
              children: [
                const Text('Kitni games:'),
                const Spacer(),
                IconButton(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _qty++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            TextField(
              controller: _rate,
              keyboardType: kDecimalKeyboard,
              decoration: const InputDecoration(labelText: 'Rate (Rs per game)'),
              onChanged: (_) => setState(() => _error = null),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 14),
            Text('Total: ${money(_total)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: const TextStyle(color: kRed)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Khata mein likho')),
      ],
    );
  }
}
