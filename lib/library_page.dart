import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:permission_handler/permission_handler.dart';
import 'database.dart';
import 'song_entry.dart';
import 'playlists_page.dart';
import 'player_page.dart';
import 'song_utils.dart';
import 'app_progress_indicator.dart';
import 'tuner.dart';
import 'app_strings.dart';

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

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);
    AppStrings.isInformal = widget.isInformalMode;
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
                    child: TextFormField(
                      controller: minController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: "Minut", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: secController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: "Sekund", border: OutlineInputBorder()),
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

  Future<void> _addToPlaylist(SongEntry song) async {
    final playlists = await widget.db.getAllPlaylists();
    if (playlists.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nejdříve si vytvořte playlist v sekci Playlisty.")),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Přidat do playlistu"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playlists.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(playlists[i].name),
              onTap: () async {
                final result = await widget.db.addSongToPlaylist(playlists[i].id, song.id);
                if (mounted) {
                  Navigator.pop(context);
                  if (result == -1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Tato píseň již v playlistu je.")),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Píseň přidána do playlistu ${playlists[i].name}")),
                    );
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Knihovna"),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: "Nápověda",
            onPressed: widget.onOpenManual,
          ),
          IconButton(
            icon: const Icon(Icons.music_note),
            tooltip: "Ladička",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TunerPage()),
            ),
          ),
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_6),
            tooltip: "Změnit motiv",
            onSelected: (val) {
              widget.onThemeModeChanged(val);
              String themeMsg = val == ThemeMode.light 
                ? AppStrings.themeLight 
                : (val == ThemeMode.dark ? AppStrings.themeDark : AppStrings.themeSystem);
              _tts.speak(themeMsg);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: ThemeMode.light, child: Text("Světlý")),
              const PopupMenuItem(value: ThemeMode.dark, child: Text("Tmavý")),
              const PopupMenuItem(value: ThemeMode.system, child: Text("Systémový")),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: "Playlisty",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PlaylistsPage(db: widget.db)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Vynulovat odehrané",
            onPressed: () async {
              await widget.db.resetAllPlayed();
              _tts.speak(AppStrings.resetPlayed);
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(widget.isInformalMode ? Icons.business : Icons.sentiment_satisfied),
            tooltip: widget.isInformalMode ? "Přepnout na formální režim" : "Přepnout na neformální režim",
            onPressed: () {
              widget.onInformalModeChanged(!widget.isInformalMode);
              _tts.speak(widget.isInformalMode ? "Přepínám do formálního režimu" : "Přepínám do neformálního režimu");
            },
          ),
          PopupMenuButton<bool>(
            icon: const Icon(Icons.sort_by_alpha),
            tooltip: "Seřadit podle",
            onSelected: (val) {
              setState(() => _sortByArtist = val);
              _tts.speak(val ? "Řadím podle interpretů" : "Řadím podle názvů písní");
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: true, child: Text("Podle interpreta")),
              const PopupMenuItem(value: false, child: Text("Podle názvu")),
            ],
          ),
          FilterChip(
            label: const Text("Oblíbené"),
            selected: _onlyFavorites,
            onSelected: (val) {
              setState(() => _onlyFavorites = val);
              _tts.speak(val ? AppStrings.filterFavorites : AppStrings.filterAll);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text("K odehrání"),
            selected: _onlyUnplayed,
            onSelected: (val) {
              setState(() => _onlyUnplayed = val);
              _tts.speak(val ? AppStrings.filterUnplayed : AppStrings.filterAll);
            },
          ),
        ],
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
            return const Center(child: Text("Knihovna je prázdná."));
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
                  ],
                ),
              ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _performTextImport,
        tooltip: "Vybrat složku",
        child: const Icon(Icons.folder_open),
      ),
    );
  }
}
