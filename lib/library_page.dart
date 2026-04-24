import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'song_model.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final FlutterTts _tts = FlutterTts();
  List<Song> _songs = [];
  Map<String, int> _alphabetIndex = {};

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
  }

  Future<void> _scanFolder() async {
    String? path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;

    final dir = Directory(path);
    final List<FileSystemEntity> files = dir.listSync(recursive: true);
    List<Song> loadedSongs = [];

    for (var file in files) {
      if (file is File && (file.path.endsWith('.mp3') || file.path.endsWith('.m4a'))) {
        final metadata = await readMetadata(file, getImage: false);
        loadedSongs.add(Song(
          artist: metadata.artist ?? "Neznámý interpret",
          title: metadata.title ?? "Neznámý název",
          filePath: file.path,
        ));
      }
    }

    loadedSongs.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    
    Map<String, int> index = {};
    for (int i = 0; i < loadedSongs.length; i++) {
      String letter = loadedSongs[i].artist[0].toUpperCase();
      if (!index.containsKey(letter)) {
        index[letter] = i;
      }
    }

    setState(() {
      _songs = loadedSongs;
      _alphabetIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Knihovna")),
      body: ListView.builder(
        itemCount: _songs.length,
        itemBuilder: (context, index) {
          final song = _songs[index];
          return ListTile(
            title: Text("${song.artist} - ${song.title}"),
            onTap: () => _tts.speak("${song.artist}, ${song.title}"),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanFolder,
        child: const Icon(Icons.folder_open),
      ),
    );
  }
}
