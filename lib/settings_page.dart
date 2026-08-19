import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'database.dart';
import 'app_strings.dart';
import 'custom_tts_settings_page.dart';
import 'dev_log.dart';

class SettingsPage extends StatefulWidget {
  final AppDatabase db;
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeModeChanged;
  final bool isInformalMode;
  final Function(bool) onInformalModeChanged;
  final bool devModeUnlocked;
  final ValueChanged<bool> onDevModeChanged;

  const SettingsPage({
    super.key, 
    required this.db,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.isInformalMode,
    required this.onInformalModeChanged,
    required this.devModeUnlocked,
    required this.onDevModeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FlutterTts _tts = FlutterTts();

  static const String _devVoiceMessagesPin = "1950";
  static const int _maxPinAttempts = 5;
  static const Duration _pinLockoutDuration = Duration(minutes: 5);

  static const String _prefsKeyDevMode = 'devModeUnlocked';
  static const String _prefsKeyPinAttempts = 'devPinFailedAttempts';
  static const String _prefsKeyPinLockoutUntil = 'devPinLockoutUntil';

  late bool _devModeUnlocked;
  int _pinFailedAttempts = 0;
  DateTime? _pinLockoutUntil;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _devModeUnlocked = widget.devModeUnlocked;
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final prefs = await SharedPreferences.getInstance();
    _pinFailedAttempts = prefs.getInt(_prefsKeyPinAttempts) ?? 0;
    final lockoutMs = prefs.getInt(_prefsKeyPinLockoutUntil);
    if (lockoutMs != null) {
      final until = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
      if (until.isAfter(DateTime.now())) {
        _pinLockoutUntil = until;
      } else {
        await prefs.remove(_prefsKeyPinLockoutUntil);
        await prefs.setInt(_prefsKeyPinAttempts, 0);
      }
    }
    if (mounted) setState(() {});
  }

  bool _isLockedOut() =>
      _pinLockoutUntil != null && _pinLockoutUntil!.isAfter(DateTime.now());

  Future<void> _resetPinState() async {
    final prefs = await SharedPreferences.getInstance();
    _pinFailedAttempts = 0;
    _pinLockoutUntil = null;
    await prefs.remove(_prefsKeyPinAttempts);
    await prefs.remove(_prefsKeyPinLockoutUntil);
    if (mounted) setState(() {});
  }

  Future<void> _registerFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    _pinFailedAttempts += 1;
    await prefs.setInt(_prefsKeyPinAttempts, _pinFailedAttempts);
    if (_pinFailedAttempts >= _maxPinAttempts) {
      _pinLockoutUntil = DateTime.now().add(_pinLockoutDuration);
      await prefs.setInt(_prefsKeyPinLockoutUntil, _pinLockoutUntil!.millisecondsSinceEpoch);
      _pinFailedAttempts = 0;
      await prefs.setInt(_prefsKeyPinAttempts, 0);
    }
    if (mounted) setState(() {});
  }

  Future<void> _openVoiceMessages() async {
    await _loadPinState();
    if (!mounted) return;
    if (_isLockedOut()) {
      await _showLockoutDialog();
      return;
    }
    await _showPinEntryDialog();
  }

  Future<void> _showLockoutDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _LockoutDialog(until: _pinLockoutUntil!),
    );
  }

  Future<void> _showPinEntryDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Vývojářský PIN"),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: "PIN"),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Zrušit")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Potvrdit")),
        ],
      ),
    );

    if (result != true) return;

    final entered = controller.text.trim();
    if (entered == _devVoiceMessagesPin) {
      await _resetPinState();
      _tts.speak("Vývojářská sekce odemčena");
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CustomTtsSettingsPage(db: widget.db)),
        );
      }
    } else {
      await _registerFailedAttempt();
      if (!mounted) return;
      if (_isLockedOut()) {
        await _showLockoutDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Nesprávný PIN, zbývá ${_maxPinAttempts - _pinFailedAttempts} pokusů")),
        );
      }
    }
  }

  Future<void> _disableDevMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyDevMode, false);
    await _resetPinState();
    if (mounted) {
      setState(() => _devModeUnlocked = false);
      widget.onDevModeChanged(false);
      _tts.speak("Vývojářský režim vypnut");
    }
  }

  Future<void> _showDevInfoDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final dbFolder = await getApplicationDocumentsDirectory();
    final platform = Platform.isAndroid
        ? "Android"
        : Platform.isIOS
            ? "iOS"
            : Platform.isLinux
                ? "Linux"
                : Platform.isWindows
                    ? "Windows"
                    : Platform.isMacOS
                        ? "macOS"
                        : "Neznámé";
    final lines = [
      "Verze aplikace: ${packageInfo.version}",
      "Build: ${packageInfo.buildNumber}",
      "Platforma: $platform",
      "OS verze: ${Platform.operatingSystemVersion}",
      "Dart/Flutter: ${Platform.version}",
      "Schéma databáze: ${widget.db.schemaVersion}",
      "Soubor databáze: ${p.join(dbFolder.path, 'db.sqlite')}",
    ];
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Info o aplikaci a zařízení"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(line),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zavřít")),
        ],
      ),
    );
  }

  Future<void> _exportDatabase() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final source = File(p.join(dbFolder.path, 'db.sqlite'));
      if (!await source.exists()) {
        throw Exception("Databáze nebyla nalezena.");
      }
      final tempDir = await getTemporaryDirectory();
      final target = File('${tempDir.path}/posouvac_databaze.sqlite');
      await source.copy(target.path);
      await Share.shareXFiles([XFile(target.path)], text: 'Databáze aplikace Posouvač textu');
      _tts.speak("Databáze exportována");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Chyba při exportu databáze: $e")));
      }
    }
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
    
    _tts.speak("Návod pro úpravu CSV: " + helpText);

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
    DevLog.log("Tlačítko importu stisknuto");
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) {
        DevLog.log("Uživatel nevybral žádný soubor");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Import zrušen.")));
        }
        return;
      }

      DevLog.log("Soubor vybrán: ${result.files.single.path}");
      
      final file = File(result.files.single.path!);
      final csvString = await file.readAsString(encoding: utf8);
      
      DevLog.log("Soubor přečten, délka: ${csvString.length}");
      
      final previewData = await widget.db.previewSongsFromCsv(csvString);
      
      DevLog.log("Počet položek k náhledu: ${previewData.length}");
      
      if (!mounted) return;
      
      if (previewData.isEmpty) {
        DevLog.log("Žádné platné změny k importu.");
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
        DevLog.log("Potvrzen import, spouštím zápis do databáze");
        final updatedCount = await widget.db.importSongsFromCsv(csvString);
        _tts.speak("Importováno $updatedCount písní");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Aktualizováno $updatedCount písní")));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      DevLog.log("CHYBA PŘI IMPORTU: $e");
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
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Vynulovat koncert"),
                  content: const Text("Opravdu chcete vynulovat všechny odehrané písně?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Zrušit")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Vynulovat", style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm != true) return;
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
              
              String message;
              switch (nextMode) {
                case ThemeMode.light:
                  message = AppStrings.themeLight;
                  break;
                case ThemeMode.dark:
                  message = AppStrings.themeDark;
                  break;
                case ThemeMode.system:
                default:
                  message = AppStrings.themeSystem;
                  break;
              }
              _tts.speak(message);
            },
          ),
          if (_devModeUnlocked) ...[
            const Divider(height: 40),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                "Vývojářské funkce",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over),
              title: const Text("Vlastní hlasové zprávy"),
              subtitle: const Text("Upravit hlasové hlášky aplikace (PIN)"),
              onTap: _openVoiceMessages,
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("Info o aplikaci a zařízení"),
              onTap: _showDevInfoDialog,
            ),
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text("Debug log"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DevLogPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text("Export databáze"),
              subtitle: const Text("Sdílet surový SQLite soubor"),
              onTap: _exportDatabase,
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text("Vypnout vývojářský režim"),
              onTap: _disableDevMode,
            ),
          ],
        ],
      ),
    );
  }
}

class _LockoutDialog extends StatefulWidget {
  final DateTime until;

  const _LockoutDialog({required this.until});

  @override
  State<_LockoutDialog> createState() => _LockoutDialogState();
}

class _LockoutDialogState extends State<_LockoutDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.until.difference(DateTime.now());
    return AlertDialog(
      title: const Text("Příliš mnoho pokusů"),
      content: Text("Vyčkejte prosím ${_format(remaining)} než to zkusíte znovu."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zavřít")),
      ],
    );
  }
}
