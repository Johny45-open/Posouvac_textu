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
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final syncResult = await widget.db.syncPlaylistFromJson(data);
      final message = syncResult.notFound.isEmpty
          ? AppStrings.playlistImportSuccess(syncResult.playlistName, syncResult.matchedCount)
          : '${AppStrings.playlistImportSuccess(syncResult.playlistName, syncResult.matchedCount)} '
              '${AppStrings.playlistImportMissing(syncResult.notFound.length)}';
      _tts.speak(message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        setState(() {});
      }
    } catch (e) {
      _tts.speak(AppStrings.playlistImportError);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppStrings.playlistImportError)));
      }
    }
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    // Po otevření dialogu přesunout fokus do TextField pro TalkBack/NVDA
    WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nový setlist"),
        content: TextField(
          controller: controller, 
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: "Název setlistu",
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
    focusNode.dispose();
  }

  Future<void> _managePlaylist(Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    final focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Spravovat setlist"),
        content: TextFormField(
          controller: controller, 
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: "Upravit název",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
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
    focusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Moje setlisty"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: "Importovat setlist ze souboru",
            onPressed: _importPlaylist,
          ),
        ],
      ),
      body: FutureBuilder<List<Playlist>>(
        future: widget.db.getAllPlaylists(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(semanticsLabel: "Načítám setlisty"));

          final playlists = snapshot.data!;
          if (playlists.isEmpty) {
            return Semantics(
              liveRegion: true,
              label: "Zatím nemáte žádné setlisty. Vytvořte nový tlačítkem vpravo dole.",
              child: const Center(child: Text("Zatím nemáte žádné setlisty.")),
            );
          }

          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, i) {
              final pl = playlists[i];
              return Semantics(
                label: "Setlist: ${pl.name}. Poklepáním otevřete, menu vpravo pro úpravy.",
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(pl.name),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PlaylistSongsPage(playlist: pl, db: widget.db)),
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: "Možnosti setlistu ${pl.name}",
                    onSelected: (v) async {
                      if (v == 'manage') _managePlaylist(pl);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'manage', child: Text("Spravovat")),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPlaylist,
        tooltip: "Vytvořit nový setlist",
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PlaylistSongsPage extends StatefulWidget {
  final Playlist playlist;
  final AppDatabase db;

  const PlaylistSongsPage({super.key, required this.playlist, required this.db});

  @override
  State<PlaylistSongsPage> createState() => _PlaylistSongsPageState();
}

class _PlaylistSongsPageState extends State<PlaylistSongsPage> {
  final FlutterTts tts = FlutterTts();
  bool _reorderUnlocked = false; // hybrid zámek 3) defaultně zamknuto

  @override
  void initState() {
    super.initState();
    tts.setLanguage("cs-CZ");
    tts.setSpeechRate(0.5);
  }

  String _formatTotalTime(int totalSeconds) {
    if (totalSeconds <= 0) return "Čas neurčen";
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    
    String minStr = minutes > 0 ? "$minutes min" : "";
    String secStr = seconds > 0 ? "$seconds s" : "";
    
    return "Celkový čas: ${minStr.isNotEmpty ? '$minStr ' : ''}$secStr".trim();
  }

  String _formatTotalTimeWithUnknown(int totalSeconds, int unknownCount) {
    final base = _formatTotalTime(totalSeconds);
    if (unknownCount == 0) return base;
    // hybrid 1) ukázat známý čas + hint odhadu, ne přičítat do celku
    return AppStrings.setlistTimeWithUnknown(base, unknownCount);
  }

  Future<void> _readSetlistOrder(List<SongEntry> songs) async {
    if (songs.isEmpty) {
      tts.speak("Setlist je prázdný");
      return;
    }
    final titles = songs.asMap().entries.map((e) => "${e.key + 1}. ${e.value.artist} - ${e.value.title}").toList();
    final announcement = AppStrings.setlistReadOrderAnnouncement(titles);
    tts.speak(announcement);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Přehrávám pořadí ${songs.length} písní"), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _toggleReorderLock() async {
    if (_reorderUnlocked) {
      setState(() => _reorderUnlocked = false);
      tts.speak(AppStrings.setlistReorderLockedAnnouncement);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.setlistReorderLockedAnnouncement)));
      }
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.setlistUnlockConfirmTitle),
        content: Text(AppStrings.setlistUnlockConfirmContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Zrušit")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Odemknout")),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _reorderUnlocked = true);
      tts.speak(AppStrings.setlistReorderUnlockedAnnouncement);
    }
  }

  Future<void> _showMoveDialog(SongEntry song, int currentIndex, int totalSongs) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Přesunout ${song.title}"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: "Nová pozice (1 - $totalSongs)"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zrušit")),
          TextButton(
            onPressed: () async {
              final newPos = int.tryParse(controller.text);
              if (newPos != null && newPos >= 1 && newPos <= totalSongs) {
                await widget.db.movePlaylistSong(widget.playlist.id, song.id, newPos - 1);
                tts.speak("Píseň ${song.title} přesunuta na ${newPos}. místo");
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Přesunout"),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkAddDialog(BuildContext context) async {
    final allSongs = await widget.db.getAllSongs();
    final existingSongs = await widget.db.watchSongsInPlaylist(widget.playlist.id).first;
    final existingIds = existingSongs.map((song) => song.id).toSet();
    
    // Filtrujeme pouze ty, které v playlistu ještě nejsou
    final availableSongs = allSongs.where((s) => !existingIds.contains(s.id)).toList();
    
    if (availableSongs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Všechny písně z knihovny již v playlistu jsou.")));
      }
      return;
    }

    final selectedIds = <int>{};
    String filter = "";
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = filter.isEmpty
              ? availableSongs
              : availableSongs.where((s) =>
                  s.title.toLowerCase().contains(filter.toLowerCase()) ||
                  s.artist.toLowerCase().contains(filter.toLowerCase())).toList();
          return AlertDialog(
            title: Text(AppStrings.bulkAddTitle),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Hledat podle názvu nebo interpreta",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setDialogState(() => filter = v),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    label: "Vybráno ${selectedIds.length} z ${filtered.length} zobrazených, celkem ${availableSongs.length} dostupných",
                    child: Text(
                      "Vybráno: ${selectedIds.length} | Zobrazeno: ${filtered.length}/${availableSongs.length}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.select_all),
                    label: Text(filtered.every((s) => selectedIds.contains(s.id)) ? "Odebrat vše zobrazené" : "Vybrat vše zobrazené"),
                    onPressed: () {
                      setDialogState(() {
                        final allSelected = filtered.every((s) => selectedIds.contains(s.id));
                        if (allSelected) {
                          for (final s in filtered) selectedIds.remove(s.id);
                          tts.speak("Odebráno z výběru ${filtered.length} písní");
                        } else {
                          for (final s in filtered) selectedIds.add(s.id);
                          tts.speak("Vybráno ${filtered.length} písní");
                        }
                      });
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text("Žádné písně nevyhovují filtru"))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final song = filtered[i];
                              final isSelected = selectedIds.contains(song.id);
                              return Semantics(
                                label: "Vybrat ${song.title} od ${song.artist}",
                                child: CheckboxListTile(
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
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zrušit")),
              TextButton(
                onPressed: selectedIds.isEmpty ? null : () async {
                  await widget.db.addSongsToPlaylist(widget.playlist.id, selectedIds.toList());
                tts.speak(AppStrings.bulkAddFinished(selectedIds.length));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Přidat vybrané"),
            ),
          ],
        );
        },
      ),
    );
  }

  Future<void> _confirmStartSetlist(List<SongEntry> songs) async {
    final totalSec = songs.fold<int>(0, (sum, s) => sum + (s.duration ?? 0));
    final unknown = songs.where((s) => s.duration == null || s.duration == 0).length;
    final timeText = _formatTotalTimeWithUnknown(totalSec, unknown);
    final first = songs.first;
    final last = songs.last;
    // Stručné shrnutí pro rychlý start + možnost přečíst celé pořadí
    final shortSummary = "${songs.length} písní, $timeText. První: ${first.artist} - ${first.title}, poslední: ${last.title}.";
    final confirm = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Spustit setlist ${widget.playlist.name}?"),
        content: Semantics(
          liveRegion: true,
          child: Text(shortSummary + (unknown > 0 ? "\n${AppStrings.setlistUnknownAnnouncement(unknown)}" : "")),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text("Zrušit")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context, 'read');
              // Po zavření dialogu přečíst celé pořadí
              await Future.delayed(const Duration(milliseconds: 300));
              _readSetlistOrder(songs);
            },
            child: Text(AppStrings.setlistReadOrderLabel),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, 'start'), child: const Text("Spustit")),
        ],
      ),
    );
    if (confirm == 'read') return; // už přečteno, uživatel může znovu dát Spustit
    if (confirm != 'start') return;
    final ids = songs.map((s) => s.id).toList();
    tts.speak(AppStrings.startSetlistMessage(widget.playlist.name, first.title));
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          songId: ids.first,
          db: widget.db,
          setlistIds: ids,
        ),
      ),
    );
  }

  void _showSongOptions(SongEntry song, int index, int total) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(song.title),
        content: Text("${song.artist} - položka ${index + 1} z $total"),
        actions: [
          TextButton(
            onPressed: () async {
              await widget.db.removeSongFromPlaylist(widget.playlist.id, song.id);
              tts.speak(AppStrings.songRemovedFromPlaylist(song.title));
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Odebrat", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showMoveDialog(song, index, total);
            },
            child: const Text("Přesunout"),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zavřít")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<SongEntry>>(
          stream: widget.db.watchSongsInPlaylist(widget.playlist.id),
          builder: (context, snapshot) {
            final String baseTitle = "Setlist: ${widget.playlist.name}";
            if (!snapshot.hasData || snapshot.data!.isEmpty) return Text(baseTitle);
            
            final totalSec = snapshot.data!.fold<int>(0, (sum, s) => sum + (s.duration ?? 0));
            final unknown = snapshot.data!.where((s) => s.duration == null || s.duration == 0).length;
            final timeText = _formatTotalTimeWithUnknown(totalSec, unknown);
            final semanticsTime = unknown == 0 ? timeText : "$timeText. ${AppStrings.setlistUnknownAnnouncement(unknown)}";

            return Semantics(
              liveRegion: true,
              label: "$baseTitle. ${snapshot.data!.length} skladeb. $semanticsTime.",
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
          // Hybrid 2) samostatné tlačítko Přečíst pořadí
          StreamBuilder<List<SongEntry>>(
            stream: widget.db.watchSongsInPlaylist(widget.playlist.id),
            builder: (context, snapshot) {
              final songs = snapshot.data ?? const [];
              if (songs.isEmpty) return const SizedBox();
              return Semantics(
                label: AppStrings.setlistReadOrderTooltip,
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.hearing),
                  tooltip: AppStrings.setlistReadOrderTooltip,
                  onPressed: () => _readSetlistOrder(songs),
                ),
              );
            },
          ),
          // Hybrid 3) zámek přesouvání
          Semantics(
            label: _reorderUnlocked ? AppStrings.setlistLockReorderLabel : AppStrings.setlistUnlockReorderLabel,
            button: true,
            child: IconButton(
              icon: Icon(_reorderUnlocked ? Icons.lock_open : Icons.lock, color: _reorderUnlocked ? Colors.orange : null),
              tooltip: _reorderUnlocked ? AppStrings.setlistLockReorderLabel : AppStrings.setlistUnlockReorderLabel,
              onPressed: _toggleReorderLock,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.library_add),
            tooltip: "Přidat více písní do setlistu",
            onPressed: () => _showBulkAddDialog(context),
          ),
          StreamBuilder<List<SongEntry>>(
            stream: widget.db.watchSongsInPlaylist(widget.playlist.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
              final count = snapshot.data!.length;
              final totalSec = snapshot.data!.fold<int>(0, (sum, s) => sum + (s.duration ?? 0));
              final unknown = snapshot.data!.where((s) => s.duration == null || s.duration == 0).length;
              final timeText = _formatTotalTimeWithUnknown(totalSec, unknown);
              return Semantics(
                label: "Spustit setlist ${widget.playlist.name}, $count písní, $timeText",
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                  tooltip: "Spustit setlist",
                  onPressed: () => _confirmStartSetlist(snapshot.data!),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<SongEntry>>(
        stream: widget.db.watchSongsInPlaylist(widget.playlist.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(semanticsLabel: "Načítám písně setlistu"));
          final songs = snapshot.data!;

          if (songs.isEmpty) {
            return Semantics(
              liveRegion: true,
              label: "V tomto setlistu nejsou žádné písně. Přidejte je tlačítkem vpravo nahoře.",
              child: const Center(child: Text("V tomto setlistu nejsou žádné písně.")),
            );
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final song = songs[i];
              String durationText = "";
              String durationSemantics = "";
              bool isUnknown = song.duration == null || song.duration == 0;
              if (!isUnknown) {
                final m = song.duration! ~/ 60;
                final s = song.duration! % 60;
                durationText = " [${m}:${s.toString().padLeft(2, '0')}]";
                durationSemantics = ". Délka $m minut a $s sekund.";
              } else {
                durationText = " [?]";
                durationSemantics = ". ${AppStrings.songDurationUnknownSemantics(song.title)}. ${AppStrings.songDurationEstimateHint(3)}.";
              }

              return Semantics(
                label: "Píseň ${i + 1} z ${songs.length}: ${song.artist}, ${song.title}$durationSemantics. Poklepáním přehrajete, menu vpravo pro možnosti.",
                button: true,
                child: ListTile(
                  leading: isUnknown ? const Icon(Icons.timer_off, size: 20, color: Colors.orange) : null,
                  title: Text("${song.artist}$durationText"),
                  subtitle: Text(song.title + (isUnknown ? " • ${AppStrings.songDurationUnknown} • ${AppStrings.songDurationEstimateHint(3)}" : "")),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PlayerPage(songId: song.id, db: widget.db)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hybrid 3) šipky jen když odemknuto, jinak jen menu (bezpečné na pódiu)
                      if (_reorderUnlocked && i > 0)
                        Semantics(
                          label: "Přesunout ${song.title} o jedno výše",
                          button: true,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 20),
                            tooltip: "Posunout výše",
                            onPressed: () async {
                              await widget.db.reorderPlaylistSongs(widget.playlist.id, song.id, true);
                              tts.speak("Přesunuto výše: ${song.title}");
                            },
                          ),
                        ),
                      if (_reorderUnlocked && i < songs.length - 1)
                        Semantics(
                          label: "Přesunout ${song.title} o jedno níže",
                          button: true,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 20),
                            tooltip: "Posunout níže",
                            onPressed: () async {
                              await widget.db.reorderPlaylistSongs(widget.playlist.id, song.id, false);
                              tts.speak("Přesunuto níže: ${song.title}");
                            },
                          ),
                        ),
                      PopupMenuButton<String>(
                        tooltip: "Možnosti písně ${song.title}",
                        onSelected: (v) {
                          if (v == 'remove') {
                            widget.db.removeSongFromPlaylist(widget.playlist.id, song.id);
                            tts.speak(AppStrings.songRemovedFromPlaylist(song.title));
                          } else if (v == 'move') {
                            _showMoveDialog(song, i, songs.length);
                          } else if (v == 'options') {
                            _showSongOptions(song, i, songs.length);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'move', child: Text("Přesunout na pozici...")),
                          PopupMenuItem(value: 'remove', child: Text("Odebrat ze setlistu")),
                        ],
                      ),
                    ],
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
