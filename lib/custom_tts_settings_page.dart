import 'package:flutter/material.dart';
import 'database.dart';
import 'app_strings.dart';

class CustomTtsSettingsPage extends StatefulWidget {
  final AppDatabase db;

  const CustomTtsSettingsPage({super.key, required this.db});

  @override
  State<CustomTtsSettingsPage> createState() => _CustomTtsSettingsPageState();
}

class _CustomTtsSettingsPageState extends State<CustomTtsSettingsPage> {
  Map<String, String> _customStrings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStrings();
  }

  Future<void> _loadStrings() async {
    final list = await widget.db.select(widget.db.customStrings).get();
    setState(() {
      _customStrings = {for (var e in list) e.key: e.value};
      _isLoading = false;
    });
  }

  Future<void> _updateString(String key, String value) async {
    await widget.db.into(widget.db.customStrings).insertOnConflictUpdate(
      CustomStringsCompanion(key: Value(key), value: Value(value)),
    );
    setState(() {
      _customStrings[key] = value;
    });
    AppStrings.setCustomStrings(_customStrings);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Seznam všech klíčů, které chceme umožnit editovat (z AppStrings)
    final keys = ["welcomeTitle", "welcomeContent", "playerContent", "resetPlayed"]; 

    return Scaffold(
      appBar: AppBar(title: const Text("Vlastní hlasové zprávy")),
      body: ListView.builder(
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final key = keys[index];
          return ListTile(
            title: Text("Klíč: $key"),
            subtitle: TextFormField(
              initialValue: _customStrings[key] ?? "",
              decoration: const InputDecoration(labelText: "Vlastní text"),
              onChanged: (val) => _updateString(key, val),
            ),
          );
        },
      ),
    );
  }
}
