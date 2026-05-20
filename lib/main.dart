import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'tuner.dart';
import 'library_page.dart';
import 'chord_display_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(LyricScrollerApp(prefs: prefs));
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
  final SharedPreferences prefs;
  const LyricScrollerApp({super.key, required this.prefs});
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
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeMode.values[widget.prefs.getInt('themeMode') ?? 0];
    _fontSize = widget.prefs.getDouble('fontSize') ?? 24.0;
    _scrollSpeed = widget.prefs.getDouble('scrollSpeed') ?? 1.0;
    _useMonospace = widget.prefs.getBool('useMonospace') ?? false;
    _beepFrequency = widget.prefs.getDouble('beepFrequency') ?? 800.0;
    _defaultStartDelay = widget.prefs.getInt('defaultStartDelay') ?? 3;
    final langCode = widget.prefs.getString('languageCode');
    if (langCode != null) _locale = Locale(langCode);
  }

  Future<void> _updateThemeMode(ThemeMode m) async {
    setState(() => _themeMode = m);
    await widget.prefs.setInt('themeMode', m.index);
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
      home: ScrollerHomePage(
        prefs: widget.prefs,
        fontSize: _fontSize,
        scrollSpeed: _scrollSpeed,
        themeMode: _themeMode,
        useMonospace: _useMonospace,
        locale: _locale,
        startDelay: _defaultStartDelay,
        onFontSizeChanged: _updateFontSize,
        onScrollSpeedChanged: _updateScrollSpeed,
        onThemeModeChanged: _updateThemeMode,
        onMonospaceChanged: _updateMonospace,
        onLocaleChanged: _updateLocale,
        onBeepFrequencyChanged: _updateBeepFrequency,
        onStartDelayChanged: _updateDefaultStartDelay,
      ),
    );
  }
}

class ScrollerHomePage extends StatefulWidget {
  final SharedPreferences prefs;
  final double fontSize;
  final double scrollSpeed;
  final ThemeMode themeMode;
  final bool useMonospace;
  final Locale? locale;
  final int startDelay;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onScrollSpeedChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<bool> onMonospaceChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final ValueChanged<double> onBeepFrequencyChanged;
  final ValueChanged<int> onStartDelayChanged;
  const ScrollerHomePage({
    super.key,
    required this.prefs,
    required this.fontSize,
    required this.scrollSpeed,
    required this.themeMode,
    required this.useMonospace,
    required this.locale,
    required this.startDelay,
    required this.onFontSizeChanged,
    required this.onScrollSpeedChanged,
    required this.onThemeModeChanged,
    required this.onMonospaceChanged,
    required this.onLocaleChanged,
    required this.onBeepFrequencyChanged,
    required this.onStartDelayChanged,
  });
  @override
  State<ScrollerHomePage> createState() => _ScrollerHomePageState();
}

class _ScrollerHomePageState extends State<ScrollerHomePage> {
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _flutterTts = FlutterTts();

  List<Song> _playlist = [];
  int _currentSongIndex = -1;
  bool _isScrolling = false;
  bool _onlyFavorites = false;
  String _searchQuery = "";
  String? _artistFilter;
  Timer? _timer;
  int _countdownRemaining = 0;
  Timer? _countdownTimer;
  bool _isGoSignal = false;
  bool _isPulseActive = false;
  List<DateTime> _tapTimes = [];

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadPlaylist();
  }

  @override
  void dispose() {
    _stopScrolling();
    _scrollController.dispose();
    _flutterTts.stop();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  int _songCountForArtist(String artist) {
    return _playlist.where((s) => s.artist == artist).length;
  }

  String _songCountLabel(int count) {
    if (count == 1) return '1 píseň';
    if (count >= 2 && count <= 4) return '$count písně';
    return '$count písní';
  }

  void _onTapTempo(void Function(void Function()) setD) {
    final now = DateTime.now();
    _tapTimes.add(now);
    if (_tapTimes.length > 8) _tapTimes.removeAt(0);
    if (_tapTimes.length >= 2) {
      final double avg =
          _tapTimes.last.difference(_tapTimes.first).inMilliseconds /
          (_tapTimes.length - 1);
      final int bpm = (60000 / avg).round();
      if (_currentSongIndex != -1) {
        setState(() {
          _playlist[_currentSongIndex].bpm = bpm.toDouble();
        });
        _savePlaylist();
        _speak("Tempo $bpm.");
        setD(() {});
      }
    }
  }

  void _syncTempoOnTheFly() {
    final now = DateTime.now();
    _tapTimes.add(now);
    if (_tapTimes.length > 4) _tapTimes.removeAt(0);
    setState(() => _isPulseActive = true);
    Future.delayed(
      const Duration(milliseconds: 100),
      () => setState(() => _isPulseActive = false),
    );
    if (_tapTimes.length >= 2 && _currentSongIndex != -1) {
      final double avg =
          _tapTimes.last.difference(_tapTimes.first).inMilliseconds /
          (_tapTimes.length - 1);
      final int newBpm = (60000 / avg).round();
      if (_playlist[_currentSongIndex].bpm != null) {
        setState(() {
          _playlist[_currentSongIndex].bpm = newBpm.toDouble();
          _startScrolling();
        });
      }
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("cs-CZ");
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _savePlaylist() async {
    final List<String> playlistJson = _playlist
        .map((s) => jsonEncode(s.toJson()))
        .toList();
    await widget.prefs.setStringList('playlist', playlistJson);
    await widget.prefs.setInt('currentSongIndex', _currentSongIndex);
  }

  Future<void> _loadPlaylist() async {
    final List<String>? playlistJson = widget.prefs.getStringList('playlist');
    if (playlistJson != null) {
      setState(() {
        _playlist = playlistJson
            .map((s) => Song.fromJson(jsonDecode(s)))
            .toList();
        int savedIndex = widget.prefs.getInt('currentSongIndex') ?? -1;
        if (savedIndex == -1 && _playlist.isNotEmpty) {
          _currentSongIndex = 0;
        } else {
          _currentSongIndex = savedIndex;
        }
      });
    }
  }

  void _toggleScrolling() {
    if (_countdownRemaining > 0) {
      _countdownTimer?.cancel();
      setState(() {
        _countdownRemaining = 0;
        _isGoSignal = false;
      });
      return;
    }
    bool isAtEnd = false;
    if (_scrollController.hasClients) {
      isAtEnd =
          _scrollController.offset >=
          _scrollController.position.maxScrollExtent - 10;
    }
    if (isAtEnd && !_isScrolling) {
      String n = _getNextSongTitle();
      if (n.isNotEmpty) {
        _speak("Další je $n.");
        _nextSong();
      }
      return;
    }
    if (!_isScrolling) {
      final current =
          _currentSongIndex != -1 && _currentSongIndex < _playlist.length
          ? _playlist[_currentSongIndex]
          : null;
      int delay = (current?.startDelay ?? 0) > 0
          ? current!.startDelay
          : widget.startDelay;
      if (delay > 0) {
        _startCountdown(delay, current?.bpm);
        return;
      }
    }
    setState(() {
      _isScrolling = !_isScrolling;
      if (_isScrolling) {
        _startScrolling();
      } else {
        _stopScrolling();
      }
    });
  }

  void _startCountdown(int a, double? bpm) {
    setState(() {
      _countdownRemaining = a;
      _isGoSignal = false;
      _isPulseActive = true;
    });
    _countdownTimer?.cancel();
    final d = bpm != null && bpm > 0
        ? Duration(milliseconds: (60000 / bpm).round())
        : const Duration(seconds: 1);
    _countdownTimer = Timer.periodic(d, (t) {
      if (_countdownRemaining > 1) {
        setState(() {
          _countdownRemaining--;
          _isPulseActive = true;
        });
        Future.delayed(
          const Duration(milliseconds: 100),
          () => setState(() => _isPulseActive = false),
        );
      } else {
        t.cancel();
        setState(() {
          _countdownRemaining = 0;
          _isGoSignal = true;
          _isPulseActive = true;
        });
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _isGoSignal = false;
              _isPulseActive = false;
              _isScrolling = true;
            });
            _startScrolling();
          }
        });
      }
    });
  }

  void _startScrolling() {
    _timer?.cancel();
    final current = _currentSongIndex != -1
        ? _playlist[_currentSongIndex]
        : null;
    double speed = (current?.bpm != null)
        ? (widget.fontSize * 1.3) /
              ((60.0 / current!.bpm!) * current.beatsPerLine) /
              5.0
        : (current?.scrollSpeed ?? widget.scrollSpeed) *
              (widget.fontSize / 24.0);
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (_scrollController.hasClients) {
        double curr = _scrollController.offset;
        if (curr < _scrollController.position.maxScrollExtent)
          _scrollController.jumpTo(curr + (speed * 0.5));
        else {
          _stopScrolling();
          setState(() {
            _isScrolling = false;
          });
        }
      }
    });
  }

  void _stopScrolling() {
    _timer?.cancel();
    _timer = null;
  }

  void _nextSong() {
    if (_currentSongIndex < _playlist.length - 1) {
      setState(() {
        _currentSongIndex++;
        _isScrolling = false;
        _stopScrolling();
      });
      _savePlaylist();
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );
    if (result != null) {
      List<String> importedTitles = [];
      for (var file in result.files) {
        String content = "";
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!);
        } else if (file.path != null) {
          content = await File(file.path!).readAsString();
        }
        if (content.isNotEmpty) {
          final newSong = Song.fromImportedTextFile(fileName: file.name, content: content);
          setState(() {
            _playlist.add(newSong);
            if (_currentSongIndex == -1) _currentSongIndex = 0;
          });
          importedTitles.add("${newSong.title}${newSong.artist != Song.unknownArtist ? ' od ${newSong.artist}' : ''}");
          _savePlaylist();
          if (context.mounted) {
            _showSetTempoDialog(context, newSong);
          }
        }
      }
      if (importedTitles.isNotEmpty) {
        String msg = "Importováno ${importedTitles.length} ${importedTitles.length == 1 ? 'píseň' : (importedTitles.length < 5 ? 'písně' : 'písní')}: ${importedTitles.join(', ')}.";
        await _speak(msg);
      }
    }
  }

  void _showSetTempoDialog(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tempo pro: ${song.title}'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'BPM'),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final n = double.tryParse(v);
            if (n != null) {
              song.bpm = n;
              _savePlaylist();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _saveNamedPlaylist(BuildContext context) {
    String name = "";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uložit playlist'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Název'),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (name.isNotEmpty) {
                final s = widget.prefs.getStringList('saved_playlists') ?? [];
                if (!s.contains(name)) {
                  s.add(name);
                  await widget.prefs.setStringList('saved_playlists', s);
                }
                await widget.prefs.setStringList(
                  'playlist_$name',
                  _playlist.map((s) => jsonEncode(s.toJson())).toList(),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Uložit'),
          ),
        ],
      ),
    );
  }

  void _loadNamedPlaylist(
    BuildContext context,
    void Function(void Function()) setP,
  ) {
    final s = widget.prefs.getStringList('saved_playlists') ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Moje playlisty'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: s.length,
            itemBuilder: (ctx, i) => ListTile(
              title: Text(s[i]),
              onTap: () {
                final l = widget.prefs.getStringList('playlist_${s[i]}');
                if (l != null) {
                  setState(() {
                    _playlist = l
                        .map((x) => Song.fromJson(jsonDecode(x)))
                        .toList();
                    _currentSongIndex = 0;
                    _artistFilter = null;
                  });
                  _savePlaylist();
                  setP(() {});
                  Navigator.pop(ctx);
                }
              },
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Smazat',
                onPressed: () async {
                  s.removeAt(i);
                  await widget.prefs.setStringList('saved_playlists', s);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  void _showAddManualSongDialog(BuildContext context, VoidCallback onAdded) {
    String t = "";
    String a = "";
    String c = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nová píseň'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Název'),
                onChanged: (v) => t = v,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: 'Interpret'),
                onChanged: (v) => a = v,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Text',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                onChanged: (v) => c = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít'),
          ),
          ElevatedButton(
            onPressed: () {
              if (t.isNotEmpty && c.isNotEmpty) {
                setState(() {
                  _playlist.add(Song(title: t, content: c, artist: a));
                  if (_currentSongIndex == -1)
                    _currentSongIndex = _playlist.length - 1;
                });
                _savePlaylist();
                onAdded();
                Navigator.pop(context);
              }
            },
            child: const Text('Uložit'),
          ),
        ],
      ),
    );
  }

  String _getNextSongTitle() {
    if (_currentSongIndex != -1 && _currentSongIndex < _playlist.length - 1)
      return _playlist[_currentSongIndex + 1].title;
    return "";
  }

  DateTime? _lastTap;
  void _handleTextTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < 1000) {
      if (!_isScrolling) _toggleScrolling();
      _syncTempoOnTheFly();
      _lastTap = now;
      return;
    }
    _lastTap = now;
    _toggleScrolling();
  }

  @override
  Widget build(BuildContext context) {
    Song? s = _currentSongIndex != -1 && _currentSongIndex < _playlist.length
        ? _playlist[_currentSongIndex]
        : null;
    bool end = false;
    if (_scrollController.hasClients) {
      end =
          _scrollController.offset >=
          _scrollController.position.maxScrollExtent - 10;
    }
    String next = _getNextSongTitle();
    String label = _countdownRemaining > 0
        ? 'Zrušit'
        : (_isScrolling
              ? 'Zastavit'
              : (end
                    ? (next.isNotEmpty ? 'DALŠÍ: $next' : 'KONEC')
                    : 'Spustit'));

    return Scaffold(
      appBar: AppBar(
        title: Text(s?.title ?? 'Posouvač'),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note),
            tooltip: 'Ladička',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TunerPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.library_music),
            tooltip: 'Knihovna',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LibraryPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play),
            tooltip: 'Playlist',
            onPressed: () => _showPlaylistDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Nastavení',
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: s == null
          ? Center(
              child: ElevatedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add),
                label: const Text('Importovat texty'),
              ),
            )
          : Stack(
              children: [
                GestureDetector(
                  onTap: _handleTextTap,
                  behavior: HitTestBehavior.opaque,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
                    child: _buildLyricContent(s.content),
                  ),
                ),
                if (_countdownRemaining > 0 || _isGoSignal)
                  Center(
                    child: AnimatedScale(
                      scale: _isPulseActive ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: _isGoSignal
                              ? (s.isVocalStart ? Colors.orange : Colors.green)
                              : Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _isGoSignal
                              ? (s.isVocalStart ? 'ZPĚV!' : 'HRAJ!')
                              : '$_countdownRemaining',
                          style: const TextStyle(
                            fontSize: 100,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  tooltip: 'Předchozí píseň',
                  onPressed: _currentSongIndex > 0
                      ? () {
                          setState(() {
                            _currentSongIndex--;
                            _isScrolling = false;
                            _stopScrolling();
                          });
                          _savePlaylist();
                          if (_scrollController.hasClients)
                            _scrollController.jumpTo(0);
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: 'Posunout nahoru',
                  onPressed: () {
                    if (_scrollController.hasClients)
                      _scrollController.animateTo(
                        (_scrollController.offset - 300).clamp(
                          0,
                          _scrollController.position.maxScrollExtent,
                        ),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                  },
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: 'Posunout dolů',
                  onPressed: () {
                    if (_scrollController.hasClients)
                      _scrollController.animateTo(
                        (_scrollController.offset + 300).clamp(
                          0,
                          _scrollController.position.maxScrollExtent,
                        ),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  tooltip: 'Další píseň',
                  onPressed: _currentSongIndex < _playlist.length - 1
                      ? () {
                          setState(() {
                            _currentSongIndex++;
                            _isScrolling = false;
                            _stopScrolling();
                          });
                          _savePlaylist();
                          if (_scrollController.hasClients)
                            _scrollController.jumpTo(0);
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: s != null
          ? FloatingActionButton.extended(
              backgroundColor: end && !_isScrolling ? Colors.green : null,
              onPressed: _toggleScrolling,
              label: Text(label),
              icon: Icon(
                _countdownRemaining > 0
                    ? Icons.cancel
                    : (_isScrolling ? Icons.pause : Icons.play_arrow),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildLyricContent(String content) {
    return ChordDisplayWidget(
      content: content,
      textStyle: TextStyle(
        fontSize: widget.fontSize,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      chordStyle: TextStyle(
        fontSize: widget.fontSize * 0.9,
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _showPlaylistDialog(BuildContext context) {
    final searchController = TextEditingController(text: _searchQuery);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setP) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (ctx, sc) {
            const allArtistsValue = '__all_artists__';
            final artists = _playlist.map((s) => s.artist).toSet().toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            final activeArtist =
                _artistFilter != null && artists.contains(_artistFilter)
                ? _artistFilter
                : null;

            // Seřadíme seznam abecedně pro snadnější navigaci v dialogu
            final filtered = _playlist
                .where(
                  (s) =>
                      (activeArtist == null || s.artist == activeArtist) &&
                      (!_onlyFavorites || s.isFavorite) &&
                      (_searchQuery.isEmpty ||
                          s.title.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          )),
                )
                .toList();
            filtered.sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            );

            // Vytvoření mapy indexů pro abecedu
            final Map<String, int> indexMap = {};
            for (int i = 0; i < filtered.length; i++) {
              String letter = filtered[i].title.isNotEmpty
                  ? filtered[i].title[0].toUpperCase()
                  : "?";
              if (!indexMap.containsKey(letter)) {
                indexMap[letter] = i;
              }
            }
            final sortedLetters = indexMap.keys.toList()..sort();

            void jumpToLetter(String letter) {
              if (indexMap.containsKey(letter)) {
                int index = indexMap[letter]!;
                sc.animateTo(
                  index * 80.0, // Musí odpovídat itemExtent níže
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
                _speak(
                  "Písmeno $letter. První je ${filtered[index].artist}, ${filtered[index].title}",
                );
              }
            }

            void clearArtistFilter() {
              setState(() {
                _artistFilter = null;
                _searchQuery = "";
                _onlyFavorites = false;
              });
              searchController.clear();
              setP(() {});
              _speak("Zobrazuji všechny interprety.");
            }

            void selectArtist(String artist) {
              if (artist == allArtistsValue) {
                clearArtistFilter();
                return;
              }
              setState(() {
                _artistFilter = artist;
                _searchQuery = "";
                _onlyFavorites = false;
              });
              searchController.clear();
              setP(() {});
              _speak(
                "Interpret $artist, ${_songCountLabel(_songCountForArtist(artist))}.",
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Playlist',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _onlyFavorites
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _onlyFavorites ? Colors.red : null,
                              ),
                              tooltip: 'Oblíbené',
                              onPressed: () {
                                setState(
                                  () => _onlyFavorites = !_onlyFavorites,
                                );
                                setP(() {});
                              },
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                activeArtist == null
                                    ? Icons.person_search
                                    : Icons.person,
                              ),
                              tooltip: 'Filtrovat interpreta',
                              onSelected: selectArtist,
                              itemBuilder: (ctx) => [
                                const PopupMenuItem<String>(
                                  value: allArtistsValue,
                                  child: Text('Všichni interpreti'),
                                ),
                                if (artists.isNotEmpty)
                                  const PopupMenuDivider(),
                                ...artists.map(
                                  (artist) => PopupMenuItem<String>(
                                    value: artist,
                                    child: Text(artist),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.save),
                              tooltip: 'Uložit playlist',
                              onPressed: () => _saveNamedPlaylist(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.folder_special),
                              tooltip: 'Moje playlisty',
                              onPressed: () =>
                                  _loadNamedPlaylist(context, setP),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note),
                              tooltip: 'Přidat ručně',
                              onPressed: () => _showAddManualSongDialog(
                                context,
                                () => setP(() {}),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Přidat soubory',
                              onPressed: () async {
                                await _pickFiles();
                                setP(() {});
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.file_upload),
                              tooltip: 'Export',
                              onPressed: () async {
                                await _exportPlaylist(context);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.file_download),
                              tooltip: 'Import',
                              onPressed: () async {
                                await _importPlaylist(context, setP);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: true,
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Hledat...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                      setP(() {});
                    },
                  ),
                ),
                if (activeArtist != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: const Icon(Icons.person),
                        label: Text(activeArtist),
                        onDeleted: clearArtistFilter,
                      ),
                    ),
                  ),
                if (sortedLetters.isNotEmpty)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sortedLetters.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(sortedLetters[i]),
                          onPressed: () => jumpToLetter(sortedLetters[i]),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: sc,
                    itemExtent: 80.0, // Pevná výška pro přesný skok
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final s = filtered[i];
                      return ListTile(
                        title: Text(s.title),
                        subtitle: Text(s.artist),
                        selected: _currentSongIndex == _playlist.indexOf(s),
                        onTap: () {
                          setState(() {
                            _currentSongIndex = _playlist.indexOf(s);
                            _isScrolling = false;
                          });
                          _speak("${s.artist}, ${s.title}");
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ).whenComplete(searchController.dispose);
  }

  /// Exportuje aktuální playlist a nastavení do JSON souboru.
  Future<void> _exportPlaylist(BuildContext context) async {
    try {
      final exportData = jsonEncode({
        'playlist': _playlist.map((s) => s.toJson()).toList(),
        'currentSongIndex': _currentSongIndex,
        'settings': {
          'fontSize': widget.fontSize,
          'scrollSpeed': widget.scrollSpeed,
          'themeMode': widget.themeMode.index,
          'useMonospace': widget.useMonospace,
          'startDelay': widget.startDelay,
        },
      });

      final bytes = utf8.encode(exportData);
      String? output = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportovat playlist a nastavení',
        fileName: 'posouvac_export.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (output != null) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          final file = File(output);
          await file.writeAsBytes(bytes);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export úspěšný.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await _speak('Export nastavení a playlistu byl úspěšný.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba exportu: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _speak('Chyba při exportu. Zkontrolujte úložiště.');
      }
    }
  }

  /// Importuje playlist a nastavení z JSON souboru.
  Future<void> _importPlaylist(
    BuildContext context,
    void Function(void Function()) setP,
  ) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result != null) {
        final file = result.files.single;
        String content = "";
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!);
        } else if (file.path != null) {
          content = await File(file.path!).readAsString();
        }

        if (content.isEmpty) return;
        final data = jsonDecode(content);

        final List<dynamic> playlistJson = data['playlist'] ?? [];
        setState(() {
          _playlist = playlistJson.map((s) => Song.fromJson(s)).toList();
          _currentSongIndex =
              data['currentSongIndex'] ?? (_playlist.isNotEmpty ? 0 : -1);
          _artistFilter = null;

          if (data['settings'] != null) {
            final s = data['settings'];
            if (s['fontSize'] != null)
              widget.onFontSizeChanged(s['fontSize'].toDouble());
            if (s['scrollSpeed'] != null)
              widget.onScrollSpeedChanged(s['scrollSpeed'].toDouble());
            if (s['themeMode'] != null)
              widget.onThemeModeChanged(ThemeMode.values[s['themeMode']]);
            if (s['useMonospace'] != null)
              widget.onMonospaceChanged(s['useMonospace']);
            if (s['startDelay'] != null)
              widget.onStartDelayChanged(s['startDelay']);
          }
        });
        await _savePlaylist();
        setP(() {});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Import úspěšný.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await _speak('Import nastavení a playlistu proběhl v pořádku.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba importu: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _speak('Chyba při importu. Soubor může být poškozen.');
      }
    }
  }

  void _showSettingsDialog(BuildContext context) {
    final currentSong = _currentSongIndex != -1
        ? _playlist[_currentSongIndex]
        : null;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) {
          final bool isBpm = currentSong?.bpm != null && currentSong!.bpm! > 0;
          final String unit = isBpm ? 'údery' : 's';
          return AlertDialog(
            title: const Text('Nastavení'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(title: Text('Písmo: ${widget.fontSize.round()}')),
                  Slider(
                    value: widget.fontSize,
                    min: 16,
                    max: 100,
                    onChanged: (v) {
                      widget.onFontSizeChanged(v);
                      setD(() {});
                    },
                  ),
                  if (currentSong != null) ...[
                    const Divider(),
                    ListTile(
                      title: const Text('Tempo'),
                      subtitle: Text(isBpm ? 'BPM' : 'Manuální'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: 'BPM',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final n = double.tryParse(v);
                                if (n != null) {
                                  setState(() => currentSong.bpm = n);
                                  _savePlaylist();
                                  setD(() {});
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => currentSong.bpm = 120);
                              _savePlaylist();
                              setD(() {});
                            },
                            child: const Text('120'),
                          ),
                          if (isBpm)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Smazat tempo',
                              onPressed: () {
                                setState(() => currentSong.bpm = null);
                                _savePlaylist();
                                setD(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _onTapTempo(setD),
                      icon: const Icon(Icons.touch_app),
                      label: const Text('TAP TEMPO'),
                    ),
                    SwitchListTile(
                      title: const Text('Zpěv na startu'),
                      value: currentSong.isVocalStart,
                      onChanged: (v) {
                        setState(() => currentSong.isVocalStart = v);
                        _savePlaylist();
                        setD(() {});
                      },
                    ),
                    ListTile(
                      title: Text('Odpočet: ${currentSong.startDelay} $unit'),
                    ),
                    Slider(
                      value: currentSong.startDelay.toDouble(),
                      min: 0,
                      max: 16,
                      divisions: 16,
                      onChanged: (v) {
                        setState(() => currentSong.startDelay = v.round());
                        _savePlaylist();
                        setD(() {});
                      },
                    ),
                  ],
                  const Divider(),
                  ListTile(title: const Text('Motiv')),
                  DropdownButton<ThemeMode>(
                    value: widget.themeMode,
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('Systémový')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Světlý')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Tmavý')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        widget.onThemeModeChanged(v);
                        setD(() {});
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: Text('Globální odpočet: ${widget.startDelay} s'),
                  ),
                  Slider(
                    value: widget.startDelay.toDouble(),
                    min: 0,
                    max: 16,
                    divisions: 16,
                    onChanged: (v) {
                      widget.onStartDelayChanged(v.round());
                      setD(() {});
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zavřít'),
              ),
            ],
          );
        },
      ),
    );
  }
}
