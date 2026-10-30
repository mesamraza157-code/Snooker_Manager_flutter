// Tab 1: Khata - customers ki list.
import 'package:flutter/material.dart';

import 'customer_page.dart';
import 'db.dart';
import 'utils.dart';
import 'widgets.dart';

class KhataPage extends StatefulWidget {
  const KhataPage({super.key, required this.db});
  final Db db;

  @override
  State<KhataPage> createState() => _KhataPageState();
}

class _KhataPageState extends State<KhataPage> {
  final _search = TextEditingController();
  bool _byDebt = false;
  bool _loading = true;
  List<Customer> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await widget.db.listCustomers(search: _search.text, byBalance: _byDebt);
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<void> _open(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CustomerPage(db: widget.db, customerId: id)),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _newCustomer() async {
    final v = await askFields(
      context,
      'Naya Customer',
      const [
        FieldSpec('Naam'),
        FieldSpec('Phone (optional)', keyboard: TextInputType.phone),
      ],
      okText: 'Save',
      validate: (v) => cleanName(v[0]).isEmpty ? 'Naam likho.' : null,
    );
    if (v == null) return;
    try {
      final id = await widget.db.addCustomer(v[0], v[1]);
      if (!mounted) return;
      _search.clear();
      await _load();
      if (!mounted) return;
      await _open(id);
    } on AppError catch (e) {
      if (!mounted) return;
      snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newCustomer,
        icon: const Icon(Icons.person_add),
        label: const Text('Naya Customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Naam ya phone se dhoondo',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                      ),
              ),
              onChanged: (_) => _load(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Naam ke hisaab se'),
                  selected: !_byDebt,
                  onSelected: (_) {
                    _byDebt = false;
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Zyada udhaar pehle'),
                  selected: _byDebt,
                  onSelected: (_) {
                    _byDebt = true;
                    _load();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Koi customer nahi.\nNeeche "Naya Customer" dabao.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = _items[i];
                          final owes = c.balance > 0.005;
                          final adv = c.balance < -0.005;
                          return ListTile(
                            title: Text(c.name,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                            subtitle: c.phone.isEmpty ? null : Text(c.phone),
                            trailing: Text(
                              money(c.balance),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: owes ? kRed : (adv ? kGreen : null),
                              ),
                            ),
                            onTap: () => _open(c.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
