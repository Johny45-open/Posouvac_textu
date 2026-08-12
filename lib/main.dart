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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final prefs = await SharedPreferences.getInstance();
  SharingHandler.init(db: db, navigatorKey: navigatorKey);
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
    final separator = RegExp(r'\s+[-–—]\s+').firstMatch(baseName);

    if (separator == null) return (title: baseName, artist: null);

    final artist = baseName.substring(0, separator.start).trim();
    final title = baseName.substring(separator.end).trim();

    if (artist.isEmpty || title.isEmpty) {
      return (title: baseName, artist: null);
    }

    return (title: title, artist: artist);
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
  Locale? _locale;
  bool _showManual = false;

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeMode.values[widget.prefs.getInt('themeMode') ?? 0];
    _fontSize = widget.prefs.getDouble('fontSize') ?? 24.0;
    _scrollSpeed = widget.prefs.getDouble('scrollSpeed') ?? 1.0;
    _useMonospace = widget.prefs.getBool('useMonospace') ?? false;
    _beepFrequency = widget.prefs.getDouble('beepFrequency') ?? 800.0;
    _defaultStartDelay = widget.prefs.getInt('defaultStartDelay') ?? 3;
    _isInformalMode = widget.prefs.getBool('isInformalMode') ?? false;
    AppStrings.isInformal = _isInformalMode;
    
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
            ),
    );
  }
}
