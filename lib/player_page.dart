import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:drift/drift.dart' show Value;
import 'database.dart';
import 'song_entry.dart';
import 'chord_display_widget.dart';
import 'app_progress_indicator.dart';
import 'app_strings.dart';

class PlayerPage extends StatefulWidget {
  final int songId;
  final AppDatabase db;
  final List<int>? setlistIds;

  const PlayerPage({super.key, required this.songId, required this.db, this.setlistIds});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();
  Timer? _scrollTimer;
  bool _isScrolling = false;
  
  late SongEntry _song;
  bool _isLoading = true;
  String? _loadedContent;
  
  double _fontSize = 20.0;
  double _scrollMultiplier = 1.0;
  double? _bpm;
  double? _introDuration;
  int _countdown = 0;
  List<StopMark> _stopMarks = [];
  bool _isPausedAtStop = false;

  Future<void> _saveSettings() async {
    await widget.db.updateSongSettings(widget.songId, _bpm, _introDuration, _fontSize, _scrollMultiplier);
  }

  void _startWithCountdown() async {
    setState(() => _isScrolling = true);
    
    if (_introDuration != null && _introDuration! > 0) {
      _tts.speak(AppStrings.introMessage(_introDuration!.round()));
      await Future.delayed(Duration(seconds: _introDuration!.round()));
    }

    if (!mounted || !_isScrolling) return;

    for (int i = 3; i > 0; i--) {
      if (!mounted || !_isScrolling) return;
      setState(() => _countdown = i);
      _tts.speak("$i");
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted || !_isScrolling) return;
    setState(() => _countdown = 0);
    _startScrolling();
  }

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);
    _loadSongData();
  }

  Future<void> _loadSongData() async {
    try {
      _song = await (widget.db.select(widget.db.songs)..where((s) => s.id.equals(widget.songId))).getSingle();
      _stopMarks = await widget.db.getStopMarksForSong(widget.songId);

      setState(() {
        _fontSize = _song.customFontSize ?? 20.0;
        _bpm = _song.tempo;
        _introDuration = _song.introDuration;
      });

      _scrollMultiplier = _song.customScrollSpeed ?? 1.0;

      final file = File(_song.filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        String content;
        try {
          content = utf8.decode(bytes);
        } catch (_) {
          content = latin1.decode(bytes);
        }
        if (mounted) {
          setState(() {
            _loadedContent = content;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _loadedContent = "Soubor nenalezen"; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _loadedContent = "Chyba: $e"; _isLoading = false; });
    }
  }

  Future<void> _manageStopMarks() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Správa pauz"),
          content: _stopMarks.isEmpty 
            ? const Text("Tato píseň nemá žádné nastavené pauzy.")
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _stopMarks.length,
                  itemBuilder: (context, i) {
                    final mark = _stopMarks[i];
                    return Semantics(
                      label: "Pauza na ${mark.durationBars} takty, umístěna v ${(mark.positionRatio * 100).round()} procentech textu.",
                      child: ListTile(
                        leading: const Icon(Icons.pause_circle_filled),
                        title: Text("Pauza na ${mark.durationBars} takty"),
                        subtitle: Text("Pozice: ${(mark.positionRatio * 100).round()}% textu"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: "Smazat tuto pauzu na ${mark.durationBars} takty",
                          onPressed: () async {
                            await widget.db.deleteStopMark(mark.id);
                            final newMarks = await widget.db.getStopMarksForSong(widget.songId);
                            setState(() => _stopMarks = newMarks);
                            setDialogState(() {});
                            _tts.speak("Pauza smazána");
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zavřít")),
          ],
        ),
      ),
    );
  }

  Future<void> _addStopMark() async {
    final barsController = TextEditingController(text: "2");
    final ratio = _scrollController.offset / _scrollController.position.maxScrollExtent;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Přidat pauzu"),
        content: TextField(
          controller: barsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Délka pauzy v taktech"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zrušit")),
          TextButton(
            onPressed: () async {
              final bars = int.tryParse(barsController.text) ?? 2;
              await widget.db.addStopMark(_song.id, ratio, bars);
              _stopMarks = await widget.db.getStopMarksForSong(_song.id);
              Navigator.pop(context);
              _tts.speak("Pauza přidána");
            },
            child: const Text("Uložit"),
          ),
        ],
      ),
    );
  }

  Future<void> _quickAddStopMark() async {
    final ratio = _scrollController.offset / _scrollController.position.maxScrollExtent;
    await widget.db.addStopMark(_song.id, ratio, 2); // Výchozí 2 takty
    _stopMarks = await widget.db.getStopMarksForSong(_song.id);
    _tts.speak(AppStrings.stopMarkQuickAdded);
  }

  void _startScrolling() {
    _scrollTimer?.cancel();
    
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        if (_isPausedAtStop) return;

        final double pixelsPerBeat = (_fontSize * 1.5) / 4.0;
        final double beatsPerSecond = (_bpm ?? 120) / 60.0;
        final double pixelsPerSecond = pixelsPerBeat * beatsPerSecond;
        final double scrollStep = (pixelsPerSecond / 20.0) * _scrollMultiplier;

        final newOffset = _scrollController.offset + scrollStep;
        final maxExtent = _scrollController.position.maxScrollExtent;

        // Kontrola zarážek
        final currentRatio = newOffset / maxExtent;
        for (final mark in _stopMarks) {
          if (currentRatio >= mark.positionRatio && currentRatio < mark.positionRatio + 0.02) {
            _handleStopMark(mark);
            return;
          }
        }

        if (newOffset < maxExtent) {
          _scrollController.jumpTo(newOffset);
        } else {
          _stopScrolling();
        }
      }
    });
  }

  Future<void> _handleStopMark(StopMark mark) async {
    _isPausedAtStop = true;
    _stopScrolling();
    _tts.speak(AppStrings.stopMarkMessage(mark.durationBars));
    
    final duration = Duration(milliseconds: ((60000 / (_bpm ?? 120)) * mark.durationBars * 4).round());
    await Future.delayed(duration);
    
    if (mounted && _isScrolling) {
      _isPausedAtStop = false;
      _startScrolling();
    } else {
      _isPausedAtStop = false;
    }
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    setState(() {
      _isScrolling = false;
      _countdown = 0;
    });

    // Pokud jsme v režimu Setlist a došli jsme na konec, nabídneme další píseň
    if (widget.setlistIds != null && _scrollController.offset >= _scrollController.position.maxScrollExtent - 10) {
      _handleNextInSetlist();
    }
  }

  Future<void> _handleNextInSetlist() async {
    final currentIndex = widget.setlistIds!.indexOf(widget.songId);
    if (currentIndex != -1 && currentIndex < widget.setlistIds!.length - 1) {
      final nextSongId = widget.setlistIds![currentIndex + 1];
      final nextSong = await (widget.db.select(widget.db.songs)..where((s) => s.id.equals(nextSongId))).getSingle();
      
      if (mounted) {
        _tts.speak(AppStrings.nextSongMessage(nextSong.title, nextSong.artist));
        
        // Krátká pauza na vydýchání
        await Future.delayed(const Duration(seconds: 3));
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerPage(
                songId: nextSongId,
                db: widget.db,
                setlistIds: widget.setlistIds,
              ),
            ),
          );
        }
      }
    } else {
      _tts.speak(AppStrings.setlistEndMessage);
    }
  }

  void _toggleScrolling() {
    if (_isScrolling || _countdown > 0) {
      _stopScrolling();
    } else {
      _startWithCountdown();
    }
  }

  Future<void> _showBpmDialog() async {
    final controller = TextEditingController(text: _bpm?.round().toString() ?? "120");
    List<DateTime> tapTimes = [];
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppStrings.bpmDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Zadejte číslo nebo klepejte níže",
                  suffixText: "BPM",
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.maxFinite, 60),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                ),
                onPressed: () {
                  final now = DateTime.now();
                  tapTimes.add(now);
                  if (tapTimes.length > 8) tapTimes.removeAt(0);
                  
                  if (tapTimes.length >= 2) {
                    final intervals = <int>[];
                    for (int i = 1; i < tapTimes.length; i++) {
                      intervals.add(tapTimes[i].difference(tapTimes[i - 1]).inMilliseconds);
                    }
                    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
                    final calculatedBpm = (60000 / avgInterval).round();
                    
                    setDialogState(() {
                      controller.text = calculatedBpm.toString();
                    });
                  }
                },
                icon: const Icon(Icons.touch_app),
                label: Text(AppStrings.tapTempoButton),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zrušit")),
            TextButton(
              onPressed: () {
                setState(() => _bpm = double.tryParse(controller.text));
                _saveSettings();
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_song.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: "Tempo (BPM)",
            onPressed: _showBpmDialog,
          ),
          Semantics(
            customSemanticsActions: {
              const CustomSemanticsAction(label: "Spravovat pauzy"): _manageStopMarks,
            },
            child: GestureDetector(
              onLongPress: _manageStopMarks,
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: "Přidat pauzu (sólo) - podržením spravujete",
                onPressed: _addStopMark,
              ),
            ),
          ),
          // Korekce rychlosti posuvu
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.fast_forward),
                tooltip: "Zrychlit posuv o 10 procent",
                onPressed: () {
                  setState(() => _scrollMultiplier += 0.1);
                  _saveSettings();
                },
              ),
              Semantics(
                label: "Aktuální rychlost posuvu",
                child: Text("${(_scrollMultiplier * 100).round()}%"),
              ),
              IconButton(
                icon: const Icon(Icons.fast_rewind),
                tooltip: "Zpomalit posuv o 10 procent",
                onPressed: () {
                  setState(() => _scrollMultiplier = (_scrollMultiplier - 0.1).clamp(0.1, 5.0));
                  _saveSettings();
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: "Zvětšit písmo",
            onPressed: () {
              setState(() => _fontSize += 2);
              _saveSettings();
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: "Zmenšit písmo",
            onPressed: () {
              setState(() => _fontSize = (_fontSize - 2).clamp(10, 100));
              _saveSettings();
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: AppProgressIndicator(label: "Načítám text..."))
        : Stack(
            children: [
              GestureDetector(
                onTap: _toggleScrolling,
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 400),
                  child: ChordDisplayWidget(
                    content: _loadedContent ?? "",
                    textStyle: TextStyle(fontSize: _fontSize),
                    chordStyle: TextStyle(fontSize: _fontSize * 0.9, color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (_countdown > 0)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: Text(
                      "$_countdown",
                      style: const TextStyle(fontSize: 80, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleScrolling,
        child: Icon(_isScrolling || _countdown > 0 ? Icons.pause : Icons.play_arrow),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.bookmark_add),
              label: const Text("OZNAČIT PAUZU"),
              onPressed: _quickAddStopMark,
            ),
            ElevatedButton.icon(
              icon: Icon(_song.isPlayed ? Icons.replay : Icons.check_circle),
              label: Text(_song.isPlayed ? AppStrings.encoreButton : AppStrings.playedButton),
              onPressed: () async {
                final newStatus = !_song.isPlayed;
                await widget.db.togglePlayed(_song.id, newStatus);
                if (newStatus) {
                  _tts.speak(AppStrings.songMarkedPlayed(_song.title));
                }
                setState(() {
                  _song = _song.copyWith(isPlayed: newStatus);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
