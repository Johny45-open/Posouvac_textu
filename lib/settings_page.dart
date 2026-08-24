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
import 'app_progress_indicator.dart';
import 'app_strings.dart';
import 'custom_tts_settings_page.dart';
import 'dev_log.dart';
import 'dev_pin_service.dart';
import 'library_checker.dart';
import 'update_dialogs.dart';
import 'package:flutter/services.dart';

class SettingsPage extends StatefulWidget {
  final AppDatabase db;
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeModeChanged;
  final bool isInformalMode;
  final Function(bool) onInformalModeChanged;
  final bool concertMode;
  final ValueChanged<bool> onConcertModeChanged;
  final int concertPreviewMode;
  final ValueChanged<int> onConcertPreviewModeChanged;
  final bool concertTrainingMode;
  final ValueChanged<bool> onConcertTrainingModeChanged;
  final int concertZonesMode;
  final ValueChanged<int> onConcertZonesModeChanged;
  final int setlistDelay;
  final ValueChanged<int> onSetlistDelayChanged;
  final bool devModeUnlocked;
  final ValueChanged<bool> onDevModeChanged;

  const SettingsPage({
    super.key,
    required this.db,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.isInformalMode,
    required this.onInformalModeChanged,
    required this.concertMode,
    required this.onConcertModeChanged,
    required this.concertPreviewMode,
    required this.onConcertPreviewModeChanged,
    required this.concertTrainingMode,
    required this.onConcertTrainingModeChanged,
    required this.concertZonesMode,
    required this.onConcertZonesModeChanged,
    required this.setlistDelay,
    required this.onSetlistDelayChanged,
    required this.devModeUnlocked,
    required this.onDevModeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FlutterTts _tts = FlutterTts();
  late final DevPinService _pinService;

  late bool _devModeUnlocked;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _devModeUnlocked = widget.devModeUnlocked;
    _pinService = DevPinService(db: widget.db);
  }

  /// Hlasové zprávy - PIN už byl ověřen při vstupu do vývojářského režimu.
  Future<void> _openVoiceMessages() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CustomTtsSettingsPage(db: widget.db)),
    );
  }

  String _previewModeAnnouncement(int mode) {
    final String name = mode == 0
        ? AppStrings.concertPreviewOff
        : mode == 1
            ? AppStrings.concertPreviewOnDemand
            : AppStrings.concertPreviewAuto;
    final String hint = mode == 0
        ? AppStrings.concertPreviewOffHint
        : mode == 1
            ? AppStrings.concertPreviewOnDemandHint
            : AppStrings.concertPreviewAutoHint;
    return "$name. $hint";
  }

  String _zonesModeAnnouncement(int mode) {
    final String name = mode == 0 ? AppStrings.concertZonesAlways : AppStrings.concertZonesOnDemand;
    final String hint = mode == 0 ? AppStrings.concertZonesAlwaysHint : AppStrings.concertZonesOnDemandHint;
    return "$name. $hint";
  }

  Future<void> _changeDevPin() async {
    final ok = await _pinService.verifyDevPin(context, _tts);
    if (!ok || !mounted) return;

    final newPin = await _pinService.promptForPin(context, title: "Nový vývojářský PIN");
    if (newPin == null) return;
    if (newPin.isEmpty) {
      if (!mounted) return;
      _tts.speak(AppStrings.pinEmpty);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.pinEmpty)),
      );
      return;
    }
    if (newPin.length < 4) {
      if (!mounted) return;
      _tts.speak(AppStrings.pinTooShort);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.pinTooShort)),
      );
      return;
    }

    final confirmPin = await _pinService.promptForPin(context, title: "Potvrďte nový vývojářský PIN");
    if (confirmPin == null) return;
    if (newPin != confirmPin) {
      if (!mounted) return;
      _tts.speak(AppStrings.pinMismatch);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.pinMismatch)),
      );
      return;
    }

    await _pinService.saveNewPin(newPin);
    _tts.speak("Vývojářský PIN změněn");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vývojářský PIN byl změněn")),
      );
    }
  }

  Future<void> _disableDevMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('devModeUnlocked', false);
    await _pinService.resetState();
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
        title: Semantics(header: true, child: Text("Info o aplikaci a zařízení")),
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
        title: Semantics(header: true, child: Text(AppStrings.backupTitle)),
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

  Future<void> _checkForUpdates() async {
    await runUpdateCheck(context);
  }

  Future<void> _showReleaseHistory() async {
    await openReleaseHistory(context);
  }

  Future<void> _showCsvHelp() async {
    const helpText = 
          "1. Exportujte CSV soubor.\n"
          "2. Otevřete ho v Excelu.\n"
          "3. Sloupce 'id' a 'filePath' jsou klíčové, NEUPRAVUJTE JE ANI NESMAŽTE – podle nich se pozná, ke které písni řádek patří. Nesouhlasí-li soubor, řádek se bezpečně přeskočí.\n"
          "4. Upravujte pouze sloupce 'artist', 'title' a 'duration'.\n"
          "5. Po úpravě uložte jako CSV (UTF-8) a importujte zpět.";
    
    _tts.speak("Návod pro úpravu CSV: " + helpText);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text("Jak upravit metadata")),
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
          title: Semantics(header: true, child: Text("Náhled změn")),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: previewData.length,
              itemBuilder: (context, i) {
                final p = previewData[i];
                final mismatch = p['pathMismatch'] == true;
                return ListTile(
                  leading: mismatch
                      ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
                      : const Icon(Icons.edit_note),
                  title: Text("${p['oldTitle']} -> ${p['newTitle']}"),
                  subtitle: Text(
                    mismatch
                        ? "Interpret: ${p['oldArtist']} -> ${p['newArtist']} (přeskočí se – soubor neodpovídá)"
                        : "Interpret: ${p['oldArtist']} -> ${p['newArtist']}",
                  ),
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
        final result = await widget.db.importSongsFromCsv(csvString);
        _tts.speak("Importováno ${result.updated} písní");
        if (mounted) {
          final message = result.skipped > 0
              ? "Aktualizováno ${result.updated} písní, přeskočeno ${result.skipped} (nesedí soubor)."
              : "Aktualizováno ${result.updated} písní";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _checkLibrary() async {
    _tts.speak(AppStrings.libraryCheckRunning);

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: AppProgressIndicator(label: AppStrings.libraryCheckRunning),
      ),
    ));

    List<LibraryIssue> issues;
    try {
      issues = await LibraryChecker.findIssues(widget.db);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _tts.speak(AppStrings.libraryCheckRepairFailed);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kontrolu knihovny se nepodařilo dokončit.")),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();

    if (issues.isEmpty) {
      _tts.speak(AppStrings.libraryCheckOk);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Semantics(header: true, child: Text(AppStrings.libraryCheckTile)),
          content: Text(AppStrings.libraryCheckOk),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppStrings.libraryCheckCloseButton),
            ),
          ],
        ),
      );
      return;
    }

    _tts.speak(AppStrings.libraryCheckFound(issues.length));

    final bool? repair = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Semantics(header: true, child: Text(AppStrings.libraryCheckTile)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: issues.length,
            itemBuilder: (context, i) {
              final issue = issues[i];
              if (issue.fileMissing) {
                return ListTile(
                  leading: const Icon(Icons.file_present, color: Colors.red),
                  title: Text("${issue.currentArtist} - ${issue.currentTitle}"),
                  subtitle: Text(
                      "${AppStrings.libraryCheckFileMissing}: ${issue.filePath}"),
                  isThreeLine: true,
                );
              }
              return ListTile(
                leading: const Icon(Icons.edit_note),
                title: Text("${issue.currentArtist} - ${issue.currentTitle}"),
                subtitle: Text(
                    "→ ${issue.suggestedArtist} - ${issue.suggestedTitle}"),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.libraryCheckCloseButton),
          ),
          if (issues.any((issue) => issue.metadataDiffers))
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppStrings.libraryCheckRepairButton),
            ),
        ],
      ),
    );

    if (repair != true) return;

    try {
      final repaired = await LibraryChecker.repairAll(widget.db, issues);
      _tts.speak(AppStrings.libraryCheckRepaired(repaired));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.libraryCheckRepaired(repaired))),
        );
      }
    } catch (_) {
      _tts.speak(AppStrings.libraryCheckRepairFailed);
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
            leading: const Icon(Icons.fact_check),
            title: Text(AppStrings.libraryCheckTile),
            subtitle: Text(AppStrings.libraryCheckSubtitle),
            onTap: _checkLibrary,
          ),
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text("Vynulovat koncert"),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Semantics(header: true, child: Text("Vynulovat koncert")),
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
            title: Text(AppStrings.concertModeTitle),
            subtitle: Text(widget.concertMode ? AppStrings.concertModeSubtitleOn : AppStrings.concertModeSubtitleOff),
            secondary: Icon(widget.concertMode ? Icons.hearing : Icons.hearing_disabled, color: widget.concertMode ? Colors.green : null),
            value: widget.concertMode,
            onChanged: (v) async {
              widget.onConcertModeChanged(v);
              _tts.speak(v ? AppStrings.concertModeAnnouncementOn : AppStrings.concertModeAnnouncementOff);
              try {
                await const MethodChannel('concert_volume_channel').invokeMethod('setConcertMode', {'enabled': v});
              } catch (_) {}
            },
          ),
          if (widget.concertMode) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.concertPreviewModeTitle, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(AppStrings.concertPreviewOff), icon: Icon(Icons.notifications_off)),
                      ButtonSegment(value: 1, label: Text(AppStrings.concertPreviewOnDemand), icon: Icon(Icons.touch_app)),
                      ButtonSegment(value: 2, label: Text(AppStrings.concertPreviewAuto), icon: Icon(Icons.auto_awesome)),
                    ],
                    selected: {widget.concertPreviewMode},
                    onSelectionChanged: (s) {
                      final mode = s.first;
                      widget.onConcertPreviewModeChanged(mode);
                      _tts.speak(_previewModeAnnouncement(mode));
                    },
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _previewModeAnnouncement(widget.concertPreviewMode),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.concertZonesModeTitle, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(AppStrings.concertZonesAlways), icon: Icon(Icons.tap_and_play)),
                      ButtonSegment(value: 1, label: Text(AppStrings.concertZonesOnDemand), icon: Icon(Icons.pan_tool)),
                    ],
                    selected: {widget.concertZonesMode},
                    onSelectionChanged: (s) {
                      final mode = s.first;
                      widget.onConcertZonesModeChanged(mode);
                      _tts.speak(_zonesModeAnnouncement(mode));
                    },
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _zonesModeAnnouncement(widget.concertZonesMode),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            SwitchListTile(
              title: const Text("Tréninkový režim zón"),
              subtitle: const Text("Při dotyku ohlásí funkci zóny"),
              value: widget.concertTrainingMode,
              onChanged: widget.onConcertTrainingModeChanged,
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.setlistDelayTitle, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(AppStrings.setlistDelaySubtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 3, label: Text(AppStrings.setlistDelay3)),
                      ButtonSegment(value: 5, label: Text(AppStrings.setlistDelay5)),
                      ButtonSegment(value: 10, label: Text(AppStrings.setlistDelay10)),
                      ButtonSegment(value: -1, label: Text(AppStrings.setlistDelayWait), icon: Icon(Icons.touch_app)),
                    ],
                    selected: {widget.setlistDelay},
                    onSelectionChanged: (s) {
                      final d = s.first;
                      widget.onSetlistDelayChanged(d);
                      _tts.speak(AppStrings.setlistDelayAnnouncement(d));
                    },
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      AppStrings.setlistDelayAnnouncement(widget.setlistDelay),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
          ],
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
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: Text(AppStrings.updateCheckTile),
            subtitle: Text(AppStrings.updateCheckTileSubtitle),
            onTap: _checkForUpdates,
          ),
          ListTile(
            leading: const Icon(Icons.new_releases),
            title: Text(AppStrings.updateNewsTile),
            subtitle: Text(AppStrings.updateNewsTileSubtitle),
            onTap: _showReleaseHistory,
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
              subtitle: const Text("Upravit hlasové hlášky aplikace"),
              onTap: _openVoiceMessages,
            ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text("Změnit vývojářský PIN"),
              onTap: _changeDevPin,
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
