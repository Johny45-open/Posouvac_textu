import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum Instrument { guitar, ukulele, violin, bass }

class TunerPage extends StatefulWidget {
  const TunerPage({super.key});

  @override
  State<TunerPage> createState() => _TunerPageState();
}

class _TunerPageState extends State<TunerPage> {
  final _audioCapture = FlutterAudioCapture();
  final _pitchDetector = PitchDetector(audioSampleRate: 44100, bufferSize: 2000);
  
  bool _isRecording = false;
  double _frequency = 0.0;
  String _note = "-";
  String _status = "Připraveno";
  Instrument _selectedInstrument = Instrument.guitar;
  
  Timer? _announcementTimer;
  String _lastAnnouncement = "";
  final _tts = FlutterTts();

  // Stabilizační proměnné
  String _lastStableNote = "";
  int _stabilityCount = 0;
  final int _requiredStability = 3;

  final Map<Instrument, String> _instrumentNames = {
    Instrument.guitar: "Kytara (struny: E, A, D, G, H, E)",
    Instrument.ukulele: "Ukulele (struny: G, C, E, A)",
    Instrument.violin: "Housle (struny: G, D, A, E)",
    Instrument.bass: "Basa (struny: E, A, D, G)",
  };

  final Map<Instrument, List<double>> _instrumentTunings = {
    Instrument.guitar: [82.41, 110.00, 146.83, 196.00, 246.94, 329.63],
    Instrument.ukulele: [392.00, 261.63, 329.63, 440.00], 
    Instrument.violin: [196.00, 293.66, 440.00, 659.25], 
    Instrument.bass: [41.20, 55.00, 73.42, 98.00], 
  };

  @override
  void initState() {
    super.initState();
    _audioCapture.init();
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _stopCapture();
    _tts.stop();
    super.dispose();
  }

  Future<void> _startCapture() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() => _status = "Chybí oprávnění k mikrofonu");
      return;
    }

    try {
      await _audioCapture.init();
      await _audioCapture.start(_onAudioData, _onError, sampleRate: 44100, bufferSize: 3000);
      setState(() {
        _isRecording = true;
        _status = "Poslouchám...";
      });
      _startAnnouncementTimer();
    } catch (e) {
      setState(() => _status = "Chyba: $e");
    }
  }

  Future<void> _stopCapture() async {
    await _audioCapture.stop();
    _announcementTimer?.cancel();
    setState(() {
      _isRecording = false;
      _frequency = 0.0;
      _note = "-";
      _status = "Zastaveno";
      _lastStableNote = "";
      _stabilityCount = 0;
    });
  }

  void _onAudioData(dynamic obj) async {
    if (obj is !List) return;
    
    final List<double> buffer = obj.map((e) => (e as num).toDouble()).toList();

    // Jednoduchý filtr hlasitosti (RMS)
    double rms = 0;
    for (var val in buffer) { rms += val * val; }
    rms = sqrt(rms / buffer.length);
    if (rms < 0.01) return; // Ignorujeme ticho a velmi slabý šum

    final result = await _pitchDetector.getPitchFromFloatBuffer(buffer);
    if (result.pitched && result.pitch > 20 && result.pitch < 2000) {
      double detectedPitch = result.pitch;
      double closestTarget = _findClosestTarget(detectedPitch);
      String detectedNote = _getNoteFromFrequency(closestTarget);
      String detectedStatus = _getTuningStatus(detectedPitch, closestTarget);

      if (detectedNote == _lastStableNote) {
        _stabilityCount++;
      } else {
        _lastStableNote = detectedNote;
        _stabilityCount = 0;
      }

      if (_stabilityCount >= _requiredStability) {
        setState(() {
          _frequency = detectedPitch;
          _note = detectedNote;
          _status = detectedStatus;
        });

        if (detectedStatus == "V pořádku") {
          HapticFeedback.mediumImpact();
        }
      }
    }
  }

  double _findClosestTarget(double pitch) {
    List<double> targets = _instrumentTunings[_selectedInstrument]!;
    double closest = targets[0];
    double minDiff = (pitch - targets[0]).abs();
    
    for (var target in targets) {
      double diff = (pitch - target).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = target;
      }
    }
    return closest;
  }

  void _onError(Object e) {
    setState(() => _status = "Chyba zvuku: $e");
  }

  String _getNoteFromFrequency(double frequency) {
    const notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    int n = (12 * (log(frequency / 440) / log(2))).round() + 69;
    int noteIndex = n % 12;
    return notes[noteIndex];
  }

  String _getTuningStatus(double frequency, double target) {
    double diff = frequency - target;
    
    if (diff.abs() < 0.5) return "V pořádku";
    if (diff > 0) return "Příliš vysoko";
    return "Příliš nízko";
  }

  void _startAnnouncementTimer() {
    _announcementTimer?.cancel();
    _announcementTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isRecording && _note != "-") {
        String announcement = "$_note, $_status";
        if (announcement != _lastAnnouncement) {
          _tts.speak(announcement);
          _lastAnnouncement = announcement;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ladička"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Nástroj",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: "Vyberte nástroj",
              child: DropdownButtonFormField<Instrument>(
                value: _selectedInstrument,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: Instrument.values.map((i) {
                return DropdownMenuItem(
                  value: i,
                  child: Text(_instrumentNames[i]!),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedInstrument = val);
              },
            ),
            ),
            const SizedBox(height: 40),
            Center(
              child: MergeSemantics(
                child: Column(
                  children: [
                    Text(
                      _note,
                      style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 24,
                        color: _status == "V pořádku" ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text("${_frequency.toStringAsFixed(1)} Hz"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton.icon(
              onPressed: _isRecording ? _stopCapture : _startCapture,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? "Zastavit ladičku" : "Spustit ladičku"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                textStyle: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
