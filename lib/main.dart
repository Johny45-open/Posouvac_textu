import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' show InsertMode;
import 'database.dart';
import 'tuner.dart';
import 'library_page.dart';
import 'chord_display_widget.dart';
import 'manual_page.dart';
import 'app_strings.dart';
import 'sharing_handler.dart';
import 'nearby_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final prefs = await SharedPreferences.getInstance();
  SharingHandler.init(db: db, navigatorKey: navigatorKey);
  NearbyService.instance.init(db: db, navKey: navigatorKey);
  runApp(LyricScrollerApp(db: db, prefs: prefs));
}

class Song {
  static const unknownArtist = 'Neznámý interpret';

  final String title;
  final String content;
  final String artist;
  double? scrollSpeed;
  double? bpm;
  double beatsPerLine;
  String? language;
  bool isFavorite;
  int startDelay;
  bool isVocalStart;

  Song({
    required this.title,
    required this.content,
    String? artist,
    this.scrollSpeed,
    this.bpm,
    this.beatsPerLine = 4.0,
    this.language,
    this.isFavorite = false,
    this.startDelay = 0,
    this.isVocalStart = false,
  }) : artist = normalizeArtist(artist);

  factory Song.fromImportedTextFile({
    required String fileName,
    required String content,
  }) {
    final parsed = parseImportedFileName(fileName);
    return Song(title: parsed.title, content: content, artist: parsed.artist);
  }

  static String normalizeArtist(Object? value) {
    if (value is! String) return unknownArtist;
    final trimmed = value.trim();
    return trimmed.isEmpty ? unknownArtist : trimmed;
  }

  static ({String title, String? artist}) parseImportedFileName(
    String fileName,
  ) {
    final baseName = p.basenameWithoutExtension(fileName).trim();
    var separator = RegExp(r'\s+[-–—]\s+').firstMatch(baseName);
    if (separator == null) {
      final all = RegExp(r'\s*[-–—]\s*').allMatches(baseName).toList();
      if (all.isNotEmpty) separator = all.last;
    }

    if (separator == null) return (title: baseName, artist: null);

    final artist = baseName.substring(0, separator.start).trim();
    final title = baseName.substring(separator.end).trim();

    if (artist.isEmpty || title.isEmpty) {
      return (title: baseName, artist: null);
    }

    return (title: title, artist: artist);
  }

  /// Varianta B: priorita filename `Interpret - Název`, fallback první řádek.
  static ({String title, String artist}) deriveMetadataFromFile(
    String filePath,
    String content,
  ) {
    final parsed = parseImportedFileName(filePath);
    if (parsed.artist != null) {
      return (title: parsed.title, artist: parsed.artist!);
    }
    final firstLine = content.split('\n').isNotEmpty
        ? content.split('\n').first.trim()
        : '';
    final title = (firstLine.isNotEmpty && firstLine.length < 50)
        ? firstLine
        : parsed.title;
    return (title: title, artist: normalizeArtist(parsed.artist));
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'artist': artist,
    'scrollSpeed': scrollSpeed,
    'bpm': bpm,
    'beatsPerLine': beatsPerLine,
    'language': language,
    'isFavorite': isFavorite,
    'startDelay': startDelay,
    'isVocalStart': isVocalStart,
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    title: json['title'],
    content: json['content'],
    artist: json['artist'],
    scrollSpeed: json['scrollSpeed']?.toDouble(),
    bpm: json['bpm']?.toDouble(),
    beatsPerLine: json['beatsPerLine']?.toDouble() ?? 4.0,
    language: json['language'],
    isFavorite: json['isFavorite'] ?? false,
    startDelay: json['startDelay'] ?? 0,
    isVocalStart: json['isVocalStart'] ?? false,
  );
}

class LyricScrollerApp extends StatefulWidget {
  final AppDatabase db;
  final SharedPreferences prefs;
  const LyricScrollerApp({super.key, required this.db, required this.prefs});
  @override
  State<LyricScrollerApp> createState() => _LyricScrollerAppState();
}

class _LyricScrollerAppState extends State<LyricScrollerApp> {
  late ThemeMode _themeMode;
  late double _fontSize;
  late double _scrollSpeed;
  late bool _useMonospace;
  late double _beepFrequency;
  late int _defaultStartDelay;
  late bool _isInformalMode;
  late bool _concertMode;
  late int _concertPreviewMode; // 0=off, 1=onDemand, 2=auto
  late bool _concertTrainingMode;
  late int _concertZonesMode; // 0=vždy aktivní, 1=na požádání
  late int _setlistDelay; // 3,5,10,-1
  late int _previewLineCount; // 2/3
  late bool _filterSectionLabels;
  late bool _enableMetronome;
  late bool _autoOpenReceived;
  late bool _nearbyAutoReceive;
  Locale? _locale;
  bool _showManual = false;

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeMode.values[widget.prefs.getInt('themeMode') ?? 2];
    _fontSize = widget.prefs.getDouble('fontSize') ?? 24.0;
    _scrollSpeed = widget.prefs.getDouble('scrollSpeed') ?? 1.0;
    _useMonospace = widget.prefs.getBool('useMonospace') ?? false;
    _beepFrequency = widget.prefs.getDouble('beepFrequency') ?? 800.0;
    _defaultStartDelay = widget.prefs.getInt('defaultStartDelay') ?? 3;
    _isInformalMode = widget.prefs.getBool('isInformalMode') ?? false;
    AppStrings.isInformal = _isInformalMode;
    _concertMode = widget.prefs.getBool('concertMode') ?? false;
    _concertPreviewMode = widget.prefs.getInt('concertPreviewMode') ?? 1;
    _concertTrainingMode = widget.prefs.getBool('concertTrainingMode') ?? false;
    _concertZonesMode = widget.prefs.getInt('concertZonesMode') ?? 0;
    _setlistDelay = widget.prefs.getInt('setlistDelay') ?? 5;
    _previewLineCount = widget.prefs.getInt('previewLineCount') ?? 2;
    _filterSectionLabels = widget.prefs.getBool('filterSectionLabels') ?? true;
    _enableMetronome = widget.prefs.getBool('enableMetronome') ?? true;
    _autoOpenReceived = widget.prefs.getBool('autoOpenReceived') ?? false;
    _nearbyAutoReceive = widget.prefs.getBool('nearbyAutoReceive') ?? true;
    
    final langCode = widget.prefs.getString('languageCode');
    if (langCode != null) _locale = Locale(langCode);

    _showManual = !(widget.prefs.getBool('manual_shown') ?? false);
  }

  void _hideManual() {
    setState(() => _showManual = false);
  }

  void _openManual() {
    setState(() => _showManual = true);
  }

  Future<void> _updateThemeMode(ThemeMode m) async {
    setState(() => _themeMode = m);
    await widget.prefs.setInt('themeMode', m.index);
  }

  void _updateInformalMode(bool v) {
    setState(() {
      _isInformalMode = v;
      AppStrings.isInformal = v;
    });
    widget.prefs.setBool('isInformalMode', v);
  }

  Future<void> _updateFontSize(double s) async {
    setState(() => _fontSize = s);
    await widget.prefs.setDouble('fontSize', s);
  }

  Future<void> _updateScrollSpeed(double s) async {
    setState(() => _scrollSpeed = s);
    await widget.prefs.setDouble('scrollSpeed', s);
  }

  Future<void> _updateMonospace(bool v) async {
    setState(() => _useMonospace = v);
    await widget.prefs.setBool('useMonospace', v);
  }

  Future<void> _updateLocale(Locale? l) async {
    setState(() => _locale = l);
    if (l == null)
      await widget.prefs.remove('languageCode');
    else
      await widget.prefs.setString('languageCode', l.languageCode);
  }

  Future<void> _updateBeepFrequency(double f) async {
    setState(() => _beepFrequency = f);
    await widget.prefs.setDouble('beepFrequency', f);
  }

  Future<void> _updateDefaultStartDelay(int d) async {
    setState(() => _defaultStartDelay = d);
    await widget.prefs.setInt('defaultStartDelay', d);
  }

  Future<void> _updateConcertMode(bool v) async {
    setState(() => _concertMode = v);
    await widget.prefs.setBool('concertMode', v);
  }

  Future<void> _updateConcertPreviewMode(int mode) async {
    setState(() => _concertPreviewMode = mode);
    await widget.prefs.setInt('concertPreviewMode', mode);
  }

  Future<void> _updateConcertTrainingMode(bool v) async {
    setState(() => _concertTrainingMode = v);
    await widget.prefs.setBool('concertTrainingMode', v);
  }

  Future<void> _updateConcertZonesMode(int mode) async {
    setState(() => _concertZonesMode = mode);
    await widget.prefs.setInt('concertZonesMode', mode);
  }

  Future<void> _updateSetlistDelay(int delay) async {
    setState(() => _setlistDelay = delay);
    await widget.prefs.setInt('setlistDelay', delay);
  }

  Future<void> _updatePreviewLineCount(int count) async {
    final v = (count == 3) ? 3 : 2;
    setState(() => _previewLineCount = v);
    await widget.prefs.setInt('previewLineCount', v);
  }

  Future<void> _updateFilterSectionLabels(bool v) async {
    setState(() => _filterSectionLabels = v);
    await widget.prefs.setBool('filterSectionLabels', v);
  }

  Future<void> _updateEnableMetronome(bool v) async {
    setState(() => _enableMetronome = v);
    await widget.prefs.setBool('enableMetronome', v);
  }

  Future<void> _updateAutoOpenReceived(bool v) async {
    setState(() => _autoOpenReceived = v);
    await widget.prefs.setBool('autoOpenReceived', v);
  }

  Future<void> _updateNearbyAutoReceive(bool v) async {
    setState(() => _nearbyAutoReceive = v);
    await widget.prefs.setBool('nearbyAutoReceive', v);
    if (v) {
      NearbyService.instance.startAdvertising();
    } else {
      NearbyService.instance.stopAdvertising();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posouvač textu',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
      ),
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('cs', 'CZ'), Locale('en', 'US')],
      home: _showManual
          ? ManualPage(onFinished: _hideManual)
          : LibraryPage(
              themeMode: _themeMode,
              onThemeModeChanged: _updateThemeMode,
              db: widget.db,
              onOpenManual: _openManual,
              isInformalMode: _isInformalMode,
              onInformalModeChanged: _updateInformalMode,
              concertMode: _concertMode,
              onConcertModeChanged: _updateConcertMode,
              concertPreviewMode: _concertPreviewMode,
              onConcertPreviewModeChanged: _updateConcertPreviewMode,
              concertTrainingMode: _concertTrainingMode,
              onConcertTrainingModeChanged: _updateConcertTrainingMode,
              concertZonesMode: _concertZonesMode,
              onConcertZonesModeChanged: _updateConcertZonesMode,
              setlistDelay: _setlistDelay,
              onSetlistDelayChanged: _updateSetlistDelay,
              previewLineCount: _previewLineCount,
              onPreviewLineCountChanged: _updatePreviewLineCount,
              filterSectionLabels: _filterSectionLabels,
              onFilterSectionLabelsChanged: _updateFilterSectionLabels,
              enableMetronome: _enableMetronome,
              onEnableMetronomeChanged: _updateEnableMetronome,
              autoOpenReceived: _autoOpenReceived,
              onAutoOpenReceivedChanged: _updateAutoOpenReceived,
              nearbyAutoReceive: _nearbyAutoReceive,
              onNearbyAutoReceiveChanged: _updateNearbyAutoReceive,
            ),
    );
  }
}
