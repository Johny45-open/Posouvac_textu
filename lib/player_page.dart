import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  double _scrollSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  void _toggleScrolling() {
    setState(() => _isScrolling = !_isScrolling);
    if (_isScrolling) {
      _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.offset + (_scrollSpeed * 2));
        }
      });
    } else {
      _scrollTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SongEntry>(
      stream: (widget.db.select(widget.db.songs)..where((s) => s.id.equals(widget.songId))).watchSingle(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold();

        final song = snapshot.data!;

        return Scaffold(
          appBar: AppBar(title: Text(song.title)),
          body: Semantics(
            label: "Text písně ${song.title} od ${song.artist}",
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: ChordDisplayWidget(
                content: "Zde by byl text písně (načtený ze souboru)", // TODO: Načítání obsahu
                textStyle: const TextStyle(fontSize: 20),
                chordStyle: const TextStyle(fontSize: 18, color: Colors.blue),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _toggleScrolling,
            child: Icon(_isScrolling ? Icons.pause : Icons.play_arrow),
          ),
        );
      },
    );
  }
}
