import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'database.dart';
import 'chord_display_widget.dart';
import 'chord_pro_parser.dart';
import 'chord_transposer.dart';
import 'app_progress_indicator.dart';
import 'app_strings.dart';
import 'song_export.dart';

/// Konstanta pro horní odsazení textu v SingleChildScrollView (16px).
const double _kTopPadding = 16.0;

/// Cíl zarážky – kotva na řádek textu (primárně) nebo procento (záložně).
class _StopMarkTarget {
  final StopMark? dbMark;
  final int bars;
  int? lineIndex;
  double? ratio;

  _StopMarkTarget({this.dbMark, required this.bars, this.lineIndex, this.ratio});
}

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
  
  SongEntry? _song;
  bool _isLoading = true;
  String? _loadedContent;
  
  double _fontSize = 20.0;
  double _scrollMultiplier = 1.0;
  double? _bpm;
  double? _introDuration;
  int _countdown = 0;
  int _transpose = 0;
  List<StopMark> _stopMarks = [];
  List<_StopMarkTarget> _resolvedStopMarks = [];
  final Set<_StopMarkTarget> _triggeredMarks = {};
  Map<int, double> _lineOffsets = {};
  Set<int> _anchorLines = {};

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
      _checkStopMarks();
    }
  }

  void _checkStopMarks() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;

    for (final mark in _resolvedStopMarks) {
      if (_triggeredMarks.contains(mark)) continue;
      final target = _stopMarkTargetOffset(mark, maxExtent);
      if (target == null) continue;
      // Zarážka se spustí ve chvíli, kdy její řádek dorazí k horní hraně obrazovky.
      if (currentOffset >= target) {
        _triggeredMarks.add(mark);
        _handleStopMarkTarget(mark);
        break;
      }
    }
  }

  double? _stopMarkTargetOffset(_StopMarkTarget mark, double maxExtent) {
    final lineIndex = mark.lineIndex;
    final lineOffset = lineIndex != null ? _lineOffsets[lineIndex] : null;
    if (lineOffset != null) {
      // Horní odsazení textu (16px) + pozice řádku v obsahu.
      return (_kTopPadding + lineOffset).clamp(0.0, maxExtent).toDouble();
    }
    if (mark.ratio != null) {
      return (mark.ratio! * maxExtent).clamp(0.0, maxExtent).toDouble();
    }
    return null;
  }

  Future<void> _handleStopMarkTarget(_StopMarkTarget mark) async {
    final bars = mark.bars > 0 ? mark.bars : 2;
    _scrollAnimationController.stop();
    _tts.speak(AppStrings.stopMarkMessage(bars));
    HapticFeedback.mediumImpact(); // Vibrace na začátku pauzy

    final totalMs = ((60000 / (_bpm ?? 120)) * bars * 4).round();

    // Pokud je pauza delší než 2 sekundy, zavibrujeme sekundu před koncem jako varování
    if (totalMs > 2000) {
      await Future.delayed(Duration(milliseconds: totalMs - 1000));
      if (mounted && _isScrolling) HapticFeedback.lightImpact(); // Varování před rozjezdem
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _isScrolling) HapticFeedback.lightImpact(); // Dvojitý pulz
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      await Future.delayed(Duration(milliseconds: totalMs));
    }

    if (mounted && _isScrolling) {
      _tts.speak(AppStrings.stopMarkResumeMessage);
      HapticFeedback.vibrate();
      _scrollAnimationController.forward();
    }
  }

  Future<void> _loadSongData() async {
    try {
      final song = await (widget.db.select(widget.db.songs)..where((s) => s.id.equals(widget.songId))).getSingle();
      _song = song;
      _stopMarks = await widget.db.getStopMarksForSong(widget.songId);

      setState(() {
        _fontSize = song.customFontSize ?? 20.0;
        _scrollMultiplier = song.customScrollSpeed ?? 1.0;
        _bpm = song.tempo;
        _introDuration = song.introDuration;
      });

      final file = File(song.filePath);
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
          await _buildResolvedStopMarks();
        }
      } else {
        if (mounted) {
          setState(() { _loadedContent = "Soubor nenalezen"; _isLoading = false; });
          _tts.speak("Soubor nenalezen");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loadedContent = "Chyba: $e"; _isLoading = false; });
        _tts.speak("Chyba při načítání souboru");
      }
    }
  }

  /// Sestaví cíle zarážek: z direktiv {stop}/{pause} v textu i z databáze.
  Future<void> _buildResolvedStopMarks() async {
    final content = _loadedContent ?? '';
    final lines = ChordProParser.orderedLines(content);
    final targets = <_StopMarkTarget>[];

    // Zarážky z direktiv v textu
    for (final mark in ChordProParser.stopMarksInLines(content)) {
      targets.add(_StopMarkTarget(bars: mark.bars, lineIndex: mark.index));
    }

    // Zarážky z databáze (s kotvou na řádek, případně záložně procentem)
    for (final dbMark in _stopMarks) {
      final lineIndex = _resolveDbLineIndex(dbMark, lines);
      targets.add(_StopMarkTarget(
        dbMark: dbMark,
        bars: dbMark.durationBars,
        lineIndex: lineIndex,
        ratio: lineIndex == null ? dbMark.positionRatio : null,
      ));
    }

    setState(() {
      _resolvedStopMarks = targets;
      _anchorLines = {
        for (final t in targets)
          if (t.dbMark != null && t.lineIndex != null) t.lineIndex!,
      };
    });
  }

  /// Najde kotevní řádek databázové zarážky podle uloženého textu/indexu.
  int? _resolveDbLineIndex(StopMark mark, List<List<ChordProElement>> lines) {
    final markText = (mark.lineText ?? '').trim();
    if (mark.lineIndex != null && mark.lineIndex! >= 0 && mark.lineIndex! < lines.length) {
      final idx = mark.lineIndex!;
      final matchesText = markText.isEmpty ||
          ChordProParser.lineText(lines[idx]) == markText;
      if (matchesText) return idx;
    }
    if (markText.isNotEmpty) {
      for (var i = 0; i < lines.length; i++) {
        if (ChordProParser.lineText(lines[i]) == markText) return i;
      }
    }
    return mark.lineIndex != null && mark.lineIndex! >= 0 && mark.lineIndex! < lines.length
        ? mark.lineIndex
        : null;
  }

  Future<void> _reloadStopMarks() async {
    _stopMarks = await widget.db.getStopMarksForSong(widget.songId);
    await _buildResolvedStopMarks();
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
                    final location = mark.lineText != null && mark.lineText!.isNotEmpty
                        ? "Řádek: ${mark.lineText}"
                        : "Pozice: ${(mark.positionRatio * 100).round()}% textu";
                    return Semantics(
                      label: "Pauza na ${mark.durationBars} takty. $location",
                      child: ListTile(
                        leading: const Icon(Icons.pause_circle_filled),
                        title: Text("Pauza na ${mark.durationBars} takty"),
                        subtitle: Text(location),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: "Smazat tuto pauzu na ${mark.durationBars} takty",
                          onPressed: () async {
                            await widget.db.deleteStopMark(mark.id);
                            await _reloadStopMarks();
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

  void _showPlayerControls() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        int localTranspose = _transpose;
        double localFontSize = _fontSize;
        double localScrollMultiplier = _scrollMultiplier;

        void syncToPage() {
          setState(() {
            _transpose = localTranspose;
            _fontSize = localFontSize;
            _scrollMultiplier = localScrollMultiplier;
          });
        }

        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Ovládání přehrávače", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, size: 48),
                      color: Colors.blue,
                      tooltip: "Snížit transpozici",
                      onPressed: () {
                        setSheetState(() => localTranspose--);
                        syncToPage();
                        _tts.speak("Transpozice $localTranspose");
                      },
                    ),
                    Text("T: $localTranspose", style: const TextStyle(fontSize: 20)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, size: 48),
                      color: Colors.blue,
                      tooltip: "Zvýšit transpozici",
                      onPressed: () {
                        setSheetState(() => localTranspose++);
                        syncToPage();
                        _tts.speak("Transpozice $localTranspose");
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.text_decrease, size: 48),
                      color: Colors.green,
                      tooltip: "Zmenšit písmo",
                      onPressed: () {
                        setSheetState(() => localFontSize = (localFontSize - 2).clamp(10, 100));
                        syncToPage();
                        _saveSettings();
                      },
                    ),
                    Text("P: ${localFontSize.round()}", style: const TextStyle(fontSize: 20)),
                    IconButton(
                      icon: const Icon(Icons.text_increase, size: 48),
                      color: Colors.green,
                      tooltip: "Zvětšit písmo",
                      onPressed: () {
                        setSheetState(() => localFontSize = (localFontSize + 2).clamp(10, 100));
                        syncToPage();
                        _saveSettings();
                      },
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(icon: const Icon(Icons.speed, size: 48), color: Colors.purple, tooltip: "Nastavit BPM", onPressed: _showBpmDialog),
                    IconButton(
                      icon: const Icon(Icons.fast_rewind, size: 48),
                      color: Colors.orange,
                      tooltip: "Zpomalit posuv",
                      onPressed: () {
                        setSheetState(() => localScrollMultiplier = (localScrollMultiplier - 0.1).clamp(0.1, 5.0));
                        syncToPage();
                        _saveSettings();
                      },
                    ),
                    Text("${(localScrollMultiplier * 100).round()}%", style: const TextStyle(fontSize: 20)),
                    IconButton(
                      icon: const Icon(Icons.fast_forward, size: 48),
                      color: Colors.orange,
                      tooltip: "Zrychlit posuv",
                      onPressed: () {
                        setSheetState(() => localScrollMultiplier = (localScrollMultiplier + 0.1).clamp(0.1, 5.0));
                        syncToPage();
                        _saveSettings();
                      },
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(icon: const Icon(Icons.bookmark_add), label: const Text("PAUZA"), onPressed: _quickAddStopMark),
                    ElevatedButton.icon(icon: const Icon(Icons.list), label: const Text("SPRÁVA PAUZ"), onPressed: _manageStopMarks),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addStopMark() async {
    final barsController = TextEditingController(text: "2");
    
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
              await _saveStopMarkAtTopLine(bars);
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
    await _saveStopMarkAtTopLine(2); // Výchozí 2 takty
    _tts.speak(AppStrings.stopMarkQuickAdded);
    HapticFeedback.lightImpact(); // Potvrzení uložení jemnou vibrací
  }

  /// Uloží zarážku na právě viditelný (horní) řádek, případně záložně procentem.
  Future<void> _saveStopMarkAtTopLine(int bars) async {
    final topLine = _topVisibleLineIndex();
    if (topLine != null) {
      final lines = ChordProParser.orderedLines(_loadedContent ?? '');
      final lineText = topLine < lines.length ? ChordProParser.lineText(lines[topLine]) : '';
      await widget.db.addStopMarkAtLine(widget.songId, topLine, lineText, bars);
    } else {
      final ratio = _scrollController.hasClients
          ? (_scrollController.position.maxScrollExtent > 0
              ? _scrollController.offset / _scrollController.position.maxScrollExtent
              : 0.0)
          : 0.0;
      await widget.db.addStopMark(widget.songId, ratio, bars);
    }
    await _reloadStopMarks();
  }

  /// Index řádku, jehož horní hrana je těsně u horního okraje obrazovky.
  int? _topVisibleLineIndex() {
    if (_lineOffsets.isEmpty) return null;
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    int? best;
    double bestY = -double.infinity;
    for (final entry in _lineOffsets.entries) {
      if (entry.value <= offset + _kTopPadding && entry.value > bestY) {
        best = entry.key;
        bestY = entry.value;
      }
    }
    return best;
  }

  void _startScrolling() {
    if (!_scrollController.hasClients) return;
    
    final maxExtent = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final remainingScroll = maxExtent - currentOffset;
    
    if (MediaQuery.of(context).disableAnimations) {
      _scrollController.jumpTo(maxExtent);
      _stopScrolling();
      return;
    }
    
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
        title: Text(_song?.title ?? ""),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: AppStrings.shareButtonLabel,
            onPressed: () {
              final song = _song;
              final content = _loadedContent;
              if (song == null || content == null) return;
              showSongShareDialog(
                context,
                title: song.title,
                artist: song.artist,
                content: content,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Ovládání přehrávače",
            onPressed: _showPlayerControls,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: AppProgressIndicator(label: "Načítám text..."))
        : Stack(
            children: [
              Semantics(
                label: "Klepnutím spustíte nebo zastavíte automatický posuv textu",
                button: true,
                child: GestureDetector(
                  onTap: _toggleScrolling,
                  behavior: HitTestBehavior.opaque,
                  child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 400),
                  child: ChordDisplayWidget(
                    content: ChordTransposer.transposeText(_loadedContent ?? "", _transpose),
                    textStyle: TextStyle(fontSize: _fontSize * MediaQuery.textScaleFactorOf(context)),
                    chordStyle: TextStyle(fontSize: _fontSize * 0.9 * MediaQuery.textScaleFactorOf(context), color: Colors.blue, fontWeight: FontWeight.bold),
                    anchorLines: _anchorLines,
                    onLineOffsetsChanged: (offsets) {
                      if (!mounted) return;
                      final same = offsets.length == _lineOffsets.length &&
                          offsets.entries.every((e) => _lineOffsets[e.key] == e.value);
                      if (same) return;
                      setState(() => _lineOffsets = offsets);
                    },
                  ),
                ),
              ),
              ),
              if (_countdown > 0)
                Semantics(
                  liveRegion: true,
                  label: "Odpočet: $_countdown",
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: Text(
                        "$_countdown",
                        style: const TextStyle(fontSize: 80, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Velké tlačítko pro rychlé přidání zarážky na viditelný řádek.
          Semantics(
            label: AppStrings.addStopMarkButtonLabel,
            button: true,
            child: GestureDetector(
              onLongPress: _addStopMark,
              child: FloatingActionButton(
                heroTag: 'addStopMarkFAB',
                onPressed: _quickAddStopMark,
                focusColor: Colors.red,
                child: const Icon(Icons.pause_circle_outline, size: 32),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            label: _isScrolling || _countdown > 0 ? "Zastavit posuv" : "Spustit posuv",
            button: true,
            child: FloatingActionButton(
              heroTag: 'playFAB',
              onPressed: _toggleScrolling,
              child: Icon(_isScrolling || _countdown > 0 ? Icons.pause : Icons.play_arrow),
            ),
          ),
        ],
      ),
    );
  }
}
