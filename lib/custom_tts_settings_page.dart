import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_tts/flutter_tts.dart';
import 'database.dart';
import 'app_strings.dart';

class CustomTtsSettingsPage extends StatefulWidget {
  final AppDatabase db;

  const CustomTtsSettingsPage({super.key, required this.db});

  @override
  State<CustomTtsSettingsPage> createState() => _CustomTtsSettingsPageState();
}

class _CustomTtsSettingsPageState extends State<CustomTtsSettingsPage> {
  final FlutterTts _tts = FlutterTts();
  Map<String, String> _customStrings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
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

  Future<void> _finishEditing(String key) async {
    final value = _customStrings[key] ?? "";
    await _updateString(key, value);
    _tts.speak("Hlasová zpráva uložena");
  }

  Future<void> _playAll() async {
    await _tts.awaitSpeakCompletion(true);
    for (final key in AppStrings.customStringKeys) {
      final value = _customStrings[key] ?? AppStrings.customStringFormalDefaults[key] ?? "";
      if (value.isEmpty) continue;
      await _tts.speak(value);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _resetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text("Reset hlasových zpráv")),
        content: const Text("Opravdu chcete vrátit všechny hlasové zprávy na výchozí hodnoty?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Zrušit")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Resetovat", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    await widget.db.clearCustomStrings();
    setState(() {
      _customStrings = {};
    });
    AppStrings.setCustomStrings({});
    _tts.speak("Hlasové zprávy vráceny do výchozího stavu");
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Vlastní hlasové zprávy"),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: "Přehrát všechny hlášky",
            onPressed: _playAll,
          ),
        ],
      ),
      body: ListView(
        children: [
          ...AppStrings.customStringKeys.map((key) {
            final label = AppStrings.customStringKeyLabels[key] ?? key;
            final hint = AppStrings.customStringFormalDefaults[key];
            return ListTile(
              title: Text(label),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Klíč: $key",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: _customStrings[key] ?? "",
                    decoration: InputDecoration(
                      labelText: "Vlastní text",
                      hintText: hint,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (val) => _updateString(key, val),
                    onEditingComplete: () => _finishEditing(key),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text("Reset na výchozí"),
            subtitle: const Text("Smaže všechny vlastní hlasové zprávy"),
            onTap: _resetAll,
          ),
        ],
      ),
    );
  }
}