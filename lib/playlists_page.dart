import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:drift/drift.dart' show innerJoin;
import 'package:file_picker/file_picker.dart';
import 'database.dart';
import 'player_page.dart';
import 'app_strings.dart';

class PlaylistsPage extends StatefulWidget {
  final AppDatabase db;
  const PlaylistsPage({super.key, required this.db});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);
  }

  Future<void> _importPlaylist() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      await widget.db.syncPlaylistFromJson(data);
      _tts.speak("Playlist importován");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playlist importován")));
        setState(() {});
      }
    }
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nový playlist"),
        content: TextField(
          controller: controller, 
          decoration: const InputDecoration(
            labelText: "Název playlistu",
            hintText: "Např. Oslava",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zrušit")),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await widget.db.createPlaylist(controller.text);
                _tts.speak(AppStrings.playlistCreated(controller.text));
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              }
            },
            child: const Text("Vytvořit"),
          ),
        ],
      ),
    );
  }

  Future<void> _managePlaylist(Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Spravovat playlist"),
        content: TextFormField(
          controller: controller, 
          decoration: const InputDecoration(
            labelText: "Upravit název",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await widget.db.deletePlaylist(playlist.id);
              _tts.speak(AppStrings.playlistDeleted(playlist.name));
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text("Smazat", style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zavřít")),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await widget.db.renamePlaylist(playlist.id, controller.text);
                _tts.speak(AppStrings.playlistRenamed(playlist.name, controller.text));
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              }
            },
            child: const Text("Přejmenovat"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Moje playlisty"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: "Importovat playlist ze souboru",
            onPressed: _importPlaylist,
          ),
        ],
      ),
      body: FutureBuilder<List<Playlist>>(
        future: widget.db.getAllPlaylists(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();

          final playlists = snapshot.data!;
          if (playlists.isEmpty) {
            return const Center(child: Text("Zatím nemáte žádné playlisty."));
          }

          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, i) {
              final pl = playlists[i];
              return Semantics(
                label: "Playlist: ${pl.name}. Dlouhým stisknutím playlist upravíte.",
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(pl.name),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PlaylistSongsPage(playlist: pl, db: widget.db)),
                  ),
                  onLongPress: () => _managePlaylist(pl),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPlaylist,
        tooltip: "Vytvořit nový playlist",
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PlaylistSongsPage extends StatelessWidget {
  final Playlist playlist;
  final AppDatabase db;

  const PlaylistSongsPage({super.key, required this.playlist, required this.db});

  String _formatTotalTime(int totalSeconds) {
    if (totalSeconds == 0) return "Čas neurčen";
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return "Celkový čas: $minutes min ${seconds > 0 ? '$seconds s' : ''}";
    }
    return "Celkový čas: $seconds s";
  }

  Future<void> _showBulkAddDialog(BuildContext context) async {
    final allSongs = await db.getAllSongs();
    final existingSongs = await (db.select(db.songs).join([innerJoin(db.playlistSongs, db.playlistSongs.songId.equalsExp(db.songs.id))])
      ..where(db.playlistSongs.playlistId.equals(playlist.id))).get();
    final existingIds = existingSongs.map((row) => row.readTable(db.songs).id).toSet();
    
    // Filtrujeme pouze ty, které v playlistu ještě nejsou
    final availableSongs = allSongs.where((s) => !existingIds.contains(s.id)).toList();
    
    if (availableSongs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Všechny písně z knihovny již v playlistu jsou.")));
      }
      return;
    }

    final selectedIds = <int>{};
    final FlutterTts tts = FlutterTts();
    tts.setLanguage("cs-CZ");

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppStrings.bulkAddTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableSongs.length,
              itemBuilder: (context, i) {
                final song = availableSongs[i];
                final isSelected = selectedIds.contains(song.id);
                return CheckboxListTile(
                  title: Text(song.artist),
                  subtitle: Text(song.title),
                  value: isSelected,
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) selectedIds.add(song.id);
                      else selectedIds.remove(song.id);
                    });
                    tts.speak(val == true ? "Vybráno: ${song.title}" : "Odebráno z výběru: ${song.title}");
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zrušit")),
            TextButton(
              onPressed: selectedIds.isEmpty ? null : () async {
                await db.addSongsToPlaylist(playlist.id, selectedIds.toList());
                tts.speak(AppStrings.bulkAddFinished(selectedIds.length));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Přidat vybrané"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FlutterTts tts = FlutterTts();
    tts.setLanguage("cs-CZ");
    tts.setSpeechRate(0.5);

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<SongEntry>>(
          stream: db.watchSongsInPlaylist(playlist.id),
          builder: (context, snapshot) {
            final String baseTitle = "Playlist: ${playlist.name}";
            if (!snapshot.hasData || snapshot.data!.isEmpty) return Text(baseTitle);
            
            final totalSec = snapshot.data!.fold<int>(0, (sum, s) => sum + (s.duration ?? 0));
            final timeText = _formatTotalTime(totalSec);

            return Semantics(
              label: "$baseTitle. ${snapshot.data!.length} skladeb. $timeText.",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baseTitle, style: const TextStyle(fontSize: 16)),
                  Text(
                    timeText,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_add),
            tooltip: "Přidat více písní",
            onPressed: () => _showBulkAddDialog(context),
          ),
          StreamBuilder<List<SongEntry>>(
            stream: db.watchSongsInPlaylist(playlist.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
              return IconButton(
                icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                tooltip: "Spustit Setlist",
                onPressed: () {
                  final ids = snapshot.data!.map((s) => s.id).toList();
                  tts.speak(AppStrings.startSetlistMessage(playlist.name, snapshot.data!.first.title));
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerPage(
                        songId: ids.first,
                        db: db,
                        setlistIds: ids,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<SongEntry>>(
        stream: db.watchSongsInPlaylist(playlist.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final songs = snapshot.data!;

          if (songs.isEmpty) {
            return const Center(child: Text("V tomto playlistu nejsou žádné písně."));
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final song = songs[i];
              String durationText = "";
              String durationSemantics = "";
              if (song.duration != null && song.duration! > 0) {
                final m = song.duration! ~/ 60;
                final s = song.duration! % 60;
                durationText = " [${m}:${s.toString().padLeft(2, '0')}]";
                durationSemantics = ". Délka $m minut a $s sekund.";
              }

              return Semantics(
                label: "Píseň ${i + 1} v pořadí: ${song.artist}, ${song.title}$durationSemantics",
                child: ListTile(
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (i > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: "Posunout ${song.title} nahoru",
                          onPressed: () async {
                            await db.reorderPlaylistSongs(playlist.id, song.id, true);
                            tts.speak("Píseň ${song.title} posunuta na ${i}. místo");
                          },
                        ),
                      if (i < songs.length - 1)
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: "Posunout ${song.title} dolů",
                          onPressed: () async {
                            await db.reorderPlaylistSongs(playlist.id, song.id, false);
                            tts.speak("Píseň ${song.title} posunuta na ${i + 2}. místo");
                          },
                        ),
                    ],
                  ),
                  title: Text("${song.artist}$durationText"),
                  subtitle: Text(song.title),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: "Odebrat skladbu ${song.title} z playlistu",
                    onPressed: () async {
                      await db.removeSongFromPlaylist(playlist.id, song.id);
                      tts.speak(AppStrings.songRemovedFromPlaylist(song.title));
                    },
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PlayerPage(songId: song.id, db: db)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
