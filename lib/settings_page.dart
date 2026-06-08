import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database.dart';
import 'app_strings.dart';
import 'custom_tts_settings_page.dart';

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

  Future<void> _showCsvHelp() async {
    const helpText = 
          "1. Exportujte CSV soubor.\n"
          "2. Otevřete ho v Excelu.\n"
          "3. Sloupec 'id' je klíčový, NEUPRAVUJTE HO ANI NESMAŽTE, jinak se písně správně neaktualizují.\n"
          "4. Upravujte pouze sloupce 'artist', 'title' a 'duration'.\n"
          "5. Po úpravě uložte jako CSV (UTF-8) a importujte zpět.";
    
    _tts.speak("Návod pro úpravu CSV: " + helpText.replaceAll(RegExp(r'\d+\.\s'), ''));

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Jak upravit metadata"),
        content: const Text(helpText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Rozumím")),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    try {
      final csvString = await widget.db.exportSongsToCsv();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/metadata_pisni.csv');
      await file.writeAsString(csvString, encoding: utf8);

      await Share.shareXFiles([XFile(file.path)], text: 'Metadata písní z aplikace Posouvač textu');
      _tts.speak("Metadata exportována do CSV");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Chyba při exportu: $e")));
      }
    }
  }

  Future<void> _importCsv() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final csvString = await file.readAsString(encoding: utf8);
        
        final previewData = await widget.db.previewSongsFromCsv(csvString);
        
        if (!mounted) return;
        
        if (previewData.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Žádné platné změny k importu.")));
          return;
        }

        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Náhled změn"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: previewData.length,
                itemBuilder: (context, i) {
                  final p = previewData[i];
                  return ListTile(
                    title: Text("${p['oldTitle']} -> ${p['newTitle']}"),
                    subtitle: Text("Interpret: ${p['oldArtist']} -> ${p['newArtist']}"),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Zrušit")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Potvrdit import")),
            ],
          ),
        );

        if (confirm == true) {
          final updatedCount = await widget.db.importSongsFromCsv(csvString);
          _tts.speak("Importováno $updatedCount písní");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Aktualizováno $updatedCount písní")));
          }
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
          // Původní část pro zálohu
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
          // Nová část pro CSV
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text("Hromadná úprava (CSV)"),
            subtitle: const Text("Export a import metadat písní v Excelu"),
            onTap: _showCsvHelp,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.maxFinite, 50)),
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Exportovat CSV"),
                  onPressed: _exportCsv,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.maxFinite, 50)),
                  icon: const Icon(Icons.download_for_offline),
                  label: const Text("Importovat CSV"),
                  onPressed: _importCsv,
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
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text("Vlastní hlasové zprávy"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CustomTtsSettingsPage(db: widget.db)),
            ),
          ),
        ],
      ),
    );
  }
}
