import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';
import 'database.dart';

/// Sdílená logika vývojářského PINu.
/// PIN se zadává jednou při vstupu do vývojářského režimu (7 poklepání na verzi)
/// a při každé změně PINu. Počítá neúspěšné pokusy, zamyká na 5 minut
/// a po překročení limitu provede soft reset hlasových zpráv.
class DevPinService {
  DevPinService({required this.db});

  final AppDatabase db;

  static const String defaultDevPin = "1950";
  static const int maxPinAttempts = 5;
  static const int softResetAttempts = 10;

  static const String prefsKeyPin = 'devPin';
  static const String prefsKeyPinAttempts = 'devPinFailedAttempts';
  static const String prefsKeyPinLockoutUntil = 'devPinLockoutUntil';

  int failedAttempts = 0;
  DateTime? lockoutUntil;

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    failedAttempts = prefs.getInt(prefsKeyPinAttempts) ?? 0;
    final lockoutMs = prefs.getInt(prefsKeyPinLockoutUntil);
    if (lockoutMs != null) {
      final until = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
      if (until.isAfter(DateTime.now())) {
        lockoutUntil = until;
      } else {
        await prefs.remove(prefsKeyPinLockoutUntil);
      }
    }
  }

  bool isLockedOut() => lockoutUntil != null && lockoutUntil!.isAfter(DateTime.now());

  int remainingAttempts() {
    final nextLockout = ((failedAttempts ~/ maxPinAttempts) + 1) * maxPinAttempts;
    return nextLockout - failedAttempts;
  }

  Future<void> resetState() async {
    final prefs = await SharedPreferences.getInstance();
    failedAttempts = 0;
    lockoutUntil = null;
    await prefs.remove(prefsKeyPinAttempts);
    await prefs.remove(prefsKeyPinLockoutUntil);
  }

  Future<String> currentPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefsKeyPin) ?? defaultDevPin;
  }

  Future<void> saveNewPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKeyPin, pin);
    await resetState();
  }

  Future<String?> promptForPin(
    BuildContext context, {
    required String title,
    String? confirmLabel,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text(title)),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: "PIN"),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Zrušit")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel ?? "Potvrdit")),
        ],
      ),
    );
    return result == true ? controller.text.trim() : null;
  }

  /// Ověří PIN včetně celého toku: zámek, dialog, TTS ohlášení chyb i úspěchu.
  /// Vrací true pouze při správně zadaném PINu.
  Future<bool> verifyDevPin(BuildContext context, FlutterTts tts) async {
    await loadState();
    if (!context.mounted) return false;
    if (isLockedOut()) {
      await _showLockout(context, tts);
      return false;
    }

    final entered = await promptForPin(context, title: "Vývojářský PIN");
    if (entered == null) return false;

    final current = await currentPin();
    if (entered == current) {
      await resetState();
      return true;
    }

    tts.stop();
    if (!context.mounted) return false;
    await _registerFailedAttempt(context, tts);
    return false;
  }

  Future<void> _registerFailedAttempt(BuildContext context, FlutterTts tts) async {
    final prefs = await SharedPreferences.getInstance();
    failedAttempts += 1;
    await prefs.setInt(prefsKeyPinAttempts, failedAttempts);

    if (failedAttempts >= softResetAttempts) {
      if (!context.mounted) return;
      await _softResetDevData(context, tts);
      return;
    }

    if (failedAttempts % maxPinAttempts == 0) {
      lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
      await prefs.setInt(prefsKeyPinLockoutUntil, lockoutUntil!.millisecondsSinceEpoch);
      if (!context.mounted) return;
      await _showLockout(context, tts);
      return;
    }

    tts.speak(AppStrings.pinIncorrect(remainingAttempts()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.pinIncorrect(remainingAttempts()))),
      );
    }
  }

  Future<void> _softResetDevData(BuildContext context, FlutterTts tts) async {
    await db.clearCustomStrings();
    AppStrings.setCustomStrings({});

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKeyPin);
    failedAttempts = 0;
    lockoutUntil = null;
    await prefs.remove(prefsKeyPinAttempts);
    await prefs.remove(prefsKeyPinLockoutUntil);

    tts.speak("Příliš mnoho pokusů, vývojářská data resetována");
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(header: true, child: Text("Vývojářská data resetována")),
        content: const Text("Po mnoha špatných pokusech byly hlasové zprávy vráceny na výchozí hodnoty a vývojářský PIN na výchozí. Vaše písně a playlisty zůstaly nedotčené."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Rozumím")),
        ],
      ),
    );
  }

  Future<void> _showLockout(BuildContext context, FlutterTts tts) async {
    tts.stop();
    tts.speak(AppStrings.pinLockout(5));
    await showDialog<void>(
      context: context,
      builder: (_) => DevLockoutDialog(until: lockoutUntil!),
    );
  }
}

class DevLockoutDialog extends StatefulWidget {
  final DateTime until;

  const DevLockoutDialog({super.key, required this.until});

  @override
  State<DevLockoutDialog> createState() => _DevLockoutDialogState();
}

class _DevLockoutDialogState extends State<DevLockoutDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.until.difference(DateTime.now());
    return AlertDialog(
      title: Semantics(header: true, child: Text("Příliš mnoho pokusů")),
      content: Text("Vyčkejte prosím ${_format(remaining)} než to zkusíte znovu."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zavřít")),
      ],
    );
  }
}