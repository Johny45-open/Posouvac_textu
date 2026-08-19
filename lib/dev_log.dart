import 'package:flutter/material.dart';

class DevLog {
  static final List<String> _entries = [];
  static const int maxEntries = 500;

  static List<String> get entries => List.unmodifiable(_entries);

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = "$timestamp  $message";
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    debugPrint("[DevLog] $message");
  }

  static void clear() => _entries.clear();
}

class DevLogPage extends StatefulWidget {
  const DevLogPage({super.key});

  @override
  State<DevLogPage> createState() => _DevLogPageState();
}

class _DevLogPageState extends State<DevLogPage> {
  @override
  Widget build(BuildContext context) {
    final entries = DevLog.entries;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Debug log"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Vymazat log",
            onPressed: () {
              DevLog.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(child: Text("Zatím žádné záznamy."))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(entries[index], style: const TextStyle(fontFamily: "monospace", fontSize: 12)),
                );
              },
            ),
    );
  }
}