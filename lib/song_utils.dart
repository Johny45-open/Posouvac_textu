import 'package:path/path.dart' as p;

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
