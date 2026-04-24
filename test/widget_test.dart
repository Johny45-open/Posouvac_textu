import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:posouvac_textu/main.dart';

void main() {
  testWidgets('Aplikace se načte a zobrazí tlačítko Spustit', (WidgetTester tester) async {
    // Inicializace mocku pro SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Sestavení aplikace
    await tester.pumpWidget(LyricScrollerApp(prefs: prefs));

    // Ověření, že se zobrazí hlavní nadpis a tlačítko Spustit
    expect(find.text('Posouvač textu'), findsWidgets); // V AppBaru a názvu
    expect(find.text('Spustit'), findsOneWidget);
    
    // Klepnutí na tlačítko Spustit
    await tester.tap(find.text('Spustit'));
    await tester.pump();

    // Po klepnutí by se měl text změnit na Zastavit
    expect(find.text('Zastavit'), findsOneWidget);
  });
}
