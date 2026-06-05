import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:drift/drift.dart' show Value;
import 'database.dart';
import 'song_entry.dart';
import 'chord_display_widget.dart';
import 'chord_transposer.dart';
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

class _PlayerPageState extends State<PlayerPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();
  late AnimationController _scrollAnimationController;
  bool _isScrolling = false;
  
  late SongEntry _song;
  bool _isLoading = true;
  String? _loadedContent;
  
  double _fontSize = 20.0;
  double _scrollMultiplier = 1.0;
  double? _bpm;
  double? _introDuration;
  int _countdown = 0;
  int _transpose = 0;
  List<StopMark> _stopMarks = [];

  Future<void> _saveSettings() async {
    await widget.db.updateSongSettings(widget.songId, _bpm, _introDuration, _fontSize, _scrollMultiplier);
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

  void _startWithCountdown() async {
    setState(() => _isScrolling = true);
    HapticFeedback.heavyImpact(); // Vibrace na začátku celého procesu
    
    if (_introDuration != null && _introDuration! > 0) {
      _tts.speak(AppStrings.introMessage(_introDuration!.round()));
      await Future.delayed(Duration(seconds: _introDuration!.round()));
    }

    if (!mounted || !_isScrolling) return;

    for (int i = 3; i > 0; i--) {
      if (!mounted || !_isScrolling) return;
      setState(() => _countdown = i);
      _tts.speak("$i");
      HapticFeedback.mediumImpact(); // Vibrace pro každou sekundu odpočtu
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted || !_isScrolling) return;
    setState(() => _countdown = 0);
    HapticFeedback.vibrate(); // Delší vibrace při startu samotného posuvu
    
    debugPrint("Countdown finished, calling _startScrolling");
    _startScrolling();
  }

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);
    _scrollAnimationController = AnimationController(vsync: this);
    _scrollAnimationController.addListener(_onAnimationUpdate);
    _loadSongData();
  }

  void _onAnimationUpdate() {
    if (_scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(_scrollAnimationController.value * maxExtent);
      
      // Kontrola zarážek
      final currentRatio = _scrollAnimationController.value;
      for (final mark in _stopMarks) {
        if (currentRatio >= mark.positionRatio && currentRatio < mark.positionRatio + 0.01) {
          _handleStopMark(mark);
          break;
        }
      }
    }
  }

  Future<void> _handleStopMark(StopMark mark) async {
    _scrollAnimationController.stop();
    _tts.speak(AppStrings.stopMarkMessage(mark.durationBars));
    HapticFeedback.mediumImpact(); // Vibrace na začátku pauzy
    
    final totalMs = ((60000 / (_bpm ?? 120)) * mark.durationBars * 4).round();
    
    // Pokud je pauza delší než 2 sekundy, zavibrujeme sekundu před koncem jako varování
    if (totalMs > 2000) {
      await Future.delayed(Duration(milliseconds: totalMs - 1000));
      if (mounted && _isScrolling) HapticFeedback.lightImpact(); // Varování před rozjezdem
      await Future.delayed(const Duration(milliseconds: 1000));
    } else {
      await Future.delayed(Duration(milliseconds: totalMs));
    }
    
    if (mounted && _isScrolling) {
      _scrollAnimationController.forward();
    }
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
    HapticFeedback.lightImpact(); // Potvrzení uložení jemnou vibrací
  }

  void _startScrolling() {
    if (!_scrollController.hasClients) return;
    
    final maxExtent = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final remainingScroll = maxExtent - currentOffset;
    
    // Výpočet trvání: (px / px_za_beat) * (60 / bpm)
    final pixelsPerBeat = (_fontSize * 1.5) / 4.0;
    final totalBeats = remainingScroll / pixelsPerBeat;
    final durationInSeconds = (totalBeats * 60.0 / (_bpm ?? 120.0)) / _scrollMultiplier;
    
    _scrollAnimationController.duration = Duration(milliseconds: (durationInSeconds * 1000).round());
    _scrollAnimationController.value = currentOffset / maxExtent;
    _scrollAnimationController.forward();
  }

  void _stopScrolling() {
    _scrollAnimationController.stop();
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
    if (_isScrolling) {
      _stopScrolling();
    } else {
      _startWithCountdown();
    }
  }

  @override
  void dispose() {
    _scrollAnimationController.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_song.title),
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
                    content: ChordTransposer.transposeText(_loadedContent ?? "", _transpose),
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
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Transpozice
                  IconButton(
                    icon: const Icon(Icons.remove_circle),
                    iconSize: 40,
                    color: Colors.blue,
                    tooltip: "Transponovat níž",
                    onPressed: () { setState(() => _transpose--); _tts.speak("Transpozice na $_transpose"); },
                  ),
                  Text("T: $_transpose", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    iconSize: 40,
                    color: Colors.blue,
                    tooltip: "Transponovat výš",
                    onPressed: () { setState(() => _transpose++); _tts.speak("Transpozice na $_transpose"); },
                  ),
                  // Písmo
                  IconButton(
                    icon: const Icon(Icons.text_decrease),
                    iconSize: 40,
                    color: Colors.green,
                    tooltip: "Zmenšit písmo",
                    onPressed: () { setState(() => _fontSize = (_fontSize - 2).clamp(10, 100)); _saveSettings(); },
                  ),
                  Text("P: ${_fontSize.round()}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.text_increase),
                    iconSize: 40,
                    color: Colors.green,
                    tooltip: "Zvětšit písmo",
                    onPressed: () { setState(() => _fontSize += 2); _saveSettings(); },
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Tempo (BPM)
                  IconButton(
                    icon: const Icon(Icons.speed),
                    iconSize: 40,
                    color: Colors.purple,
                    tooltip: "Nastavit tempo (BPM)",
                    onPressed: _showBpmDialog,
                  ),
                  Text("BPM: ${(_bpm ?? 120).round()}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  
                  // Rychlost
                  IconButton(
                    icon: const Icon(Icons.fast_rewind),
                    iconSize: 40,
                    color: Colors.orange,
                    tooltip: "Zpomalit",
                    onPressed: () { setState(() => _scrollMultiplier = (_scrollMultiplier - 0.1).clamp(0.1, 5.0)); _saveSettings(); },
                  ),
                  Text("R: ${(_scrollMultiplier * 100).round()}%", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.fast_forward),
                    iconSize: 40,
                    color: Colors.orange,
                    tooltip: "Zrychlit",
                    onPressed: () { setState(() => _scrollMultiplier += 0.1); _saveSettings(); },
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    onTap: _quickAddStopMark,
                    onLongPress: _manageStopMarks,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.bookmark_add, color: Colors.blue),
                          SizedBox(width: 8),
                          Text("PAUZA", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(_song.isPlayed ? Icons.replay : Icons.check_circle),
                    label: Text(_song.isPlayed ? "Znovu" : "Hotovo"),
                    onPressed: () async {
                      final newStatus = !_song.isPlayed;
                      await widget.db.togglePlayed(_song.id, newStatus);
                      setState(() => _song = _song.copyWith(isPlayed: newStatus));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
