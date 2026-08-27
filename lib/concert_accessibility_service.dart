import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'chord_pro_parser.dart';
import 'app_strings.dart';

/// Služba pro koncertní režim: HW klávesy, pedál, náhled dalšího řádku.
/// Navržena pro nevidomého muzikanta - odolná vůči hluku, bez hlasového ovládání.
class ConcertAccessibilityService {
  final FlutterTts tts;
  int _lastAnnouncedIndex = -1;

  ConcertAccessibilityService({required this.tts});

  void reset() {
    _lastAnnouncedIndex = -1;
  }

  /// Rozhodne, zda KeyEvent patří koncertnímu režimu a provede akci.
  /// Vrací true pokud byl event zpracován (nepropustit k systému).
  bool handleKeyEvent(
    KeyEvent event, {
    required bool concertMode,
    required VoidCallback onToggleScrolling,
    required Future<void> Function(int delta) onAdjustBpm,
    required Future<void> Function() onAnnounceNext,
    Future<void> Function()? onNextSong,
    Future<void> Function()? onPrevSong,
  }) {
    if (!concertMode) return false;
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

    // Setlist: další / předchozí píseň - HW media klávesy (B2)
    if (onNextSong != null &&
        (key == LogicalKeyboardKey.mediaTrackNext ||
            key == LogicalKeyboardKey.browserForward ||
            key == LogicalKeyboardKey.f12)) {
      HapticFeedback.heavyImpact();
      onNextSong();
      return true;
    }
    if (onPrevSong != null &&
        (key == LogicalKeyboardKey.mediaTrackPrevious ||
            key == LogicalKeyboardKey.browserBack ||
            key == LogicalKeyboardKey.f11)) {
      HapticFeedback.heavyImpact();
      onPrevSong();
      return true;
    }

    // Pedál / klávesnice: mezerník, enter, media play/pause -> play/pause
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.select) {
      HapticFeedback.heavyImpact();
      onToggleScrolling();
      return true;
    }

    // Volume / šipky / page -> BPM
    if (key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.numpad2) {
      HapticFeedback.selectionClick();
      onAdjustBpm(5);
      return true;
    }
    if (key == LogicalKeyboardKey.audioVolumeDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.numpad1) {
      HapticFeedback.selectionClick();
      onAdjustBpm(-5);
      return true;
    }
    // Šipka dolů - náhled dalšího řádku (pedál long = držení posílá opakovaně)
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.numpad5) {
      HapticFeedback.vibrate();
      onAnnounceNext();
      return true;
    }

    return false;
  }

  static final RegExp _sectionLabelReg = RegExp(
    r'^\s*(sloka\s*\d*|refr[eé]n|chorus|verse\s*\d*|bridge|s[oó]lo|mezihra|předehra|dohr[áa]vka|intro|outro|capo\s*\d*.*)\s*[:\-]?\s*$',
    caseSensitive: false,
  );

  bool _isFilteredLine(List<ChordProElement> line, {required bool filterSectionLabels, required bool filterChordsOnly}) {
    final raw = ChordProParser.lineText(line);
    final trimmed = raw.trim();
    if (filterSectionLabels && _sectionLabelReg.hasMatch(trimmed)) return true;
    if (line.any((e) => e.type == ElementType.comment)) return true;
    if (line.any((e) => e.type == ElementType.stopMark)) return true;
    final hasText = line.any((e) => e.type == ElementType.text && e.content.trim().isNotEmpty);
    final hasChord = line.any((e) => e.type == ElementType.chord);
    if (filterChordsOnly && hasChord && !hasText) return true;
    if (!hasText && trimmed.isEmpty) return true;
    // Prázdný text po ořezu (např. jen "[C]") už pokryt výše, ale jistota:
    if (trimmed.isEmpty) return true;
    return false;
  }

  String _announcementForLine(List<ChordProElement> line) {
    final text = ChordProParser.lineText(line);
    final chords = line.where((e) => e.type == ElementType.chord).map((e) => e.content).join(' ');
    if (chords.isNotEmpty && text.isNotEmpty) return '$chords, $text';
    if (chords.isNotEmpty) return chords;
    return text;
  }

  /// Sestaví text pro TTS náhled dalšího řádku.
  /// Vrací text a skutečný index ohlášeného řádku, null pokud není co hlásit.
  /// [startIndexOverride] umožňuje ručnímu režimu postupovat kurzorem po řádcích.
  ({String text, int index})? buildNextLineAnnouncement({
    required String? loadedContent,
    required int? topVisibleLineIndex,
    required Map<int, double> lineOffsets,
    int? startIndexOverride,
    bool filterSectionLabels = true,
    bool filterChordsOnly = true,
  }) {
    final res = buildNextLinesAnnouncement(
      loadedContent: loadedContent,
      topVisibleLineIndex: topVisibleLineIndex,
      lineOffsets: lineOffsets,
      startIndexOverride: startIndexOverride,
      count: 1,
      filterSectionLabels: filterSectionLabels,
      filterChordsOnly: filterChordsOnly,
    );
    if (res == null) return null;
    return (text: res.texts.first, index: res.indices.first);
  }

  /// Sestaví 2-3 filtrované řádky pro náhled.
  /// Vrací null pokud není co hlásit.
  ({List<String> texts, List<int> indices, int lastIndex})? buildNextLinesAnnouncement({
    required String? loadedContent,
    required int? topVisibleLineIndex,
    required Map<int, double> lineOffsets,
    int? startIndexOverride,
    int count = 2,
    bool filterSectionLabels = true,
    bool filterChordsOnly = true,
  }) {
    if (loadedContent == null || loadedContent.isEmpty) return null;
    final lines = ChordProParser.orderedLines(loadedContent);
    if (lines.isEmpty) return null;

    int nextIndex;
    if (startIndexOverride != null) {
      nextIndex = startIndexOverride;
    } else if (topVisibleLineIndex != null) {
      nextIndex = topVisibleLineIndex + 1;
    } else {
      nextIndex = 0;
    }

    if (nextIndex >= lines.length) return null;

    final texts = <String>[];
    final indices = <int>[];

    while (nextIndex < lines.length && texts.length < count) {
      final line = lines[nextIndex];
      if (_isFilteredLine(line, filterSectionLabels: filterSectionLabels, filterChordsOnly: filterChordsOnly)) {
        nextIndex++;
        continue;
      }
      final announcement = _announcementForLine(line).trim();
      if (announcement.isEmpty) {
        nextIndex++;
        continue;
      }
      texts.add(announcement);
      indices.add(nextIndex);
      nextIndex++;
    }

    if (texts.isEmpty) return null;
    return (texts: texts, indices: indices, lastIndex: indices.last);
  }

  /// Zavolá TTS pro další řádek, s haptikou a ochranou proti duplicitám v auto režimu.
  /// Vrací index ohlášeného řádku, nebo null pokud nebylo co hlásit (konec textu).
  Future<int?> announceNextLine({
    required String? loadedContent,
    required int? topVisibleLineIndex,
    required Map<int, double> lineOffsets,
    required bool isAutomatic,
    int? startIndexOverride,
    bool filterSectionLabels = true,
    bool filterChordsOnly = true,
  }) async {
    final result = buildNextLineAnnouncement(
      loadedContent: loadedContent,
      topVisibleLineIndex: topVisibleLineIndex,
      lineOffsets: lineOffsets,
      startIndexOverride: startIndexOverride,
      filterSectionLabels: filterSectionLabels,
      filterChordsOnly: filterChordsOnly,
    );
    if (result == null) {
      await tts.stop();
      await tts.speak(AppStrings.nextLineEmpty);
      HapticFeedback.mediumImpact();
      return null;
    }

    // V automatickém režimu neopakovat stejný řádek
    if (isAutomatic && result.index == _lastAnnouncedIndex) return result.index;

    if (isAutomatic) _lastAnnouncedIndex = result.index;

    await tts.stop();
    HapticFeedback.vibrate();
    await tts.speak(AppStrings.nextLineAnnouncement(result.text));
    return result.index;
  }

  /// Ohlásí 2-3 řádky najednou (ruční i automatický náhled).
  /// Vrací lastIndex nebo null.
  Future<int?> announceNextLines({
    required String? loadedContent,
    required int? topVisibleLineIndex,
    required Map<int, double> lineOffsets,
    required bool isAutomatic,
    int? startIndexOverride,
    int count = 2,
    bool filterSectionLabels = true,
    bool filterChordsOnly = true,
  }) async {
    final result = buildNextLinesAnnouncement(
      loadedContent: loadedContent,
      topVisibleLineIndex: topVisibleLineIndex,
      lineOffsets: lineOffsets,
      startIndexOverride: startIndexOverride,
      count: count,
      filterSectionLabels: filterSectionLabels,
      filterChordsOnly: filterChordsOnly,
    );
    if (result == null) {
      await tts.stop();
      await tts.speak(AppStrings.nextLineEmpty);
      HapticFeedback.mediumImpact();
      return null;
    }

    if (isAutomatic && result.lastIndex == _lastAnnouncedIndex) return result.lastIndex;
    if (isAutomatic) _lastAnnouncedIndex = result.lastIndex;

    await tts.stop();
    HapticFeedback.vibrate();
    await tts.speak(AppStrings.nextLinesAnnouncement(result.texts));
    return result.lastIndex;
  }

  /// Pro automatiku: zkontroluj zda se blíží další řádek (časově).
  bool shouldAutoAnnounce({
    required double nextLineOffset,
    required double currentOffset,
    required double effectiveBpm,
    required double fontSize,
  }) {
    final deltaPx = nextLineOffset - currentOffset;
    if (deltaPx <= 0 || deltaPx > 600) return false;
    final pixelsPerBeat = (fontSize * 1.5) / 4.0;
    if (pixelsPerBeat <= 0 || effectiveBpm <= 0) return false;
    final beats = deltaPx / pixelsPerBeat;
    final seconds = beats * 60.0 / effectiveBpm;
    // Ohlásit 2.5s předem (dle dohody)
    return seconds <= 2.5 && seconds > 0.3;
  }
}
