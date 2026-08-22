import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

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
      title: AppStrings.welcomeTitle,
      content: AppStrings.welcomeContent,
    ),
    ManualStep(
      title: AppStrings.libraryTitle,
      content: AppStrings.libraryContent,
    ),
    ManualStep(
      title: AppStrings.playerTitle,
      content: AppStrings.playerContent,
    ),
    ManualStep(
      title: AppStrings.extraTitle,
      content: AppStrings.extraContent,
    ),
    ManualStep(
      title: AppStrings.accessibilityTitle,
      content: AppStrings.accessibilityContent,
    ),
    ManualStep(
      title: AppStrings.concertModeTitle,
      content: AppStrings.isInformal
          ? "Koncertní režim ti dá velké dotykové plochy - levá zpomalí, pravá zrychlí, střed spustí. Pedál nebo volume tlačítka fungují stejně. Dvojitým poklepáním dvěma prsty nebo podržením pedálu zjistíš další řádek. V nastavení si vyber jestli chceš náhled na vyžádání nebo automaticky 2,5 sekundy předem do jednoho sluchátka. Bez sluchátka funguje aspoň vibrace a hlášky z repráku."
          : "Koncertní režim v Nastavení zvětší dotykové plochy v přehrávači - levá třetina zpomalí o 5 BPM, střed spustí nebo zastaví posuv, pravá zrychlí. Stejně funguje Bluetooth pedál (mezerník) a volume tlačítka. Dvojitým poklepáním dvěma prsty, podržením středu nebo pedálu se ohlásí další řádek s akordy. V Nastavení zvolte Na vyžádání nebo Automaticky 2,5 sekundy předem (vhodné s jedním sluchátkem). Bez sluchátka slouží jako fallback vibrace a hlášky z reproduktoru.",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);
    
    // Nastavení handleru pro dokončení řeči
    _tts.setCompletionHandler(() {
      if (mounted && _currentPage < _steps.length - 1) {
        // Počkáme 2 sekundy po dočtení a pak přepneme na další stránku
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _currentPage < _steps.length - 1) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    });

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
                      child: Text(AppStrings.understandButton),
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
