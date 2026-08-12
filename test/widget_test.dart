import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:posouvac_textu/database.dart';
import 'package:posouvac_textu/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    const ttsChannel = MethodChannel('flutter_tts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async => null);

    const infoChannel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(infoChannel, (call) async {
      return <String, dynamic>{
        'appName': 'Posouvač textu',
        'packageName': 'com.example.posouvac_textu',
        'version': '5.3.0',
        'buildNumber': '1',
        'buildSignature': '',
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'), null);
  });

  testWidgets('Knihovna zobrazí píseň a přehrávač se otevře', (tester) async {
    SharedPreferences.setMockInitialValues({
      'manual_shown': true,
      'defaultStartDelay': 0,
    });

    final db = AppDatabase.forTesting();
    addTearDown(db.close);

    await db.into(db.songs).insert(SongsCompanion.insert(
          filePath: 'test_song.txt',
          artist: 'Testovací interpret',
          title: 'Testovací píseň',
        ));

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(LyricScrollerApp(db: db, prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Knihovna'), findsOneWidget);
    expect(find.text('Testovací píseň'), findsOneWidget);

    await tester.tap(find.text('Testovací píseň'));
    await tester.pump(); // Spustí navigaci a sestaví PlayerPage, čímž se spustí _loadSongData

    // Umožníme asynchronním I/O operacím (file.exists) v _loadSongData doběhnout.
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(); // Vykreslí načtenou stránku s "Soubor nenalezen"

    for (final element in find.byType(Text).evaluate()) {
      print('Found Text: ${(element.widget as Text).data}');
    }

    // Soubor test_song.txt neexistuje, přehrávač proto ukáže hlášku.
    expect(find.text('Soubor nenalezen'), findsOneWidget);
  });
}