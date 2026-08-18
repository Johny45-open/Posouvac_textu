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
      title: Text(AppStrings.shareTitle),
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
      title: Text(AppStrings.shareQrDialogTitle),
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