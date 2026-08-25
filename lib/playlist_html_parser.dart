import 'dart:convert';

/// Jednoduchý parser pro HTML export playlistů (vytvořený v song_export.dart).
Map<String, dynamic> parsePlaylistHtml(String html) {
  // 1. Získání názvu playlistu z title
  final nameMatch = RegExp(r'<title>(.*?) – setlist</title>').firstMatch(html);
  final name = nameMatch?.group(1) ?? 'Importovaný setlist';

  // 2. Extrakce řádků tabulky z tbody
  final tbodyMatch = RegExp(r'<tbody>(.*?)</tbody>', dotAll: true).firstMatch(html);
  if (tbodyMatch == null) return {'name': name, 'songs': [], 'version': 2};

  final rowRegex = RegExp(r'<tr>(.*?)</tr>', dotAll: true);
  final rows = rowRegex.allMatches(tbodyMatch.group(1)!);

  List<Map<String, dynamic>> songs = [];
  for (final row in rows) {
    final cells = RegExp(r'<td.*?>(.*?)</td>', dotAll: true)
        .allMatches(row.group(1)!)
        .toList();
    if (cells.length < 5) continue;

    final artist = _unescape(cells[1].group(1)!.trim());
    final title = _unescape(cells[2].group(1)!.trim());
    final durationStr = cells[3].group(1)!.trim();
    final tempoStr = cells[4].group(1)!.trim();

    // Délka: m:ss nebo ?
    int? duration;
    if (!durationStr.contains('unknown')) {
      final parts = durationStr.split(':');
      if (parts.length == 2) {
        duration = int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;
      }
    }

    // Tempo: BPM nebo —
    double? tempo;
    if (!tempoStr.contains('unknown')) {
      tempo = double.tryParse(tempoStr.replaceAll(' BPM', ''));
    }

    songs.add({
      'title': title,
      'artist': artist,
      'duration': duration,
      'tempo': tempo,
    });
  }
  return {'name': name, 'songs': songs, 'version': 2};
}

String _unescape(String input) => input
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");
