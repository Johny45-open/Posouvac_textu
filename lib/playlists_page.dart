import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:drift/drift.dart' show innerJoin;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import 'player_page.dart';
import 'app_strings.dart';
import 'song_export.dart';
import 'dev_log.dart';
import 'playlist_html_parser.dart';
import 'qr_scan_page.dart';

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

  Future<void> _showImportChoice() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Semantics(header: true, child: Text(AppStrings.playlistImportChoiceTitle)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'file'),
            child: ListTile(leading: const Icon(Icons.file_upload), title: Text(AppStrings.playlistImportFileLabel), subtitle: Text(AppStrings.playlistImportFileDescription)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'html'),
            child: ListTile(leading: const Icon(Icons.public), title: Text(AppStrings.playlistImportHtmlLabel), subtitle: Text(AppStrings.playlistImportHtmlDescription)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'clipboard'),
            child: ListTile(leading: const Icon(Icons.content_paste), title: Text(AppStrings.playlistImportClipboardLabel), subtitle: Text(AppStrings.playlistImportClipboardDescription)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'qr'),
            child: ListTile(leading: const Icon(Icons.qr_code_scanner), title: Text("QR kód"), subtitle: const Text("Naskenovat QR")),
          ),
        ],
      ),
    );

    if (choice == null) return;
    if (choice == 'file') _importFromFile();
    if (choice == 'html') _importFromHtmlFile();
    if (choice == 'clipboard') _importFromClipboard();
    if (choice == 'qr') {
        Navigator.push(context, MaterialPageRoute(builder: (context) => QrScanPage(db: widget.db)));
    }
  }

  Future<void> _importFromFile() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (files == null || files.isEmpty) return;
      final file = File(files.single.path!);
      final jsonString = await file.readAsString();
      await _importFromString(jsonString);
    } catch (e) {
      _announceError(AppStrings.playlistImportError);
    }
  }

  Future<void> _importFromHtmlFile() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['html', 'htm']);
      if (files == null || files.isEmpty) return;
      final file = File(files.single.path!);
      final htmlString = await file.readAsString();
      final data = parsePlaylistHtml(htmlString);
      await _importFromString(jsonEncode(data));
    } catch (e) {
      _announceError(AppStrings.playlistImportHtmlError);
    }
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) {
        _tts.speak(AppStrings.playlistImportClipboardEmpty);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.playlistImportClipboardEmpty)));
        return;
    }
    await _importFromString(data.text!);
  }

  Future<void> _importFromString(String raw) async {
    try {
      final decoded = jsonDecode(raw.startsWith('\uFEFF') ? raw.substring(1) : raw);
      final syncResult = await widget.db.syncPlaylistFromJson(decoded as Map<String, dynamic>);
      
      final hasTime = syncResult.totalDurationShared > 0 || syncResult.unknownShared > 0;
      final timeText = hasTime ? _formatImportTime(syncResult.totalDurationShared, syncResult.unknownShared) : null;
      final baseMessage = syncResult.notFound.isEmpty
          ? AppStrings.playlistImportSuccess(syncResult.playlistName, syncResult.matchedCount)
          : '${AppStrings.playlistImportSuccess(syncResult.playlistName, syncResult.matchedCount)} '
              '${AppStrings.playlistImportMissing(syncResult.notFound.length)}';
      final message = timeText != null ? '$baseMessage $timeText' : baseMessage;
      _tts.speak(message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        setState(() {});
        if (syncResult.durationCandidates.isNotEmpty || syncResult.diacriticCandidates.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) await _showFixDialog(syncResult);
        }
      }
    } catch (e) {
      _announceError(AppStrings.playlistImportError);
    }
  }

  void _announceError(String message) {
    _tts.speak(message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _formatImportTime(int totalSec, int unknown) {
    if (totalSec <= 0 && unknown == 0) return "";
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    final base = totalSec > 0 ? "Celkový čas: $m:${s.toString().padLeft(2, '0')}" : "Čas neurčen";
    if (unknown == 0) return base;
    return AppStrings.setlistTimeWithUnknown(base, unknown);
  }

  String _formatDurationShort(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  Future<void> _showFixDialog(PlaylistSyncResult result) async {
    final timeCount = result.durationCandidates.length;
    final diaCount = result.diacriticCandidates.length;
    final prefs = await SharedPreferences.getInstance();
    bool renameFiles = prefs.getBool('diacriticRenameFiles') ?? false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SimpleDialog(
          title: Semantics(header: true, child: Text(AppStrings.playlistFixDialogTitle)),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(AppStrings.playlistFixDialogContent(timeCount, diaCount)),
            ),
            if (timeCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Semantics(
                  header: true,
                  child: Text("Chybějící časy:", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            for (final c in result.durationCandidates.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                child: Text(AppStrings.playlistFixTimeItem(c.artist, c.title, _formatDurationShort(c.newDuration)),
                    style: const TextStyle(fontSize: 13)),
              ),
            if (timeCount > 5)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text("... a dalších ${timeCount - 5}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
            if (diaCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Semantics(
                  header: true,
                  child: Text("Oprava diakritiky:", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            for (final c in result.diacriticCandidates.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                child: Text(AppStrings.playlistFixDiaItem(c.oldArtist, c.oldTitle, c.newArtist, c.newTitle),
                    style: const TextStyle(fontSize: 13)),
              ),
            if (diaCount > 5)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text("... a dalších ${diaCount - 5}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
            if (diaCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Semantics(
                  label: renameFiles
                      ? "Přejmenovat i soubory na disku, zaškrtnuto"
                      : "Přejmenovat i soubory na disku, nezaškrtnuto",
                  child: CheckboxListTile(
                    title: const Text("Přejmenovat i soubory"),
                    subtitle: const Text("Na Windows může selhat, pokud je soubor otevřen"),
                    value: renameFiles,
                    onChanged: (v) {
                      setDialogState(() => renameFiles = v ?? false);
                      DevLog.log("Playlist fix checkbox renameFiles=$v");
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.playlistFixSkipLabel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.playlistFixConfirmLabel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    await prefs.setBool('diacriticRenameFiles', renameFiles);
    int fixedTime = 0;
    int fixedDia = 0;
    int renamed = 0;
    int failed = 0;
    if (timeCount > 0) fixedTime = await widget.db.applyMissingDurations(result.durationCandidates);
    if (diaCount > 0) {
      final res = await widget.db.applyDiacriticRepairs(result.diacriticCandidates, renameFiles: renameFiles);
      fixedDia = res.dbUpdated;
      renamed = res.filesRenamed;
      failed = res.filesFailed;
      if (failed > 0) DevLog.log("Playlist fix failed rename: ${res.failedPaths.join(', ')}");
    }
    final doneMsg = failed > 0
        ? "${AppStrings.playlistFixDone(fixedTime, fixedDia)} Př: $renamed, selhání: $failed."
        : AppStrings.playlistFixDone(fixedTime, fixedDia);
    _tts.speak(doneMsg);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(doneMsg)));
      setState(() {});
    }
  }

  Future<void> _sharePlaylist(Playlist playlist) async {
    try {
      final items = await widget.db.getPlaylistSongsWithTempo(playlist.id);
      if (items.isEmpty) {
        _tts.speak(AppStrings.playlistExportEmpty);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.playlistExportEmpty)));
        return;
      }
      int totalDuration = 0;
      int unknown = 0;
      for (final w in items) {
        final s = w.song;
        if (s.duration != null && s.duration! > 0) totalDuration += s.duration!;
        else unknown++;
      }
      final songsPayload = <Map<String, dynamic>>[];
      for (final w in items) {
        final marks = await widget.db.getStopMarksForSong(w.song.id);
        final entry = <String, dynamic>{
          'title': w.song.title,
          'artist': w.song.artist,
          'duration': w.song.duration,
          'tempo': w.playlistTempo ?? w.song.tempo,
          'filePath': w.song.filePath,
        };
        if (marks.isNotEmpty) {
          entry['stopMarks'] = [
            for (final m in marks)
              {
                if (m.lineText != null && m.lineText!.isNotEmpty) 'lineText': m.lineText,
                if (m.lineIndex != null) 'lineIndex': m.lineIndex,
                'bars': m.durationBars,
              }
          ];
        }
        songsPayload.add(entry);
      }
      if (!mounted) return;
      await showPlaylistShareDialog(context, playlistName: playlist.name, songs: songsPayload, totalDuration: totalDuration, unknownCount: unknown, db: widget.db, playlistId: playlist.id);
    } catch (e) {
      _tts.speak(AppStrings.shareError);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.shareError)));
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
        title: Semantics(header: true, child: Text("Nový setlist")),
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
        title: Semantics(header: true, child: Text("Spravovat setlist")),
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
              tooltip: "Importovat setlist",
              onPressed: _showImportChoice,
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
                      if (v == 'share') _sharePlaylist(pl);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'share', child: Text("Sdílet")),
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
        title: Semantics(header: true, child: Text(AppStrings.setlistUnlockConfirmTitle)),
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
        title: Semantics(header: true, child: Text("Přesunout ${song.title}")),
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
            title: Semantics(header: true, child: Text(AppStrings.bulkAddTitle)),
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
        title: Semantics(header: true, child: Text("Spustit setlist ${widget.playlist.name}?")),
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
          playlistId: widget.playlist.id,
        ),
      ),
    );
  }

  void _showSongOptions(SongEntry song, int index, int total) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text(song.title)),
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

  Future<void> _showTempoDialog(PlaylistSongWithTempo item) async {
    final hasOverride = item.playlistTempo != null;
    final initial = (item.playlistTempo ?? item.song.tempo)?.round().toString() ?? "";
    final controller = TextEditingController(text: initial);
    // Tap-tempo uvnitř dialogu setlistu – malé, bez duplikace celé logiky
    List<DateTime> tapTimes = [];
    String? error;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: Semantics(header: true, child: Text("Tempo pro ${item.song.title}")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Interpret: ${item.song.artist}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 8),
              if (hasOverride)
                Text("V setlistu: ${item.playlistTempo!.round()} BPM", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(item.song.tempo != null ? "Globálně: ${item.song.tempo!.round()} BPM" : "Globálně: nenastaveno", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "BPM v setlistu",
                  suffixText: "BPM",
                  helperText: "30 až 300, prázdné = použije globální",
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.maxFinite, 44), backgroundColor: Colors.blue.withOpacity(0.1)),
                onPressed: () {
                  final now = DateTime.now();
                  tapTimes.add(now);
                  if (tapTimes.length > 8) tapTimes.removeAt(0);
                  if (tapTimes.length >= 2) {
                    final intervals = <int>[];
                    for (int i = 1; i < tapTimes.length; i++) intervals.add(tapTimes[i].difference(tapTimes[i-1]).inMilliseconds);
                    final avg = intervals.reduce((a,b)=>a+b)/intervals.length;
                    final bpm = (60000/avg).round().clamp(30, 300);
                    setD(() { controller.text = bpm.toString(); error = null; });
                  }
                },
                icon: const Icon(Icons.touch_app),
                label: Text(AppStrings.tapTempoButton),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zrušit")),
            if (hasOverride)
              TextButton(
                onPressed: () async {
                  await widget.db.updatePlaylistSongTempo(widget.playlist.id, item.song.id, null);
                  tts.speak("Tempo pro ${item.song.title} nastaveno na globální");
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("Použít globální", style: TextStyle(color: Colors.orange)),
              ),
            FilledButton(
              onPressed: () async {
                final txt = controller.text.trim();
                if (txt.isEmpty) {
                  await widget.db.updatePlaylistSongTempo(widget.playlist.id, item.song.id, null);
                  tts.speak("Tempo pro ${item.song.title} nastaveno na globální");
                  if (mounted) Navigator.pop(context);
                  return;
                }
                final v = double.tryParse(txt);
                if (v == null || v < 30 || v > 300) {
                  setD(() => error = "Zadejte 30 až 300");
                  return;
                }
                await widget.db.updatePlaylistSongTempo(widget.playlist.id, item.song.id, v);
                tts.speak(AppStrings.bpmSetMessage(v.round()));
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Uložit"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareCurrentPlaylist(List<SongEntry> songs) async {
    if (songs.isEmpty) {
      tts.speak(AppStrings.playlistExportEmpty);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.playlistExportEmpty)));
      return;
    }
    int totalDuration = 0;
    int unknown = 0;
    for (final s in songs) {
      if (s.duration != null && s.duration! > 0) totalDuration += s.duration!;
      else unknown++;
    }
    final payload = songs.map((s) => {'title': s.title, 'artist': s.artist, 'duration': s.duration, 'filePath': s.filePath}).toList();
    await showPlaylistShareDialog(context, playlistName: widget.playlist.name, songs: payload, totalDuration: totalDuration, unknownCount: unknown, db: widget.db, playlistId: widget.playlist.id);
  }

  Future<void> _shareCurrentPlaylistWithTempo(List<PlaylistSongWithTempo> items) async {
    if (items.isEmpty) {
      tts.speak(AppStrings.playlistExportEmpty);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.playlistExportEmpty)));
      return;
    }
    int totalDuration = 0;
    int unknown = 0;
    for (final w in items) {
      final s = w.song;
      if (s.duration != null && s.duration! > 0) totalDuration += s.duration!;
      else unknown++;
    }
    final payload = <Map<String, dynamic>>[];
    for (final w in items) {
      final marks = await widget.db.getStopMarksForSong(w.song.id);
      final entry = <String, dynamic>{
        'title': w.song.title,
        'artist': w.song.artist,
        'duration': w.song.duration,
        'tempo': w.playlistTempo ?? w.song.tempo,
        'filePath': w.song.filePath,
      };
      if (marks.isNotEmpty) {
        entry['stopMarks'] = [
          for (final m in marks)
            {
              if (m.lineText != null && m.lineText!.isNotEmpty) 'lineText': m.lineText,
              if (m.lineIndex != null) 'lineIndex': m.lineIndex,
              'bars': m.durationBars,
            }
        ];
      }
      payload.add(entry);
    }
    await showPlaylistShareDialog(context, playlistName: widget.playlist.name, songs: payload, totalDuration: totalDuration, unknownCount: unknown, db: widget.db, playlistId: widget.playlist.id);
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
          StreamBuilder<List<PlaylistSongWithTempo>>(
            stream: widget.db.watchSongsWithTempoInPlaylist(widget.playlist.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              if (items.isEmpty) return const SizedBox();
              final songs = items.map((e) => e.song).toList();
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
          StreamBuilder<List<PlaylistSongWithTempo>>(
            stream: widget.db.watchSongsWithTempoInPlaylist(widget.playlist.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              if (items.isEmpty) return const SizedBox();
              final totalSec = items.fold<int>(0, (sum, w) => sum + (w.song.duration ?? 0));
              final unknown = items.where((w) => w.song.duration == null || w.song.duration == 0).length;
              final timeText = _formatTotalTimeWithUnknown(totalSec, unknown);
              return Semantics(
                label: "Sdílet setlist ${widget.playlist.name}, ${items.length} písní, $timeText",
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: "Sdílet setlist",
                  onPressed: () => _shareCurrentPlaylistWithTempo(items),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.library_add),
            tooltip: "Přidat více písní do setlistu",
            onPressed: () => _showBulkAddDialog(context),
          ),
          StreamBuilder<List<PlaylistSongWithTempo>>(
            stream: widget.db.watchSongsWithTempoInPlaylist(widget.playlist.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              if (!snapshot.hasData || items.isEmpty) return const SizedBox();
              final count = items.length;
              final totalSec = items.fold<int>(0, (sum, w) => sum + (w.song.duration ?? 0));
              final unknown = items.where((w) => w.song.duration == null || w.song.duration == 0).length;
              final timeText = _formatTotalTimeWithUnknown(totalSec, unknown);
              final songs = items.map((e) => e.song).toList();
              return Semantics(
                label: "Spustit setlist ${widget.playlist.name}, $count písní, $timeText",
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                  tooltip: "Spustit setlist",
                  onPressed: () => _confirmStartSetlist(songs),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PlaylistSongWithTempo>>(
        stream: widget.db.watchSongsWithTempoInPlaylist(widget.playlist.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(semanticsLabel: "Načítám písně setlistu"));
          final items = snapshot.data!;

          if (items.isEmpty) {
            return Semantics(
              liveRegion: true,
              label: "V tomto setlistu nejsou žádné písně. Přidejte je tlačítkem vpravo nahoře.",
              child: const Center(child: Text("V tomto setlistu nejsou žádné písně.")),
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final song = item.song;
              final effectiveTempo = item.playlistTempo ?? song.tempo;
              final hasOverride = item.playlistTempo != null;
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
              String tempoText = "";
              String tempoSemantics = "";
              if (effectiveTempo != null) {
                tempoText = " • ${effectiveTempo.round()} BPM${hasOverride ? "" : " (glob.)"}";
                tempoSemantics = ". Tempo ${effectiveTempo.round()} BPM${hasOverride ? " nastaveno pro setlist" : " globální"}";
              } else {
                tempoText = " • bez tempa";
                tempoSemantics = ". Tempo nenastaveno, klepněte na tempo pro nastavení";
              }

              return Semantics(
                label: "Píseň ${i + 1} z ${items.length}: ${song.artist}, ${song.title}$durationSemantics$tempoSemantics. Poklepáním přehrajete, menu vpravo pro možnosti.",
                button: true,
                child: ListTile(
                  leading: isUnknown ? const Icon(Icons.timer_off, size: 20, color: Colors.orange) : null,
                  title: Text("${song.artist}$durationText"),
                  subtitle: InkWell(
                    onTap: () => _showTempoDialog(item),
                    child: Text(
                      song.title + (isUnknown ? " • ${AppStrings.songDurationUnknown} • ${AppStrings.songDurationEstimateHint(3)}" : "") + tempoText,
                      style: TextStyle(color: hasOverride ? Theme.of(context).colorScheme.primary : null, fontWeight: hasOverride ? FontWeight.w600 : null),
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PlayerPage(songId: song.id, db: widget.db, playlistId: widget.playlist.id)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tempo rychlá akce
                      Semantics(
                        label: effectiveTempo != null ? "Tempo ${effectiveTempo.round()} BPM, klepnutím upravit" : "Nastavit tempo pro ${song.title}",
                        button: true,
                        child: InkWell(
                          onTap: () => _showTempoDialog(item),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasOverride ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: hasOverride ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.speed, size: 16, color: hasOverride ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.grey[700]),
                                const SizedBox(width: 4),
                                Text(effectiveTempo != null ? "${effectiveTempo.round()}" : "—", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: hasOverride ? Theme.of(context).colorScheme.onPrimaryContainer : null)),
                              ],
                            ),
                          ),
                        ),
                      ),
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
                      if (_reorderUnlocked && i < items.length - 1)
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
                          if (v == 'tempo') {
                            _showTempoDialog(item);
                          } else if (v == 'remove') {
                            widget.db.removeSongFromPlaylist(widget.playlist.id, song.id);
                            tts.speak(AppStrings.songRemovedFromPlaylist(song.title));
                          } else if (v == 'move') {
                            _showMoveDialog(song, i, items.length);
                          } else if (v == 'options') {
                            _showSongOptions(song, i, items.length);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'tempo', child: Text("Nastavit tempo...")),
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