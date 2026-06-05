import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database.dart';
import 'app_strings.dart';

class SettingsPage extends StatefulWidget {
  final AppDatabase db;
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeModeChanged;
  final bool isInformalMode;
  final Function(bool) onInformalModeChanged;

  const SettingsPage({
    super.key, 
    required this.db,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.isInformalMode,
    required this.onInformalModeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
  }

  Future<void> _exportBackup() async {
    try {
      final data = await widget.db.exportToJson();
      final jsonString = jsonEncode(data);
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/posouvac_zaloha.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'Záloha aplikace Posouvač textu');
      _tts.speak(AppStrings.backupExportSuccess);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Chyba při exportu: $e")));
      }
    }
  }

  Future<void> _importBackup() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.backupTitle),
        content: Text(AppStrings.backupImportWarning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Zrušit")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Pokračovat", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        
        await widget.db.importFromJson(data);
        _tts.speak(AppStrings.backupImportSuccess);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.backupImportSuccess)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Chyba při importu: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.settingsTitle),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.backup),
            title: Text(AppStrings.backupTitle),
            subtitle: const Text("Export a import kompletních dat aplikace"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.maxFinite, 50)),
                  icon: const Icon(Icons.upload),
                  label: Text(AppStrings.backupExportButton),
                  onPressed: _exportBackup,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.maxFinite, 50)),
                  icon: const Icon(Icons.download),
                  label: Text(AppStrings.backupImportButton),
                  onPressed: _importBackup,
                ),
              ],
            ),
          ),
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text("Vynulovat koncert"),
            onTap: () async {
              await widget.db.resetAllPlayed();
              _tts.speak(AppStrings.resetPlayed);
            },
          ),
          SwitchListTile(
            title: const Text("Neformální režim"),
            subtitle: Text(widget.isInformalMode ? "Zapnuto" : "Vypnuto"),
            value: widget.isInformalMode,
            onChanged: widget.onInformalModeChanged,
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text("Motiv aplikace"),
            subtitle: Text("Aktuálně: ${widget.themeMode.name}"),
            onTap: () {
              final nextMode = ThemeMode.values[(widget.themeMode.index + 1) % ThemeMode.values.length];
              widget.onThemeModeChanged(nextMode);
            },
          ),
        ],
      ),
    );
  }
}
