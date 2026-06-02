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

class PlayerPage extends StatefulWidget {
  final int songId;
  final AppDatabase db;

  const PlayerPage({super.key, required this.songId, required this.db});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();
  Timer? _scrollTimer;
  bool _isScrolling = false;
  
  double _fontSize = 20.0;
  double? _bpm;
  int _countdown = 0;
  
  String? _loadedContent;
  bool _isLoading = true;
  late SongEntry _song;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.8);
    _loadSongData();
  }

  Future<void> _loadSongData() async {
    try {
      _song = await (widget.db.select(widget.db.songs)..where((s) => s.id.equals(widget.songId))).getSingle();
      
      setState(() {
        _fontSize = _song.customFontSize ?? 20.0;
        _bpm = _song.tempo;
      });

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

  Future<void> _saveSettings() async {
    await (widget.db.update(widget.db.songs)..where((s) => s.id.equals(widget.songId))).write(
      SongsCompanion(
        tempo: Value(_bpm),
        customFontSize: Value(_fontSize),
      ),
    );
  }

  Future<void> _startWithCountdown() async {
    if (_bpm == null || _bpm! <= 0) {
      await _showBpmDialog();
      if (_bpm == null) return;
    }

    setState(() => _countdown = 4);
    
    final interval = Duration(milliseconds: (60000 / _bpm!).round());
    
    for (int i = 4; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await _tts.speak(i.toString());
      await Future.delayed(interval);
    }

    if (mounted) {
      setState(() {
        _countdown = 0;
        _isScrolling = true;
      });
      _startScrolling();
    }
  }

  void _startScrolling() {
    _scrollTimer?.cancel();
    // Výpočet rychlosti: Pixely za 50ms
    // Odhad: Jeden řádek textu má cca _fontSize * 1.5 pixelů. 
    // Předpokládáme 4 doby na řádek.
    final double pixelsPerBeat = (_fontSize * 1.5) / 4.0;
    final double beatsPerSecond = _bpm! / 60.0;
    final double pixelsPerSecond = pixelsPerBeat * beatsPerSecond;
    final double scrollStep = pixelsPerSecond / 20.0; // 20x za sekundu (každých 50ms)

    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        final newOffset = _scrollController.offset + scrollStep;
        if (newOffset < _scrollController.position.maxScrollExtent) {
          _scrollController.jumpTo(newOffset);
        } else {
          _stopScrolling();
        }
      }
    });
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    setState(() {
      _isScrolling = false;
      _countdown = 0;
    });
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
          title: const Text("Nastavit tempo (BPM)"),
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
                label: const Text("KLEPEJTE DO RYTMU"),
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
            tooltip: "Nastavit tempo",
            onPressed: _showBpmDialog,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              setState(() => _fontSize += 2);
              _saveSettings();
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 200),
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
    );
  }
}
