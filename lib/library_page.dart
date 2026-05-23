import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart' show InsertMode;
import 'database.dart';
import 'song_entry.dart';
import 'playlists_page.dart';
import 'player_page.dart';
import 'song_utils.dart';

class LibraryPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const LibraryPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final FlutterTts _tts = FlutterTts();
  late AppDatabase _db;
  bool _onlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _db = AppDatabase();
    _tts.setLanguage("cs-CZ");
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
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
            onPressed: () {
              _db.updateSong(song.id, artistController.text, titleController.text);
              _tts.speak("Píseň upravena");
              Navigator.pop(context);
            },
            child: const Text("Uložit"),
          ),
        ],
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
            icon: const Icon(Icons.playlist_add),
            tooltip: "Spravovat playlisty",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PlaylistsPage(db: _db)),
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
        stream: _db.watchAllSongs(onlyFavorites: _onlyFavorites),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final songs = snapshot.data!;

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return Semantics(
                label: "${song.artist}, ${song.title}${song.isFavorite ? ', oblíbená' : ''}",
                button: true,
                child: ListTile(
                  leading: IconButton(
                    icon: Icon(song.isFavorite ? Icons.favorite : Icons.favorite_border),
                    tooltip: "Přepnout oblíbené",
                    onPressed: () => _db.toggleFavorite(song.id, !song.isFavorite),
                  ),
                  title: Text(song.artist),
                  subtitle: Text(song.title),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PlayerPage(songId: song.id, db: _db)),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanFolder,
        tooltip: "Vybrat složku s hudbou",
        child: const Icon(Icons.folder_open),
      ),
    );
  }

  Future<void> _scanFolder() async {
    String? path = await FilePicker.getDirectoryPath();
    if (path == null) return;

    final dir = Directory(path);
    final List<FileSystemEntity> files = dir.listSync(recursive: true);
    final txtFiles = files.where((f) => f is File && f.path.endsWith('.txt')).toList();
    final totalFiles = txtFiles.length;
    int processed = 0;

    if (totalFiles == 0) {
      _tts.speak("Nebyly nalezeny žádné textové soubory.");
      return;
    }

    void Function(void Function())? updateDialog;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setS) {
            updateDialog = setS;
            final progress = totalFiles > 0 ? processed / totalFiles : 0.0;
            return AlertDialog(
              title: const Text("Importuji soubory"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    semanticsLabel: "Importováno ${(progress * 100).toInt()} procent",
                  ),
                  const SizedBox(height: 10),
                  Text("$processed z $totalFiles souborů"),
                ],
              ),
            );
          },
        ),
      );
    }

    for (var entity in txtFiles) {
      if (entity is File) {
        try {
          final content = await entity.readAsString();
          final parsed = Song.parseImportedFileName(entity.path);

          await _db.into(_db.songs).insert(
            SongsCompanion.insert(
              filePath: entity.path,
              artist: parsed.artist ?? "Neznámý interpret",
              title: parsed.title,
            ),
            mode: InsertMode.insertOrIgnore,
          );
          processed++;
          
          if (updateDialog != null) {
            updateDialog!(() {});
            // Hlasová zpětná vazba po každých 20 %
            if (processed % (totalFiles / 5).ceil() == 0 || processed == totalFiles) {
              final percent = (processed / totalFiles * 100).toInt();
              _tts.speak("Importováno $percent procent.");
            }
          }
        } catch (e) {
          debugPrint("Chyba čtení souboru: $e");
        }
      }
    }

    if (context.mounted) Navigator.pop(context); // Zavřít dialog
    _tts.speak("Import dokončen. Načteno $processed souborů.");
  }

  }

