import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'chord_pro_parser.dart';

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
  }) {
    if (!concertMode) return false;
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

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
      HapticFeedback.lightImpact();
      onAnnounceNext();
      return true;
    }

    return false;
  }

  /// Sestaví text pro TTS náhled dalšího řádku.
  /// Vrací null pokud není co hlásit.
  String? buildNextLineAnnouncement({
    required String? loadedContent,
    required int? topVisibleLineIndex,
    required Map<int, double> lineOffsets,
  }) {
    if (loadedContent == null || loadedContent.isEmpty) return null;
    final lines = ChordProParser.orderedLines(loadedContent);
    if (lines.isEmpty) return null;

    int nextIndex;
    if (topVisibleLineIndex != null) {
      nextIndex = topVisibleLineIndex + 1;
    } else if (lineOffsets.isNotEmpty) {
      nextIndex = 0;
    } else {
      nextIndex = 0;
    }

    if (nextIndex >= lines.length) return null;
    // Přeskočit prázdné / stopMark řádky
    while (nextIndex < lines.length) {
      final line = lines[nextIndex];
      final hasRealContent = line.any((e) => e.type == ElementType.text && e.content.trim().isNotEmpty);
      if (hasRealContent) break;
      if (line.any((e) => e.type == ElementType.stopMark)) {
        nextIndex++;
        continue;
      }
      final txt = ChordProParser.lineText(line);
      if (txt.isNotEmpty) break;
      nextIndex++;
    }
    if (nextIndex >= lines.length) return null;

    final line = lines[nextIndex];
    final text = ChordProParser.lineText(line);
    final chords = line.where((e) => e.type == ElementType.chord).map((e) => e.content).join(' ');

    if (text.isEmpty && chords.isEmpty) return null;

    // Sekce (Refrén apod.) - najít sekci obsahující nextIndex
    String? sectionTitle;
    final sections = ChordProParser.parse(loadedContent);
    int cursor = 0;
    for (final s in sections) {
      final len = s.lines.length;
      if (nextIndex >= cursor && nextIndex < cursor + len) {
        sectionTitle = s.title;
        break;
      }
      cursor += len;
    }

    String announcement;
    if (chords.isNotEmpty && text.isNotEmpty) {
      announcement = '$chords, $text';
    } else if (chords.isNotEmpty) {
      announcement = chords;
    } else {
      announcement = text;
    }

    if (sectionTitle != null && sectionTitle.isNotEmpty && sectionTitle != 'Refrén') {
      // Refrén je implicitní, nezahlcujeme
    }

    return announcement.trim().isEmpty ? null : announcement;
  }

  /// Zavolá TTS pro další řádek, s haptikou a ochranou proti duplicitám v auto režimu.
  Future<void> announceNextLine({
    required String? loadedContent,
    required int? topVisibleLineIndex,
    required Map<int, double> lineOffsets,
    required bool isAutomatic,
  }) async {
    final text = buildNextLineAnnouncement(
      loadedContent: loadedContent,
      topVisibleLineIndex: topVisibleLineIndex,
      lineOffsets: lineOffsets,
    );
    if (text == null) {
      await tts.stop();
      await tts.speak('Konec textu');
      HapticFeedback.mediumImpact();
      return;
    }

    // V automatickém režimu neopakovat stejný řádek
    if (isAutomatic) {
      final int nextIdx = topVisibleLineIndex != null ? topVisibleLineIndex + 1 : 0;
      if (nextIdx == _lastAnnouncedIndex) return;
      _lastAnnouncedIndex = nextIdx;
    }

    await tts.stop();
    HapticFeedback.lightImpact();
    // Použij AppStrings prefix pro lokalizaci
    final spoken = text;
    await tts.speak('Další: $spoken');
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
