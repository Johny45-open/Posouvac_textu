import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManualPage extends StatefulWidget {
  final VoidCallback onFinished;

  const ManualPage({super.key, required this.onFinished});

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  final PageController _pageController = PageController();
  final FlutterTts _tts = FlutterTts();
  int _currentPage = 0;

  final List<ManualStep> _steps = [
    ManualStep(
      title: "Vítejte v Posouvači textů",
      content: "Tato aplikace vám pomůže s texty a akordy při hraní. Je navržena tak, aby byla plně přístupná pro čtečky obrazovky.",
    ),
    ManualStep(
      title: "Knihovna a import",
      content: "V Knihovně najdete své písně. Nové texty ve formátu .txt importujete tlačítkem vpravo dole. Pokud chcete upravit jméno interpreta nebo název, podržte na písni prst déle.",
    ),
    ManualStep(
      title: "Přehrávač a tempo",
      content: "Klepnutím na text v přehrávači spustíte hlasový odpočet a automatický posuv. Tempo BPM nastavíte ikonou tachometru v horní liště. Nastavení se uloží pro každou píseň zvlášť.",
    ),
    ManualStep(
      title: "Ladička a Playlisty",
      content: "Ikona noty v Knihovně otevře ladičku. Ikona plus u písně vám umožní zařadit ji do vlastních seznamů, jako jsou například playlisty Olympic nebo Oslava.",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _speakCurrentStep();
  }

  void _speakCurrentStep() {
    _tts.stop();
    _tts.speak("${_steps[_currentPage].title}. ${_steps[_currentPage].content}");
  }

  Future<void> _finishManual() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('manual_shown', true);
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _speakCurrentStep();
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            _steps[index].title,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          _steps[index].content,
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: const Text("ZPĚT"),
                    )
                  else
                    const SizedBox(width: 60),
                  
                  Text("${_currentPage + 1} z ${_steps.length}"),

                  if (_currentPage < _steps.length - 1)
                    ElevatedButton(
                      onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: const Text("DALŠÍ"),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: _finishManual,
                      child: const Text("ROZUMÍM"),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _pageController.dispose();
    super.dispose();
  }
}

class ManualStep {
  final String title;
  final String content;
  ManualStep({required this.title, required this.content});
}
