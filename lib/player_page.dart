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
import 'concert_accessibility_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final int? playlistId;

  const PlayerPage({super.key, required this.songId, required this.db, this.setlistIds, this.playlistId});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();
  late AnimationController _scrollAnimationController;
  late ConcertAccessibilityService _concertService;
  final FocusNode _focusNode = FocusNode();
  bool _isScrolling = false;
  bool _concertMode = false;
  int _concertPreviewMode = 1; // 0 off, 1 onDemand, 2 auto
  bool _concertTrainingMode = false;
  int _concertZonesMode = 0; // 0 vždy aktivní, 1 na požádání
  bool _zonesArmed = false;
  int _setlistDelay = 5; // 3,5,10 nebo -1 = čekat na stisk (C2)
  bool _setlistAutoPending = false;
  bool _setlistCancelled = false;
  
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

  /// Kurzor ručního náhledu - index dalšího řádku k ohlášení při zastaveném posuvu.
  int? _manualPreviewCursor;

  Future<void> _saveSettings({double? customFontSize}) async {
    // Pokud jsme v setlistu s playlistId, ulož tempo per-setlist (globální ostatní)
    if (widget.playlistId != null) {
      await widget.db.updatePlaylistSongTempo(widget.playlistId!, widget.songId, _bpm);
      // ostatní nastavení (font, rychlost, intro) stále globálně na písni
      await widget.db.updateSongSettings(widget.songId, null, _introDuration, customFontSize ?? _fontSize, _scrollMultiplier);
    } else {
      await widget.db.updateSongSettings(widget.songId, _bpm, _introDuration, customFontSize ?? _fontSize, _scrollMultiplier);
    }
  }

  double _effectiveBpm() => (_bpm ?? 120.0) * _scrollMultiplier;

  double _calcDurationSeconds(double remainingScroll) {
    final pixelsPerBeat = (_fontSize * 1.5) / 4.0;
    if (pixelsPerBeat <= 0) return 0;
    final totalBeats = remainingScroll / pixelsPerBeat;
    final effectiveBpm = _effectiveBpm();
    if (effectiveBpm <= 0) return 0;
    return totalBeats * 60.0 / effectiveBpm;
  }

  void _updateScrollingSpeed() {
    if (!_isScrolling || !_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    final currentOffset = _scrollController.offset;
    final remainingScroll = (maxExtent - currentOffset).clamp(0.0, maxExtent).toDouble();
    if (remainingScroll <= 0) return;
    final durationInSeconds = _calcDurationSeconds(remainingScroll);
    final newDuration = Duration(milliseconds: (durationInSeconds * 1000).round());
    // Zachovat plynulost – nastavit novou duration a pokračovat od aktuální pozice
    _scrollAnimationController.stop();
    _scrollAnimationController.duration = newDuration;
    _scrollAnimationController.value = (currentOffset / maxExtent).clamp(0.0, 1.0).toDouble();
    if (remainingScroll > 1) {
      _scrollAnimationController.forward();
    }
  }

  Future<void> _adjustBpm(int delta) async {
    final newBpm = ((_bpm ?? 120.0) + delta).clamp(30.0, 300.0).toDouble();
    setState(() => _bpm = newBpm);
    await _saveSettings();
    _updateScrollingSpeed();
    HapticFeedback.vibrate(); 
    _tts.stop();
    _tts.speak(AppStrings.bpmChangedMessage(newBpm.round()));
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.bpmChangedMessage(newBpm.round())),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Ohlásí jemnou změnu rychlosti posuvu v procentech, včetně efektivního BPM.
  void _speakScrollSpeed(double multiplier, {required double baseBpm}) {
    final int percent = (multiplier * 100).round();
    String message = AppStrings.scrollSpeedChanged(percent);
    if ((multiplier - 1.0).abs() >= 0.01) {
      final int effective = (baseBpm * multiplier).round();
      message += ", ${AppStrings.bpmEffectiveValue(effective)}";
    }
    _tts.stop();
    _tts.speak(message);
  }

  Future<void> _showBpmDialog() async {
    final controller = TextEditingController(text: _bpm?.round().toString() ?? "120");
    List<DateTime> tapTimes = [];
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Semantics(header: true, child: Text(AppStrings.bpmDialogTitle)),
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
                _updateScrollingSpeed();
                Navigator.pop(context);
                final int? savedBpm = _bpm?.round();
                if (savedBpm != null) {
                  _tts.speak(AppStrings.bpmSetMessage(savedBpm));
                }
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
    HapticFeedback.vibrate(); 
    
    if (_introDuration != null && _introDuration! > 0) {
      _tts.speak(AppStrings.introMessage(_introDuration!.round()));
      await Future.delayed(Duration(seconds: _introDuration!.round()));
    }

    if (!mounted || !_isScrolling) return;

    for (int i = 3; i > 0; i--) {
      if (!mounted || !_isScrolling) return;
      setState(() => _countdown = i);
      _tts.speak("$i");
      HapticFeedback.vibrate(); 
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted || !_isScrolling) return;
    setState(() => _countdown = 0);
    HapticFeedback.vibrate(); 
    
    debugPrint("Countdown finished, calling _startScrolling");
    _startScrolling();
  }

  static const MethodChannel _concertChannel = MethodChannel('concert_volume_channel');

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);
    _concertService = ConcertAccessibilityService(tts: _tts);
    _scrollAnimationController = AnimationController(vsync: this);
    _scrollAnimationController.addListener(_onAnimationUpdate);
    _loadConcertPrefs();
    _loadSongData();
    _concertChannel.setMethodCallHandler(_handleConcertMethod);
  }

  Future<dynamic> _handleConcertMethod(MethodCall call) async {
    if (call.method == 'onVolumeBpm') {
      final delta = (call.arguments as Map?)?['delta'] as int? ?? 5;
      if (_concertMode) {
        await _adjustBpm(delta);
      }
    } else if (call.method == 'onSetlistNext' || call.method == 'onVolumeLongNext') {
      if (widget.setlistIds != null) await _handleNextInSetlist(manual: true);
    } else if (call.method == 'onSetlistPrev' || call.method == 'onVolumeLongPrev') {
      if (widget.setlistIds != null) await _handlePreviousInSetlist();
    }
    return null;
  }

  Future<void> _syncConcertModeToNative() async {
    try {
      await _concertChannel.invokeMethod('setConcertMode', {'enabled': _concertMode});
    } catch (_) {
      // Nativní kanál nemusí být dostupný v testu / na iOS
    }
  }

  Future<void> _loadConcertPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final mode = prefs.getBool('concertMode') ?? false;
      final preview = prefs.getInt('concertPreviewMode') ?? 1;
      final training = prefs.getBool('concertTrainingMode') ?? false;
      final zonesMode = prefs.getInt('concertZonesMode') ?? 0;
      final delay = prefs.getInt('setlistDelay') ?? 5;
      setState(() {
        _concertMode = mode;
        _concertPreviewMode = preview;
        _concertTrainingMode = training;
        _concertZonesMode = zonesMode;
        _setlistDelay = delay;
        // Zóny "na požádání" začínají při každé písni vypnuté
        _zonesArmed = false;
      });
      await _syncConcertModeToNative();
    } catch (_) {
      // Test prostředí bez SharedPreferences mock - ponech default
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final handled = _concertService.handleKeyEvent(
      event,
      concertMode: _concertMode,
      onToggleScrolling: _toggleScrolling,
      onAdjustBpm: (d) => _adjustBpm(d),
      onAnnounceNext: () => _announceNextLine(isAutomatic: false),
      onNextSong: widget.setlistIds == null ? null : () => _handleNextInSetlist(manual: true),
      onPrevSong: widget.setlistIds == null ? null : () => _handlePreviousInSetlist(),
    );
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  Future<void> _announceNextLine({required bool isAutomatic}) async {
    if (!_concertMode || _concertPreviewMode == 0) return;
    if (isAutomatic && _concertPreviewMode != 2) return;
    if (!isAutomatic && _concertPreviewMode == 0) return;
    // Nepřekrývat odpočet a pauzu
    if (_countdown > 0) return;

    final int? startOverride = isAutomatic ? null : _manualPreviewCursor;
    final int? announcedIndex = await _concertService.announceNextLine(
      loadedContent: _loadedContent,
      topVisibleLineIndex: _topVisibleLineIndex(),
      lineOffsets: _lineOffsets,
      isAutomatic: isAutomatic,
      startIndexOverride: startOverride,
    );
    if (!mounted || isAutomatic) return;
    // Ruční režim: kurzor postoupí na další řádek; po konci textu se nuluje
    setState(() => _manualPreviewCursor = announcedIndex == null ? null : announcedIndex + 1);
  }

  void _checkAutoNextLine() {
    if (!_concertMode || _concertPreviewMode != 2 || !_isScrolling) return;
    if (_countdown > 0) return;
    final topIdx = _topVisibleLineIndex();
    if (topIdx == null) return;
    final lines = ChordProParser.orderedLines(_loadedContent ?? '');
    final nextIdx = topIdx + 1;
    if (nextIdx >= lines.length) return;
    final maxExtent = _scrollController.hasClients ? _scrollController.position.maxScrollExtent : 0.0;
    if (maxExtent <= 0) return;
    final nextOffset = _lineOffsets[nextIdx];
    if (nextOffset == null) return;
    final currentOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    if (_concertService.shouldAutoAnnounce(
      nextLineOffset: _kTopPadding + nextOffset,
      currentOffset: currentOffset,
      effectiveBpm: _effectiveBpm(),
      fontSize: _fontSize,
    )) {
      _announceNextLine(isAutomatic: true);
    }
  }

  void _onAnimationUpdate() {
    if (_scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(_scrollAnimationController.value * maxExtent);
      _checkStopMarks();
      _checkAutoNextLine();
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
    HapticFeedback.vibrate(); 

    final totalMs = ((60000 / (_bpm ?? 120)) * bars * 4).round();

    // Pokud je pauza delší než 2 sekundy, zavibrujeme sekundu před koncem jako varování
    if (totalMs > 2000) {
      await Future.delayed(Duration(milliseconds: totalMs - 1000));
      if (mounted && _isScrolling) HapticFeedback.vibrate(); 
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _isScrolling) HapticFeedback.vibrate(); 
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      await Future.delayed(Duration(milliseconds: totalMs));
    }

    if (mounted && _isScrolling) {
      _tts.speak(AppStrings.stopMarkResumeMessage);
      HapticFeedback.vibrate();
      _manualPreviewCursor = null;
      _scrollAnimationController.forward();
    }
  }

  Future<void> _loadSongData() async {
    try {
      final song = await (widget.db.select(widget.db.songs)..where((s) => s.id.equals(widget.songId))).getSingle();
      _song = song;
      _stopMarks = await widget.db.getStopMarksForSong(widget.songId);

      final prefs = await SharedPreferences.getInstance();
      final globalFontSize = prefs.getDouble('fontSize') ?? 24.0;

      double? effectiveTempo = song.tempo;
      if (widget.playlistId != null) {
        final pt = await widget.db.getPlaylistSongTempo(widget.playlistId!, widget.songId);
        if (pt != null) effectiveTempo = pt;
      }

      setState(() {
        _fontSize = song.customFontSize ?? globalFontSize;
        _scrollMultiplier = song.customScrollSpeed ?? 1.0;
        _bpm = effectiveTempo;
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
            _manualPreviewCursor = null;
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
          title: Semantics(header: true, child: Text("Správa pauz")),
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
          // Okamžitě přepočítat rychlost i během posuvu
          _updateScrollingSpeed();
        }

        String effectiveBpmLabel() {
          final base = _bpm ?? 120.0;
          final eff = (base * localScrollMultiplier).round();
          if ((localScrollMultiplier - 1.0).abs() < 0.01) return "$eff BPM";
          return "${base.round()} BPM → $eff BPM";
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
                        _updateScrollingSpeed();
                        _tts.speak(AppStrings.fontSizeChanged(localFontSize.round()));
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
                        _updateScrollingSpeed();
                        _tts.speak(AppStrings.fontSizeChanged(localFontSize.round()));
                      },
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final globalFontSize = prefs.getDouble('fontSize') ?? 24.0;
                    setSheetState(() => localFontSize = globalFontSize);
                    setState(() => _fontSize = globalFontSize);
                    await _saveSettings(customFontSize: null);
                    _updateScrollingSpeed();
                    _tts.speak("Nastaveno na globální velikost ${globalFontSize.round()}");
                  },
                  child: const Text("Použít globální velikost"),
                ),
                const Divider(),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(icon: const Icon(Icons.speed, size: 48), color: Colors.purple, tooltip: "Nastavit BPM", onPressed: () async { await _showBpmDialog(); setSheetState(() {}); }),
                        IconButton(
                          icon: const Icon(Icons.fast_rewind, size: 48),
                          color: Colors.orange,
                          tooltip: "Zpomalit posuv (jemně -5 %)",
                          onPressed: () {
                            setSheetState(() => localScrollMultiplier = (localScrollMultiplier - 0.05).clamp(0.1, 5.0));
                            syncToPage();
                            _saveSettings();
                            _speakScrollSpeed(localScrollMultiplier, baseBpm: _bpm ?? 120.0);
                          },
                        ),
                        Column(
                          children: [
                            Text("${(localScrollMultiplier * 100).round()}%", style: const TextStyle(fontSize: 20)),
                            Text(effectiveBpmLabel(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.fast_forward, size: 48),
                          color: Colors.orange,
                          tooltip: "Zrychlit posuv (jemně +5 %)",
                          onPressed: () {
                            setSheetState(() => localScrollMultiplier = (localScrollMultiplier + 0.05).clamp(0.1, 5.0));
                            syncToPage();
                            _saveSettings();
                            _speakScrollSpeed(localScrollMultiplier, baseBpm: _bpm ?? 120.0);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(AppStrings.bpmOverlayHelp, style: TextStyle(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center),
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
        title: Semantics(header: true, child: Text("Přidat pauzu")),
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
    HapticFeedback.vibrate(); 
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
    _manualPreviewCursor = null;

    final maxExtent = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final remainingScroll = maxExtent - currentOffset;
    
    if (MediaQuery.of(context).disableAnimations) {
      _scrollController.jumpTo(maxExtent);
      _stopScrolling();
      return;
    }
    
    final durationInSeconds = _calcDurationSeconds(remainingScroll);
    
    _scrollAnimationController.duration = Duration(milliseconds: (durationInSeconds * 1000).round());
    _scrollAnimationController.value = (currentOffset / maxExtent).clamp(0.0, 1.0).toDouble();
    _scrollAnimationController.forward();
  }

  void _stopScrolling() {
    _scrollAnimationController.stop();
    setState(() {
      _isScrolling = false;
      _countdown = 0;
    });

    // Pokud jsme v režimu Setlist a došli jsme na konec, nabídneme další píseň
    final bool setlistEndReached = widget.setlistIds != null &&
        _scrollController.hasClients &&
        _scrollController.offset >= _scrollController.position.maxScrollExtent - 10;

    // Konec setlistu ohlašuje samotný přechod na další píseň, neopakujeme
    if (!setlistEndReached) {
      _tts.speak(AppStrings.scrollStopped);
    }

    if (setlistEndReached) {
      _handleNextInSetlist();
    }
  }

  Future<void> _navigateToSetlistSong(int targetSongId) async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          songId: targetSongId,
          db: widget.db,
          setlistIds: widget.setlistIds,
          playlistId: widget.playlistId,
        ),
      ),
    );
  }

  Future<void> _handleNextInSetlist({bool manual = false}) async {
    if (widget.setlistIds == null) return;
    final currentIndex = widget.setlistIds!.indexOf(widget.songId);
    // Pokud je automatický přechod zrušen manuálním zásahem, ignoruj
    if (!manual && _setlistCancelled) {
      _setlistCancelled = false;
      return;
    }
    if (currentIndex != -1 && currentIndex < widget.setlistIds!.length - 1) {
      final nextSongId = widget.setlistIds![currentIndex + 1];
      final nextSong = await (widget.db.select(widget.db.songs)..where((s) => s.id.equals(nextSongId))).getSingle();
      
      if (!mounted) return;

      // Oznámit pozici v setlistu (B2)
      final posMsg = AppStrings.setlistPositionAnnouncement(currentIndex + 2, widget.setlistIds!.length);
      _tts.speak("${AppStrings.nextSongMessage(nextSong.title, nextSong.artist)} $posMsg");
      HapticFeedback.vibrate(); 

      if (_setlistDelay < 0) {
        // Režim čekat na stisk (C2)
        if (!mounted) return;
        setState(() => _setlistAutoPending = true);
        _tts.speak(AppStrings.setlistNextReady);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.setlistNextReady),
              duration: const Duration(days: 1),
              action: SnackBarAction(
                label: "Spustit hned",
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _navigateToSetlistSong(nextSongId);
                },
              ),
            ),
          );
        }
        return;
      }

      // Auto režim s nastavitelnou prodlevou + možnost zrušit
      _setlistCancelled = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Za $_setlistDelay s: ${nextSong.title} - ${nextSong.artist}"),
            duration: Duration(seconds: _setlistDelay),
            action: SnackBarAction(
              label: AppStrings.setlistCancelAutoLabel,
              onPressed: () {
                _setlistCancelled = true;
                _tts.speak(AppStrings.scrollStopped);
                HapticFeedback.lightImpact();
              },
            ),
          ),
        );
      }
      await Future.delayed(Duration(seconds: _setlistDelay));
      if (!mounted || _setlistCancelled) {
        _setlistCancelled = false;
        return;
      }
      await _navigateToSetlistSong(nextSongId);
    } else {
      _tts.speak(AppStrings.setlistEndMessage);
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.setlistEndMessage), duration: const Duration(seconds: 4)),
        );
      }
    }
  }

  Future<void> _handlePreviousInSetlist() async {
    if (widget.setlistIds == null) return;
    final currentIndex = widget.setlistIds!.indexOf(widget.songId);
    if (currentIndex > 0) {
      final prevSongId = widget.setlistIds![currentIndex - 1];
      final prevSong = await (widget.db.select(widget.db.songs)..where((s) => s.id.equals(prevSongId))).getSingle();
      if (!mounted) return;
      final posMsg = AppStrings.setlistPositionAnnouncement(currentIndex, widget.setlistIds!.length);
      _tts.speak("${AppStrings.setlistPrevSongAnnouncement(prevSong.title, prevSong.artist)} $posMsg");
      HapticFeedback.vibrate(); 
      // Zrušit případný čekající auto-přechod
      _setlistCancelled = true;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => _setlistAutoPending = false);
      await _navigateToSetlistSong(prevSongId);
    } else {
      _tts.speak("Jste na první písni setlistu");
      HapticFeedback.vibrate(); 
    }
  }

  void _toggleScrolling() {
    // Pokud čekáme na potvrzení další písně (režim čekat na stisk), poklep spustí další
    if (_setlistAutoPending && widget.setlistIds != null) {
      final idx = widget.setlistIds!.indexOf(widget.songId);
      if (idx != -1 && idx < widget.setlistIds!.length - 1) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() => _setlistAutoPending = false);
        _navigateToSetlistSong(widget.setlistIds![idx + 1]);
        return;
      }
    }
    if (_isScrolling) {
      _stopScrolling();
    } else {
      _startWithCountdown();
    }
  }

  /// Označí nebo odoznačí píseň jako odehranou (DOHRÁNO / PŘÍDAVEK).
  Future<void> _togglePlayed() async {
    final song = _song;
    if (song == null) return;
    final bool newStatus = !song.isPlayed;
    await widget.db.togglePlayed(song.id, newStatus);
    _tts.speak(newStatus
        ? AppStrings.songMarkedPlayed(song.title)
        : AppStrings.songMarkedNotPlayed(song.title));
    if (!mounted) return;
    setState(() {
      _song = song.copyWith(isPlayed: newStatus);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Aktualizovat nativní stav při každém zobrazení (např. po návratu z nastavení)
    _syncConcertModeToNative();
  }

  @override
  void dispose() {
    _concertService.reset();
    _concertChannel.setMethodCallHandler(null);
    _focusNode.dispose();
    _scrollAnimationController.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  int? _lastZone; // -1 left, 0 center, 1 right

  // Koncertní 3-zónový overlay: levá zpomalit, střed play/pause, pravá zrychlit
  Widget _buildConcertZones() {
    if (!_concertMode || _isLoading) return const SizedBox.shrink();
    // Režim "na požádání": zóny nesmí zasahovat do dotyků, dokud je obsluha nezapne
    if (_concertZonesMode == 1 && !_zonesArmed) return const SizedBox.shrink();
    return Positioned.fill(
      child: Listener(
        onPointerMove: (details) {
          final width = MediaQuery.of(context).size.width;
          final x = details.localPosition.dx;
          int zone = x < width / 3 ? -1 : (x < 2 * width / 3 ? 0 : 1);
          if (zone != _lastZone) {
            _lastZone = zone;
            HapticFeedback.lightImpact();
            // Zvuková značka - tóny lze vylepšit (např. přes assety)
            SystemSound.play(SystemSoundType.click); 
          }
        },
        onPointerUp: (_) => _lastZone = null,
        child: Row(
          children: [
            // Levá třetina - zpomalit
            Expanded(
              child: Semantics(
                label: AppStrings.concertZoneLeftSemantics,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_concertTrainingMode) {
                      _tts.speak("Zpomalit");
                    } else {
                      _adjustBpm(-5);
                    }
                  },
                  onLongPress: () => _adjustBpm(-10),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
                // Střední třetina - další řádek (tap) + play/pause (double-tap)
                Expanded(
                  child: Semantics(
                    label: AppStrings.concertZoneCenterSemantics,
                    hint: "Poklepání: další řádek. Dvojité poklepání: pauza/start.",
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                         _announceNextLine(isAutomatic: false);
                      },
                      onDoubleTap: () {
                        if (_concertTrainingMode) {
                          _tts.speak("Spustit posuv");
                        } else {
                          _toggleScrolling();
                        }
                      },
                      onLongPress: () => _announceNextLine(isAutomatic: false),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

            // Pravá třetina - zrychlit
            Expanded(
              child: Semantics(
                label: AppStrings.concertZoneRightSemantics,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_concertTrainingMode) {
                      _tts.speak("Zrychlit");
                    } else {
                      _adjustBpm(5);
                    }
                  },
                  onLongPress: () => _adjustBpm(10),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    final base = _song?.title ?? "";
    if (widget.setlistIds == null) return Text(base);
    final idx = widget.setlistIds!.indexOf(widget.songId);
    if (idx == -1) return Text(base);
    return Semantics(
      label: "$base. ${AppStrings.setlistPositionAnnouncement(idx + 1, widget.setlistIds!.length)}",
      child: Text(base),
    );
  }

  @override
  Widget build(BuildContext context) {
    // V koncertním režimu zvětšit BPM overlay a hit targety
    final double bpmButtonPadding = _concertMode ? 12 : 4;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: [
          if (widget.setlistIds != null && !_isLoading)
            Semantics(
              label: AppStrings.setlistPositionAnnouncement(
                widget.setlistIds!.indexOf(widget.songId) + 1,
                widget.setlistIds!.length,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Chip(
                  label: Text(
                    "${widget.setlistIds!.indexOf(widget.songId) + 1}/${widget.setlistIds!.length}",
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.blue.withOpacity(0.15),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          if (_concertMode)
            Semantics(
              label: AppStrings.concertModeTitle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Chip(
                  label: Text(AppStrings.concertModeTitle, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.green.withOpacity(0.2),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
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
                label: _concertMode
                    ? "Koncertní režim: levá zpomalit, střed spustit/zastavit, pravá zrychlit. Dvojitým poklepáním další řádek."
                    : "Klepnutím spustíte nebo zastavíte automatický posuv textu",
                button: true,
                child: GestureDetector(
                  onTap: _concertMode ? null : _toggleScrolling,
                  onDoubleTap: _concertMode ? () => _announceNextLine(isAutomatic: false) : null,
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
              // Trvalý overlay pro rychlé ladění BPM i během posuvu (±5 tap, ±10 long-press)
              if (!_isLoading)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Semantics(
                    label: "${AppStrings.bpmOverlaySemantics} ${AppStrings.bpmOverlayValue((_bpm ?? 120).round())}",
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(24),
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: bpmButtonPadding, vertical: bpmButtonPadding - 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              label: AppStrings.bpmOverlayDecreaseLabel,
                              hint: AppStrings.bpmOverlayDecreaseLongLabel,
                              button: true,
                              child: GestureDetector(
                                onLongPress: () => _adjustBpm(-10),
                                child: IconButton(
                                  icon: const Icon(Icons.remove),
                                  tooltip: AppStrings.bpmOverlayDecreaseLabel,
                                  onPressed: () => _adjustBpm(-5),
                                  visualDensity: VisualDensity.compact,
                                  iconSize: _concertMode ? 28 : 24,
                                  padding: EdgeInsets.all(_concertMode ? 12 : 8),
                                ),
                              ),
                            ),
                            Semantics(
                              liveRegion: true,
                              label: AppStrings.bpmOverlayValue((_bpm ?? 120).round()),
                              child: Container(
                                constraints: BoxConstraints(minWidth: _concertMode ? 80 : 72),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppStrings.bpmOverlayValue((_bpm ?? 120).round()),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: _concertMode ? 16 : 14,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    if ((_scrollMultiplier - 1.0).abs() > 0.01)
                                      Text(
                                        AppStrings.bpmEffectiveValue(_effectiveBpm().round()),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Semantics(
                              label: AppStrings.bpmOverlayIncreaseLabel,
                              hint: AppStrings.bpmOverlayIncreaseLongLabel,
                              button: true,
                              child: GestureDetector(
                                onLongPress: () => _adjustBpm(10),
                                child: IconButton(
                                  icon: const Icon(Icons.add),
                                  tooltip: AppStrings.bpmOverlayIncreaseLabel,
                                  onPressed: () => _adjustBpm(5),
                                  visualDensity: VisualDensity.compact,
                                  iconSize: _concertMode ? 28 : 24,
                                  padding: EdgeInsets.all(_concertMode ? 12 : 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Koncertní 3-zónový overlay (nad textem, pod BPM overlay díky pořadí)
              _buildConcertZones(),
            ],
          ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Setlist: předchozí / další (B2) - přístupné i bez koncertního režimu
          if (widget.setlistIds != null && widget.setlistIds!.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                label: AppStrings.setlistSkipPrevLabel,
                button: true,
                child: FloatingActionButton.small(
                  heroTag: 'prevSongFAB',
                  tooltip: AppStrings.setlistSkipPrevLabel,
                  onPressed: _handlePreviousInSetlist,
                  child: const Icon(Icons.skip_previous),
                ),
              ),
            ),
          if (widget.setlistIds != null && widget.setlistIds!.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Semantics(
                label: AppStrings.setlistSkipNextLabel,
                button: true,
                child: FloatingActionButton.small(
                  heroTag: 'nextSongFAB',
                  tooltip: AppStrings.setlistSkipNextLabel,
                  onPressed: () => _handleNextInSetlist(manual: true),
                  child: const Icon(Icons.skip_next),
                ),
              ),
            ),
          // Přepínač zónového ovládání (jen v režimu "na požádání")
          if (_concertMode && _concertZonesMode == 1)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Semantics(
                label: _zonesArmed ? AppStrings.zoneToggleDisarmLabel : AppStrings.zoneToggleArmLabel,
                hint: _zonesArmed ? AppStrings.zonesDisarmedAnnouncement : AppStrings.zonesArmedAnnouncement,
                button: true,
                child: FloatingActionButton.small(
                  heroTag: 'zonesToggleFAB',
                  tooltip: _zonesArmed ? AppStrings.zoneToggleDisarmLabel : AppStrings.zoneToggleArmLabel,
                  onPressed: () {
                    setState(() => _zonesArmed = !_zonesArmed);
                    HapticFeedback.lightImpact();
                    _tts.speak(_zonesArmed
                        ? AppStrings.zonesArmedAnnouncement
                        : AppStrings.zonesDisarmedAnnouncement);
                  },
                  child: Icon(_zonesArmed ? Icons.touch_app : Icons.pan_tool),
                ),
              ),
            ),
          // Tlačítko náhled dalšího řádku v koncertním režimu
          if (_concertMode && _concertPreviewMode != 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Semantics(
                label: AppStrings.concertZoneNextLineSemantics,
                hint: AppStrings.nextLineGestureHint,
                button: true,
                child: FloatingActionButton.small(
                  heroTag: 'nextLineFAB',
                  onPressed: () => _announceNextLine(isAutomatic: false),
                  tooltip: AppStrings.concertZoneNextLineSemantics,
                  child: const Icon(Icons.hearing),
                ),
              ),
            ),
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
      bottomNavigationBar: (_isLoading || _song == null)
          ? null
          : BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Semantics(
                  label: _song!.isPlayed ? AppStrings.encoreButton : AppStrings.playedButton,
                  button: true,
                  child: ElevatedButton.icon(
                    icon: Icon(_song!.isPlayed ? Icons.replay : Icons.check_circle),
                    label: Text(
                      _song!.isPlayed
                          ? AppStrings.encoreButton
                          : AppStrings.playedButton,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _togglePlayed,
                  ),
                ),
              ),
            ),
      ),
    );
  }
}