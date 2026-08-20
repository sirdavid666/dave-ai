import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:particles_flutter/particles_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/dave_service.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});
  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  final SpeechToText _speech = SpeechToText();
  final DaveService _dave = DaveService.instance;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _lastWords = "Say 'Hey Dave' Boss...";
  String _daveResponse = "DAVE AI Online";

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
    await _dave.speak("DAVE AI Online. Yes Boss.");
    _startListening(); // AUTO START
  }

  void _startListening() async {
    if (!_isListening && !_isSpeaking) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) async {
            setState(() {
              _lastWords = result.recognizedWords; // LIVE SUBTITLE UPDATE
            });
            if (result.finalResult) {
              setState(() => _isListening = false);
              setState(() => _isSpeaking = true);
              String response = await _dave.chat(_lastWords);
              setState(() {
                _daveResponse = response;
                _isSpeaking = false;
              });
              await Future.delayed(const Duration(milliseconds: 500));
              _startListening(); // LISTEN AGAIN
            }
          },
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 2),
          localeId: "en_US",
          partialResults: true, // THIS MAKES SUBTITLES LIVE
          onDevice: true, // OFFLINE
          cancelOnError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Particles(
            key: UniqueKey(),
            numberOfParticles: 80,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            particleColor: Colors.white.withOpacity(0.1),
            joinParticleColor: const Color(0xFF4A90E2).withOpacity(0.3),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0A0F), Color(0xFF1A1A2E), Color(0xFF0A0A0F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("DAVE", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))).animate().fade(),
                const Text("AI", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))).animate().fade(delay: 200.ms),
                
                const SizedBox(height: 40),
                
                // JARVIS ARC REACTOR
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSpeaking ? const Color(0xFFFFD700).withOpacity(0.3) : const Color(0xFF4A90E2).withOpacity(0.2),
                    border: Border.all(color: _isSpeaking ? const Color(0xFFFFD700) : const Color(0xFF4A90E2), width: 3),
                    boxShadow: [
                      BoxShadow(color: (_isSpeaking ? const Color(0xFFFFD700) : const Color(0xFF4A90E2)).withOpacity(0.6), blurRadius: 50, spreadRadius: 10)
                    ],
                  ),
                  child: Icon(
                    _isSpeaking ? Icons.volume_up : _isListening ? Icons.mic : Icons.smart_toy,
                    size: 120,
                    color: _isSpeaking ? const Color(0xFFFFD700) : const Color(0xFF4A90E2),
                  ),
                ).animate(target: _isListening || _isSpeaking ? 1 : 0).scale().then().shimmer(),

                const SizedBox(height: 30),
                
                // 1. LIVE SUBTITLE - WHAT YOU SAID
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isListening ? const Color(0xFFFFD700) : Colors.white24)
                  ),
                  child: Column(
                    children: [
                      Text("YOU", style: TextStyle(fontSize: 12, color: _isListening ? const Color(0xFFFFD700) : Colors.white54)),
                      const SizedBox(height: 8),
                      Text(
                        _lastWords,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ).animate().fade(),
                
                const SizedBox(height: 20),

                // 2. DAVE RESPONSE
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4A90E2))
                  ),
                  child: Column(
                    children: [
                      const Text("DAVE", style: TextStyle(fontSize: 12, color: Color(0xFF4A90E2))),
                      const SizedBox(height: 8),
                      Text(
                        _daveResponse,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, color: Color(0xFF4A90E2), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                Text(
                  _isListening ? "Listening..." : _isSpeaking ? "Speaking..." : "Standby",
                  style: TextStyle(fontSize: 16, color: _isListening ? const Color(0xFFFFD700) : Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
