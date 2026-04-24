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
  final ScrollController _scrollController = ScrollController();
  List<Song> _songs = [];
  Map<String, int> _alphabetIndex = {};

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scanFolder() async {
    String? path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;

    final dir = Directory(path);
    final List<FileSystemEntity> files = dir.listSync(recursive: true);
    List<Song> loadedSongs = [];

    for (var file in files) {
      if (file is File && (file.path.endsWith('.mp3') || file.path.endsWith('.m4a'))) {
        try {
          final metadata = await readMetadata(file, getImage: false);
          loadedSongs.add(Song(
            artist: metadata.artist ?? "Neznámý interpret",
            title: metadata.title ?? "Neznámý název",
            filePath: file.path,
          ));
        } catch (e) {
          debugPrint("Chyba čtení metadat: $e");
        }
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
    
    _tts.speak("Načteno ${_songs.length} skladeb.");
  }

  void _jumpToLetter(String letter) {
    if (_alphabetIndex.containsKey(letter)) {
      int index = _alphabetIndex[letter]!;
      _scrollController.animateTo(
        index * 72.0, // Průměrná výška ListTile
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _tts.speak("Skočeno na písmeno $letter. První je ${_songs[index].artist}");
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> sortedLetters = _alphabetIndex.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text("Knihovna")),
      body: Column(
        children: [
          if (sortedLetters.isNotEmpty)
            Container(
              height: 50,
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sortedLetters.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(sortedLetters[i]),
                      onPressed: () => _jumpToLetter(sortedLetters[i]),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: _songs.isEmpty
                ? const Center(child: Text("Knihovna je prázdná. Vyberte složku."))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _songs.length,
                    itemExtent: 72.0, // Pevná výška pro přesný skok
                    itemBuilder: (context, index) {
                      final song = _songs[index];
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(song.artist),
                        subtitle: Text(song.title),
                        onTap: () => _tts.speak("${song.artist}, ${song.title}"),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanFolder,
        tooltip: "Vybrat složku s hudbou",
        child: const Icon(Icons.folder_open),
      ),
    );
  }
}
