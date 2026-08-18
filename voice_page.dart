import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'dave_service.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage>
    with SingleTickerProviderStateMixin {
  final _svc = DaveService.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _speechReady = false;
  bool _isListening = false;
  bool _wakeWordListening = false; // separate loop from tap-to-talk
  String _liveText = "";
  String _lastReply = "";

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onError: (e) => _snack("Speech error: ${e.errorMsg}"),
        onStatus: (status) {
          if (status == "done" || status == "notListening") {
            if (_isListening) setState(() => _isListening = false);
          }
        },
      );
      setState(() {});

      // NOTE ON WAKE WORD: true always-on background listening (app closed,
      // screen off) requires a persistent foreground service + a dedicated
      // wake-word engine (e.g. Porcupine) — outside what speech_to_text can
      // do offline. What IS reliably achievable, and what this implements,
      // is FOREGROUND wake-word listening: while this Voice tab is open and
      // the toggle is on, Dave listens in short repeating bursts for "dave"
      // or "hey dave" and reacts when heard.
      final wakeOn =
          _svc.settingsBox.get('wake_word_on', defaultValue: true) as bool;
      if (wakeOn) _startWakeWordLoop();
    } catch (e) {
      _snack("Could not initialize speech recognition: $e");
    }
  }

  void _startWakeWordLoop() {
    if (!_speechReady || _wakeWordListening) return;
    _wakeWordListening = true;
    _listenForWakeWord();
  }

  Future<void> _listenForWakeWord() async {
    if (!_wakeWordListening || _isListening) return;
    try {
      await _speech.listen(
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          final heard = result.recognizedWords.toLowerCase();
          if (heard.contains("hey dave") || heard.contains("dave")) {
            _speech.stop();
            _onWakeWordDetected();
          }
        },
      );
      // Re-arm the loop after each burst ends, if still enabled.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _wakeWordListening && !_isListening) {
          _listenForWakeWord();
        }
      });
    } catch (_) {
      // Silently retry — wake-word loop shouldn't spam errors.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _wakeWordListening) _listenForWakeWord();
      });
    }
  }

  void _onWakeWordDetected() async {
    _svc.recordActivity();
    setState(() => _liveText = "Yes Boss, I dey here...");
    await _svc.speak("Yes Boss, I dey here");
    _startTapToTalk();
  }

  Future<void> _startTapToTalk() async {
    if (!_speechReady) {
      _snack("Speech recognition is not available on this device.");
      return;
    }
    setState(() {
      _isListening = true;
      _liveText = "";
    });
    try {
      await _speech.listen(
        onResult: (result) {
          setState(() => _liveText = result.recognizedWords);
        },
      );
    } catch (e) {
      setState(() => _isListening = false);
      _snack("Could not start listening: $e");
    }
  }

  Future<void> _stopAndRespond() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_liveText.trim().isEmpty) return;

    final reply = _svc.getResponse(_liveText.trim());
    setState(() => _lastReply = reply);
    await _svc.speak(reply);

    // Re-arm wake word listening after replying.
    if (_svc.settingsBox.get('wake_word_on', defaultValue: true) as bool) {
      _wakeWordListening = true;
      _listenForWakeWord();
    }
  }

  void _onMicTap() {
    if (_isListening) {
      _stopAndRespond();
    } else {
      _wakeWordListening = false; // pause wake loop during manual talk
      _speech.stop();
      _startTapToTalk();
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  void dispose() {
    _wakeWordListening = false;
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text("Voice",
            style: TextStyle(
                color: Color(0xFF4A90E2), fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_wakeWordListening && !_isListening)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text("Listening for 'Hey Dave'...",
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            GestureDetector(
              onTap: _onMicTap,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final strength = _isListening ? _pulse.value : 0.4;
                  return Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF12121A),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(strength * 0.7),
                          blurRadius: _isListening ? 45 : 20,
                          spreadRadius: _isListening ? 8 : 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: const Color(0xFFFFD700),
                      size: 60,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                _liveText.isNotEmpty
                    ? _liveText
                    : (_isListening ? "Listening..." : "Tap to talk to Dave"),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            if (_lastReply.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_lastReply,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
