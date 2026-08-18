import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'database.dart';
import 'song_entry.dart';
import 'playlists_page.dart';
import 'player_page.dart';
import 'settings_page.dart';
import 'manual_page.dart';
import 'song_utils.dart';
import 'app_progress_indicator.dart';
import 'tuner.dart';
import 'app_strings.dart';
import 'song_export.dart';
import 'qr_scan_page.dart';

class LibraryPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final AppDatabase db;
  final VoidCallback onOpenManual;
  final bool isInformalMode;
  final ValueChanged<bool> onInformalModeChanged;

  const LibraryPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.db,
    required this.onOpenManual,
    required this.isInformalMode,
    required this.onInformalModeChanged,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final FlutterTts _tts = FlutterTts();
  bool _onlyFavorites = false;
  bool _onlyUnplayed = false;
  bool _sortByArtist = true;
  String _version = "";

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);
    AppStrings.isInformal = widget.isInformalMode;
    _initVersion();
  }

  Future<void> _initVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = packageInfo.version;
      });
    }
  }

  @override
  void didUpdateWidget(LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isInformalMode != widget.isInformalMode) {
      AppStrings.isInformal = widget.isInformalMode;
    }
  }

  Future<void> _editSong(SongEntry song) async {
    final artistController = TextEditingController(text: song.artist);
    final titleController = TextEditingController(text: song.title);
    
    int initialMinutes = (song.duration ?? 0) ~/ 60;
    int initialSeconds = (song.duration ?? 0) % 60;
    final minController = TextEditingController(text: initialMinutes > 0 ? initialMinutes.toString() : "");
    final secController = TextEditingController(text: initialSeconds > 0 ? initialSeconds.toString() : "");

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Upravit píseň"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: artistController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: "Jméno interpreta",
                  hintText: "Zadejte jméno interpreta",
                  helperText: "Upravte jméno umělce",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: "Název písně",
                  hintText: "Zadejte název písně",
                  helperText: "Upravte název skladby",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Délka skladby", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: "Délka skladby v minutách",
                      child: TextFormField(
                        controller: minController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: "Minut", border: OutlineInputBorder()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      label: "Délka skladby v sekundách",
                      child: TextFormField(
                        controller: secController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: "Sekund", border: OutlineInputBorder()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zrušit")),
          TextButton(
            onPressed: () async {
              await widget.db.updateSong(song.id, artistController.text, titleController.text);
              
              int totalSec = (int.tryParse(minController.text) ?? 0) * 60 + (int.tryParse(secController.text) ?? 0);
              await widget.db.updateSongDuration(song.id, totalSec > 0 ? totalSec : null);
              
              _tts.speak("Píseň upravena");
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Uložit"),
          ),
        ],
      ),
    );
  }

  Future<void> _performTextImport() async {
    await [
      Permission.manageExternalStorage,
      Permission.storage,
    ].request();

    // Dialog pro výběr typu importu
    final importType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.importTypeTitle),
        content: Text(AppStrings.importTypeContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, "folder"),
            child: const Text("Vybrat složku"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, "files"),
            child: const Text("Vybrat soubory"),
          ),
        ],
      ),
    );

    if (importType == null) return;

    List<File> txtFiles = [];

    if (importType == "folder") {
      String? path = await FilePicker.getDirectoryPath();
      if (path == null) return;
      debugPrint("Vybraná složka: $path");
      final dir = Directory(path);
      try {
        if (!await dir.exists()) {
          _tts.speak("Složka nebyla nalezena. Zkuste metodu Vybrat soubory.");
          return;
        }
        final allEntities = dir.listSync(recursive: true);
        txtFiles = allEntities.whereType<File>().where((f) => f.path.toLowerCase().endsWith('.txt')).toList();
      } catch (e) {
        debugPrint("Chyba složky: $e");
        _tts.speak("Chyba přístupu ke složce. Zkuste metodu Vybrat soubory.");
        return;
      }
    } else {
      // Přímý výběr souborů - nejspolehlivější metoda
      FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result == null || result.files.isEmpty) return;
      txtFiles = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
    }

    final totalFiles = txtFiles.length;
    int processed = 0;

    if (totalFiles == 0) {
      _tts.speak("Nebyly nalezeny žádné textové soubory.");
      return;
    }

    // Zjistíme počet písní před importem
    final songsBefore = await widget.db.getAllSongs();
    final countBefore = songsBefore.length;

    StateSetter? updateDialog;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setS) {
            updateDialog = setS;
            final progress = totalFiles > 0 ? processed / totalFiles : 0.0;
            return AlertDialog(
              title: Text(AppStrings.importDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppProgressIndicator(
                    value: progress,
                    label: "$processed z $totalFiles souborů",
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    for (var entity in txtFiles) {
      try {
        final bytes = await entity.readAsBytes();
        String content;
        try {
          content = utf8.decode(bytes);
        } catch (_) {
          content = latin1.decode(bytes);
        }
        
        final lines = content.split('\n');
        final firstLine = lines.isNotEmpty ? lines.first.trim() : "";
        final title = (firstLine.isNotEmpty && firstLine.length < 50) 
            ? firstLine 
            : Song.parseImportedFileName(entity.path).title;
        final artist = Song.parseImportedFileName(entity.path).artist ?? "Neznámý interpret";

        await widget.db.into(widget.db.songs).insert(
          SongsCompanion.insert(
            filePath: entity.path,
            artist: artist,
            title: title,
          ),
          mode: InsertMode.insertOrIgnore,
        );
        
        processed++;
        if (updateDialog != null) {
          updateDialog!(() {});
        }
      } catch (e) {
        debugPrint("Chyba importu: $e");
      }
    }

    if (context.mounted) Navigator.pop(context); 

    // Zjistíme počet písní po importu
    final songsAfter = await widget.db.getAllSongs();
    final countAfter = songsAfter.length;
    final newlyAdded = countAfter - countBefore;

    if (newlyAdded > 0) {
      await _tts.speak(AppStrings.importFinished(newlyAdded));
    } else {
      await _tts.speak(AppStrings.noNewSongs);
    }
  }

  Future<void> _deleteSong(SongEntry song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Smazat píseň"),
        content: Text("Opravdu chcete smazat píseň \"${song.title}\" od interpreta \"${song.artist}\"?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Zrušit")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Smazat", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await widget.db.deleteSong(song.id);
    _tts.speak("Píseň ${song.title} od ${song.artist} byla smazána.");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Smazáno: ${song.title}")),
      );
    }
  }

  Future<void> _shareSong(SongEntry song) async {
    try {
      final file = File(song.filePath);
      if (!await file.exists()) {
        _tts.speak(AppStrings.shareFileMissing);
        return;
      }
      final bytes = await file.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }
      await showSongShareDialog(
        context,
        title: song.title,
        artist: song.artist,
        content: content,
      );
    } catch (_) {
      _tts.speak(AppStrings.shareFileMissing);
    }
  }

  Future<void> _addToPlaylist(SongEntry song) async {
    final playlists = await widget.db.getAllPlaylists();
    if (playlists.isEmpty) {
      _tts.speak("Nemáte žádný playlist. Vytvořte ho v sekci Playlisty a pak zkuste skladbu přidat znovu.");
      return;
    }

    final selected = await showDialog<Playlist>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Přidat do playlistu"),
        children: [
          for (final p in playlists)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p),
              child: Semantics(
                label: "Přidat skladbu ${song.title} do playlistu ${p.name}",
                child: Text(p.name),
              ),
            ),
        ],
      ),
    );

    if (selected == null) return;
    await widget.db.addSongToPlaylist(selected.id, song.id);
    _tts.speak("Píseň ${song.title} přidána do playlistu ${selected.name}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Knihovna"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: "Otevřít menu",
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_onlyFavorites ? Icons.favorite : Icons.favorite_border),
            tooltip: _onlyFavorites ? "Zobrazit všechny" : "Pouze oblíbené",
            onPressed: () {
              setState(() => _onlyFavorites = !_onlyFavorites);
              _tts.speak(_onlyFavorites 
                  ? (AppStrings.isInformal ? "Ukazuju jen oblíbený." : "Zobrazuji pouze oblíbené.")
                  : (AppStrings.isInformal ? "Ukazuju úplně všechno." : "Zobrazuji všechny skladby."));
            },
          ),
          IconButton(
            icon: Icon(_onlyUnplayed ? Icons.check_box : Icons.check_box_outline_blank),
            tooltip: _onlyUnplayed ? "Zobrazit vše" : "Pouze k odehrání",
            onPressed: () {
              setState(() => _onlyUnplayed = !_onlyUnplayed);
              _tts.speak(_onlyUnplayed 
                  ? (AppStrings.isInformal ? "Ukazuju věci, co čekají na zahrání." : "Zobrazuji pouze skladby k odehrání.")
                  : (AppStrings.isInformal ? "Ukazuju úplně všechno." : "Zobrazuji všechny skladby."));
            },
          ),
          IconButton(
            icon: const Icon(Icons.music_note),
            tooltip: "Ladička",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TunerPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: "Playlisty",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PlaylistsPage(db: widget.db)),
            ),
          ),
          PopupMenuButton<bool>(
            icon: const Icon(Icons.sort_by_alpha),
            tooltip: "Seřadit podle",
            onSelected: (val) {
              setState(() => _sortByArtist = val);
              _tts.speak(val ? "Řadím podle interpretů" : "Řadím podle názvů písní");
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: true,
                child: Semantics(
                  label: "Seřadit písně podle interpreta",
                  child: const Text("Podle interpreta"),
                ),
              ),
              PopupMenuItem(
                value: false,
                child: Semantics(
                  label: "Seřadit písně podle názvu",
                  child: const Text("Podle názvu"),
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_stories, size: 50, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    "Posouvač textu v$_version",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(AppStrings.settingsTitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      db: widget.db,
                      themeMode: widget.themeMode,
                      onThemeModeChanged: widget.onThemeModeChanged,
                      isInformalMode: widget.isInformalMode,
                      onInformalModeChanged: widget.onInformalModeChanged,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text("Návod k použití"),
              onTap: () {
                Navigator.pop(context);
                widget.onOpenManual();
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text("Neformální režim"),
              subtitle: const Text("Mluvit na mě přátelsky"),
              value: widget.isInformalMode,
              onChanged: (val) {
                Navigator.pop(context);
                widget.onInformalModeChanged(val);
                _tts.speak(val ? "Přepínám do neformálního režimu" : "Přepínám do formálního režimu");
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text("Vynulovat odehrané"),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Vynulovat odehrané"),
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
                setState(() {});
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<SongEntry>>(
        stream: widget.db.watchAllSongs(
          onlyFavorites: _onlyFavorites,
          onlyUnplayed: _onlyUnplayed,
          sortByArtist: _sortByArtist,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final songs = snapshot.data!;
          
          if (songs.isEmpty) {
            return Semantics(
              liveRegion: true,
              label: "Knihovna je prázdná. Importujte texty tlačítkem vpravo dole.",
              child: const Center(child: Text("Knihovna je prázdná.")),
            );
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final bpmText = song.tempo != null ? "${song.tempo!.round()} údery za minutu" : "Tempo nenastaveno";
              final playedText = song.isPlayed ? "Odehraná. " : "";
              
              String durationText = "";
              String durationSemantics = "";
              if (song.duration != null && song.duration! > 0) {
                final m = song.duration! ~/ 60;
                final s = song.duration! % 60;
                durationText = " [$m:${s.toString().padLeft(2, '0')}]";
                durationSemantics = ". Délka $m minut a $s sekund.";
              }

              // Vyčistíme název od duplicitního interpreta
              String cleanTitle = song.title;
              if (cleanTitle.startsWith("${song.artist} - ")) {
                cleanTitle = cleanTitle.replaceFirst("${song.artist} - ", "");
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Opacity(
                  opacity: song.isPlayed ? 0.5 : 1.0,
                  child: Row(
                    children: [
                      // 1. ŠVIH: Pouze akce oblíbené
                      Semantics(
                        container: true,
                        excludeSemantics: true,
                        label: song.isFavorite 
                          ? "Odebrat skladbu $cleanTitle od ${song.artist} z oblíbených" 
                          : "Přidat skladbu $cleanTitle od ${song.artist} k oblíbeným",
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            song.isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: song.isFavorite ? Colors.red : null,
                          ),
                          onPressed: () async {
                            final newStatus = !song.isFavorite;
                            await widget.db.toggleFavorite(song.id, newStatus);
                            _tts.speak(newStatus 
                                ? AppStrings.songMarkedFavorite(cleanTitle)
                                : AppStrings.songRemovedFavorite(cleanTitle));
                          },
                        ),
                      ),

                      // 2. ŠVIH: Kompletní informace + Přehrát/Upravit
                      Expanded(
                        child: Semantics(
                          container: true,
                          excludeSemantics: true,
                          label: "${playedText}Píseň: $cleanTitle od ${song.artist}$durationSemantics $bpmText. Poklepáním přehrajete, podržením upravíte.",
                          button: true,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PlayerPage(songId: song.id, db: widget.db)),
                            ),
                            onLongPress: () => _editSong(song),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (song.isPlayed)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8.0),
                                          child: Icon(Icons.check_circle, size: 16, color: Colors.green),
                                        ),
                                      Expanded(
                                        child: Text(
                                          "${song.artist}$durationText",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    song.title,
                                    style: TextStyle(color: Theme.of(context).hintColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 3. ŠVIH: Pouze akce Playlist
                    Semantics(
                      container: true,
                      excludeSemantics: true,
                      label: "Přidat skladbu $cleanTitle od ${song.artist} do playlistu",
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.playlist_add),
                        onPressed: () => _addToPlaylist(song),
                      ),
                    ),
                    // 4. ŠVIH: Sdílet text
                    Semantics(
                      container: true,
                      excludeSemantics: true,
                      label: "Sdílet text skladby $cleanTitle od ${song.artist}",
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => _shareSong(song),
                      ),
                    ),
                    // 5. ŠVIH: Smazat
                    Semantics(
                      container: true,
                      excludeSemantics: true,
                      label: "Smazat skladbu $cleanTitle od ${song.artist}",
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSong(song),
                      ),
                    ),
                  ],
                ),
              ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (Platform.isAndroid || Platform.isIOS)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.small(
                heroTag: 'qrScanFab',
                tooltip: AppStrings.scanQrTooltip,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QrScanPage(db: widget.db),
                  ),
                ),
                child: const Icon(Icons.qr_code_scanner),
              ),
            ),
          FloatingActionButton(
            onPressed: _performTextImport,
            tooltip: "Importovat textové soubory",
            child: const Icon(Icons.folder_open),
          ),
        ],
      ),
    );
  }
}
