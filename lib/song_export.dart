import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'app_strings.dart';
import 'chord_pro_parser.dart';

/// Maximální délka textu, který se ještě spolehlivě vejde do QR kódu.
const int maxQrContentLength = 1500;

/// Vytvoří samostatný HTML soubor s textem a akordy (funguje offline
/// v libovolném prohlížeči, bez nutnosti mít nainstalovanou aplikaci).
String buildSongHtml({
  required String title,
  required String artist,
  required String content,
}) {
  final sections = ChordProParser.parse(content);
  final buffer = StringBuffer();

  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('<html lang="cs">');
  buffer.writeln('<head>');
  buffer.writeln('<meta charset="UTF-8">');
  buffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
  buffer.writeln('<title>${_escape(title)} - ${_escape(artist)}</title>');
  buffer.writeln('<style>');
  buffer.writeln('  body { font-family: sans-serif; font-size: 22px; line-height: 1.6; margin: 16px; color: #111; }');
  buffer.writeln('  h1 { font-size: 32px; }');
  buffer.writeln('  h2 { font-size: 24px; color: #444; }');
  buffer.writeln('  h3 { font-size: 22px; margin-top: 24px; }');
  buffer.writeln('  .chord { color: #1565c0; font-weight: bold; margin-right: 6px; }');
  buffer.writeln('  .comment { color: #555; font-style: italic; }');
  buffer.writeln('  .stop { color: #c62828; font-weight: bold; }');
  buffer.writeln('  p { margin: 8px 0; }');
  buffer.writeln('</style>');
  buffer.writeln('</head>');
  buffer.writeln('<body>');
  buffer.writeln('<main>');
  buffer.writeln('<h1>${_escape(title)}</h1>');
  buffer.writeln('<h2>${_escape(artist)}</h2>');

  for (final section in sections) {
    if (section.title != null) {
      buffer.writeln('<h3>${_escape(section.title!)}</h3>');
    }
    for (final line in section.lines) {
      buffer.write('<p>');
      for (final element in line) {
        switch (element.type) {
          case ElementType.chord:
            buffer.write('<span class="chord">${_escape(element.content)}</span>');
            break;
          case ElementType.comment:
            buffer.write('<span class="comment">${_escape(element.content)}</span>');
            break;
          case ElementType.stopMark:
            final bars = element.stopMarkBars ?? 0;
            final label = bars > 0 ? 'Pauza $bars taktů' : 'Pauza';
            buffer.write('<span class="stop">[$label]</span>');
            break;
          case ElementType.text:
            buffer.write(_escape(element.content));
            break;
        }
      }
      buffer.writeln('</p>');
    }
  }

  buffer.writeln('</main>');
  buffer.writeln('</body>');
  buffer.writeln('</html>');
  return buffer.toString();
}

/// Balíček písně pro jinou instalaci aplikace Posouvač textu.
/// Obsahuje název, interpreta a samotný text, takže ho příjemce
/// (i bez internetu) naimportuje přímo do knihovny.
String buildSongPackageJson({
  required String title,
  required String artist,
  required String content,
}) {
  return jsonEncode({
    'type': 'song',
    'version': 1,
    'title': title,
    'artist': artist,
    'content': content,
  });
}

/// Balíček setlistu – názvy, interpreti, časy, volitelně texty a zarážky (v3).
String buildPlaylistPackageJson({
  required String name,
  required List<Map<String, dynamic>> songs,
  required int totalDuration,
  required int unknownCount,
  String? exportedAt,
}) {
  return jsonEncode({
    'type': 'playlist',
    'version': 3,
    'name': name,
    'exportedAt': exportedAt ?? DateTime.now().toIso8601String(),
    'totalDuration': totalDuration,
    'unknownCount': unknownCount,
    'songs': songs,
  });
}

/// HTML přehled setlistu s tabulkou časů – funguje offline v prohlížeči.
String buildPlaylistHtml({
  required String name,
  required List<Map<String, dynamic>> songs,
  required int totalDuration,
  required int unknownCount,
}) {
  final buffer = StringBuffer();
  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('<html lang="cs">');
  buffer.writeln('<head>');
  buffer.writeln('<meta charset="UTF-8">');
  buffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
  buffer.writeln('<title>${_escape(name)} – setlist</title>');
  buffer.writeln('<style>');
  buffer.writeln('  body { font-family: sans-serif; font-size: 18px; line-height: 1.5; margin: 16px; color: #111; }');
  buffer.writeln('  h1 { font-size: 28px; margin-bottom: 4px; }');
  buffer.writeln('  .meta { color: #555; margin-bottom: 16px; }');
  buffer.writeln('  table { width: 100%; border-collapse: collapse; }');
  buffer.writeln('  th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }');
  buffer.writeln('  th { background: #f0f0f0; }');
  buffer.writeln('  .dur { text-align: right; white-space: nowrap; }');
  buffer.writeln('  .unknown { color: #c62828; }');
  buffer.writeln('</style>');
  buffer.writeln('</head>');
  buffer.writeln('<body>');
  buffer.writeln('<main>');
  buffer.writeln('<h1>${_escape(name)}</h1>');
  final totalMin = totalDuration ~/ 60;
  final totalSec = totalDuration % 60;
  final timeLabel = unknownCount == 0
      ? 'Celkový čas: $totalMin min ${totalSec.toString().padLeft(2, '0')} s'
      : 'Celkový čas: $totalMin min ${totalSec.toString().padLeft(2, '0')} s + $unknownCount bez času (odhad +${unknownCount * 3} min)';
  buffer.writeln('<p class="meta">${_escape(timeLabel)} • ${songs.length} písní</p>');
  buffer.writeln('<table>');
  buffer.writeln('<caption>Seznam písní v setlistu ${_escape(name)}</caption>');
  buffer.writeln('<thead><tr><th scope="col">#</th><th scope="col">Interpret</th><th scope="col">Název</th><th scope="col" class="dur">Délka</th><th scope="col" class="dur">Tempo</th></tr></thead>');
  buffer.writeln('<tbody>');
  for (var i = 0; i < songs.length; i++) {
    final s = songs[i];
    final artist = _escape((s['artist'] ?? '').toString());
    final title = _escape((s['title'] ?? '').toString());
    final dur = s['duration'] as int?;
    final durText = (dur != null && dur > 0) ? '${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}' : '<span class="unknown">?</span>';
    final tempoVal = s['tempo'];
    double? tempo;
    if (tempoVal is num) tempo = tempoVal.toDouble();
    else if (tempoVal is String) tempo = double.tryParse(tempoVal);
    final tempoText = tempo != null ? '${tempo.round()} BPM' : '<span class="unknown">—</span>';
    buffer.writeln('<tr><td>${i + 1}</td><td>$artist</td><td>$title</td><td class="dur">$durText</td><td class="dur">$tempoText</td></tr>');
  }
  buffer.writeln('</tbody></table>');
  buffer.writeln('</main>');
  buffer.writeln('</body>');
  buffer.writeln('</html>');
  return buffer.toString();
}

String _escape(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// Otevře dialog s výběrem formy sdílení a provede zvolenou akci.
/// Volá se z přehrávače i z knihovny.
Future<void> showSongShareDialog(
  BuildContext context, {
  required String title,
  required String artist,
  required String content,
}) async {
  final tts = FlutterTts();
  await tts.setLanguage("cs-CZ");
  await tts.setSpeechRate(0.5);

  final choice = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Semantics(header: true, child: Text(AppStrings.shareTitle)),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'html'),
          child: _ShareOption(
            title: AppStrings.shareHtmlLabel,
            description: AppStrings.shareHtmlDescription,
            icon: Icons.public,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'qr'),
          child: _ShareOption(
            title: AppStrings.shareQrLabel,
            description: AppStrings.shareQrDescription,
            icon: Icons.qr_code,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'package'),
          child: _ShareOption(
            title: AppStrings.sharePackageLabel,
            description: AppStrings.sharePackageDescription,
            icon: Icons.apps,
          ),
        ),
      ],
    ),
  );

  if (choice == null || !context.mounted) return;

  switch (choice) {
    case 'html':
      await _shareHtml(context, tts, title: title, artist: artist, content: content);
      break;
    case 'qr':
      await _showQrDialog(context, tts, title: title, artist: artist, content: content);
      break;
    case 'package':
      await _sharePackage(context, tts, title: title, artist: artist, content: content);
      break;
  }
}

Future<void> _shareHtml(
  BuildContext context,
  FlutterTts tts, {
  required String title,
  required String artist,
  required String content,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pisen_${_safeName(title)}.html');
    await file.writeAsString(
      buildSongHtml(title: title, artist: artist, content: content),
      encoding: utf8,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/html')],
      text: AppStrings.shareHtmlText(title),
    );
    tts.speak(AppStrings.shareHtmlDone);
  } catch (e) {
    _announceError(context, tts, e);
  }
}

Future<void> _sharePackage(
  BuildContext context,
  FlutterTts tts, {
  required String title,
  required String artist,
  required String content,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pisen_${_safeName(title)}.json');
    await file.writeAsString(
      buildSongPackageJson(title: title, artist: artist, content: content),
      encoding: utf8,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: AppStrings.sharePackageText(title),
    );
    tts.speak(AppStrings.sharePackageDone);
  } catch (e) {
    _announceError(context, tts, e);
  }
}

Future<void> _showQrDialog(
  BuildContext context,
  FlutterTts tts, {
  required String title,
  required String artist,
  required String content,
}) async {
  final packageJson =
      buildSongPackageJson(title: title, artist: artist, content: content);
  if (packageJson.length > maxQrContentLength) {
    tts.speak(AppStrings.shareQrTooLong);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppStrings.shareQrTooLong)));
    }
    return;
  }

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Semantics(header: true, child: Text(AppStrings.shareQrDialogTitle)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Semantics(
                label: AppStrings.shareQrSemantics(title, artist),
                image: true,
                child: QrImageView(
                  data: packageJson,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.shareQrTextLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                child: SelectableText(content),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Zavřít"),
        ),
      ],
    ),
  );
}

Future<void> showPlaylistShareDialog(
  BuildContext context, {
  required String playlistName,
  required List<Map<String, dynamic>> songs,
  required int totalDuration,
  required int unknownCount,
}) async {
  final tts = FlutterTts();
  await tts.setLanguage("cs-CZ");
  await tts.setSpeechRate(0.5);

  if (songs.isEmpty) {
    tts.speak(AppStrings.playlistExportEmpty);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.playlistExportEmpty)));
    }
    return;
  }

  final choice = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Semantics(header: true, child: Text(AppStrings.sharePlaylistTitle)),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'package'),
          child: _ShareOption(
            title: AppStrings.sharePlaylistPackageLabel,
            description: AppStrings.sharePlaylistPackageDescription,
            icon: Icons.playlist_play,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'package_with_contents'),
          child: _ShareOption(
            title: AppStrings.sharePlaylistWithContentsLabel,
            description: AppStrings.sharePlaylistWithContentsDescription,
            icon: Icons.library_music,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'html'),
          child: _ShareOption(
            title: AppStrings.sharePlaylistHtmlLabel,
            description: AppStrings.sharePlaylistHtmlDescription,
            icon: Icons.public,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'qr'),
          child: _ShareOption(
            title: AppStrings.sharePlaylistQrLabel,
            description: AppStrings.sharePlaylistQrDescription,
            icon: Icons.qr_code,
          ),
        ),
      ],
    ),
  );

  if (choice == null || !context.mounted) return;

  switch (choice) {
    case 'package':
      await _sharePlaylistPackage(context, tts,
          playlistName: playlistName, songs: songs, totalDuration: totalDuration, unknownCount: unknownCount, includeContents: false);
      break;
    case 'package_with_contents':
      await _sharePlaylistPackage(context, tts,
          playlistName: playlistName, songs: songs, totalDuration: totalDuration, unknownCount: unknownCount, includeContents: true);
      break;
    case 'html':
      await _sharePlaylistHtml(context, tts,
          playlistName: playlistName, songs: songs, totalDuration: totalDuration, unknownCount: unknownCount);
      break;
    case 'qr':
      await _showPlaylistQrDialog(context, tts,
          playlistName: playlistName, songs: songs, totalDuration: totalDuration, unknownCount: unknownCount);
      break;
  }
}

Future<void> _sharePlaylistPackage(
  BuildContext context,
  FlutterTts tts, {
  required String playlistName,
  required List<Map<String, dynamic>> songs,
  required int totalDuration,
  required int unknownCount,
  required bool includeContents,
}) async {
  try {
    // Pokud uživatel zvolil včetně textů a payload zatím neobsahuje content, doplnit z filePath
    List<Map<String, dynamic>> payload = songs;
    if (includeContents) {
      payload = [];
      for (final s in songs) {
        final entry = Map<String, dynamic>.from(s);
        if (!entry.containsKey('content') || (entry['content'] as String?)?.isEmpty == true) {
          final path = entry['filePath'] as String?;
          if (path != null) {
            try {
              final file = File(path);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                String content;
                try { content = utf8.decode(bytes); } catch (_) { content = latin1.decode(bytes); }
                entry['content'] = content;
              }
            } catch (_) {}
          }
        }
        entry.remove('filePath');
        payload.add(entry);
      }
    } else {
      payload = payload.map((e) { final m = Map<String, dynamic>.from(e); m.remove('filePath'); m.remove('content'); return m; }).toList();
    }
    final dir = await getTemporaryDirectory();
    final suffix = includeContents ? '_s_texty' : '';
    final file = File('${dir.path}/setlist_${_safeName(playlistName)}$suffix.json');
    final jsonStr = buildPlaylistPackageJson(
      name: playlistName,
      songs: payload,
      totalDuration: totalDuration,
      unknownCount: unknownCount,
    );
    await file.writeAsString(jsonStr, encoding: utf8);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: AppStrings.sharePlaylistPackageText(playlistName),
    );
    tts.speak(AppStrings.sharePlaylistPackageDone);
  } catch (e) {
    _announceError(context, tts, e);
  }
}

Future<void> _sharePlaylistHtml(
  BuildContext context,
  FlutterTts tts, {
  required String playlistName,
  required List<Map<String, dynamic>> songs,
  required int totalDuration,
  required int unknownCount,
}) async {
  try {
    final cleanSongs = songs.map((e) { final m = Map<String, dynamic>.from(e); m.remove('filePath'); return m; }).toList();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/setlist_${_safeName(playlistName)}.html');
    await file.writeAsString(
      buildPlaylistHtml(name: playlistName, songs: cleanSongs, totalDuration: totalDuration, unknownCount: unknownCount),
      encoding: utf8,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/html')],
      text: AppStrings.sharePlaylistHtmlText(playlistName),
    );
    tts.speak(AppStrings.sharePlaylistHtmlDone);
  } catch (e) {
    _announceError(context, tts, e);
  }
}

Future<void> _showPlaylistQrDialog(
  BuildContext context,
  FlutterTts tts, {
  required String playlistName,
  required List<Map<String, dynamic>> songs,
  required int totalDuration,
  required int unknownCount,
}) async {
  final cleanSongs = songs.map((e) { final m = Map<String, dynamic>.from(e); m.remove('filePath'); m.remove('content'); return m; }).toList();
  final jsonStr = buildPlaylistPackageJson(
    name: playlistName,
    songs: cleanSongs,
    totalDuration: totalDuration,
    unknownCount: unknownCount,
  );
  if (jsonStr.length > maxQrContentLength) {
    tts.speak(AppStrings.sharePlaylistQrTooLong);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.sharePlaylistQrTooLong)));
    }
    return;
  }
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Semantics(header: true, child: Text(AppStrings.sharePlaylistQrDialogTitle)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Semantics(
                label: AppStrings.sharePlaylistQrSemantics(playlistName),
                image: true,
                child: QrImageView(data: jsonStr, version: QrVersions.auto, size: 240),
              ),
            ),
            const SizedBox(height: 16),
            Text("Setlist: $playlistName", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...songs.asMap().entries.map((e) {
              final s = e.value;
              final dur = s['duration'] as int?;
              final durText = (dur != null && dur > 0) ? "${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}" : "?";
              final tempoVal = s['tempo'];
              double? tempo;
              if (tempoVal is num) tempo = tempoVal.toDouble();
              else if (tempoVal is String) tempo = double.tryParse(tempoVal.toString());
              final tempoText = tempo != null ? "${tempo.round()} BPM" : "—";
              return Text("${e.key + 1}. ${s['artist']} – ${s['title']} [$durText, $tempoText]");
            }),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zavřít")),
      ],
    ),
  );
}

void _announceError(BuildContext context, FlutterTts tts, Object error) {
  tts.speak(AppStrings.shareError);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppStrings.shareError)));
  }
}

String _safeName(String input) {
  final cleaned = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return cleaned.isEmpty ? 'pisen' : cleaned;
}

/// Zobrazuje jednu volbu v dialogu sdílení: název, popis a ikonu.
/// Přístupné pro čtečky obrazovky - standardní SimpleDialogOption.
class _ShareOption extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _ShareOption({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}