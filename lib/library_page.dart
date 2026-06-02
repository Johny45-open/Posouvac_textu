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

class LibraryPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final AppDatabase db;

  const LibraryPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.db,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final FlutterTts _tts = FlutterTts();
  bool _onlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
  }

  Future<void> _editSong(SongEntry song) async {
    final artistController = TextEditingController(text: song.artist);
    final titleController = TextEditingController(text: song.title);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Upravit píseň"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: artistController, decoration: const InputDecoration(labelText: "Interpret")),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Název")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zrušit")),
          TextButton(
            onPressed: () async {
              await widget.db.updateSong(song.id, artistController.text, titleController.text);
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

    String? path = await FilePicker.getDirectoryPath();
    if (path == null) return;

    final dir = Directory(path);
    final allFiles = dir.listSync(recursive: true);
    final txtFiles = allFiles.whereType<File>().where((f) => f.path.toLowerCase().endsWith('.txt')).toList();
    
    final totalFiles = txtFiles.length;
    int processed = 0;

    if (totalFiles == 0) {
      _tts.speak("Nebyly nalezeny žádné textové soubory.");
      return;
    }

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
              title: const Text("Importuji texty"),
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
    await _tts.speak("Import dokončen. Celkem uloženo $processed písní.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Knihovna"),
        actions: [
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
            onSelected: widget.onThemeModeChanged,
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
          FilterChip(
            label: const Text("Oblíbené"),
            selected: _onlyFavorites,
            onSelected: (val) => setState(() => _onlyFavorites = val),
          ),
        ],
      ),
      body: StreamBuilder<List<SongEntry>>(
        stream: widget.db.watchAllSongs(onlyFavorites: _onlyFavorites),
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
              return ListTile(
                leading: IconButton(
                  icon: Icon(
                    song.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: song.isFavorite ? Colors.red : null,
                  ),
                  onPressed: () => widget.db.toggleFavorite(song.id, !song.isFavorite),
                ),
                title: Text(song.artist),
                subtitle: Text(song.title),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlayerPage(songId: song.id, db: widget.db)),
                ),
                onLongPress: () => _editSong(song),
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
