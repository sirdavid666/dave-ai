import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/dave_service.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});
  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  final DaveService _dave = DaveService.instance;
  
  bool _isListening = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _dave.status.addListener(_updateState);
    _dave.transcript.addListener(_updateState);
    _dave.response.addListener(_updateState);
  }

  void _updateState() {
    if(!mounted) return;
    setState(() {
      _isListening = _dave.status.value.contains("Listening");
      _isSpeaking = _dave.status.value.contains("speaking");
    });
  }

  @override
  void dispose() {
    _dave.status.removeListener(_updateState);
    _dave.transcript.removeListener(_updateState);
    _dave.response.removeListener(_updateState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // BACKGROUND
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
                
                // JARVIS ARC REACTOR - NOW TAPABLE
                GestureDetector(
                  onTap: _dave.startListening, // TAP TO TALK
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isSpeaking? const Color(0xFFFFD700).withOpacity(0.3) : const Color(0xFF4A90E2).withOpacity(0.2),
                      border: Border.all(color: _isSpeaking? const Color(0xFFFFD700) : const Color(0xFF4A90E2), width: 3),
                      boxShadow: [
                        BoxShadow(color: (_isSpeaking? const Color(0xFFFFD700) : const Color(0xFF4A90E2)).withOpacity(0.6), blurRadius: 50, spreadRadius: 10)
                      ],
                    ),
                    child: Icon(
                      _isSpeaking? Icons.volume_up : _isListening? Icons.mic : Icons.touch_app, // mic icon when listening
                      size: 120,
                      color: _isSpeaking? const Color(0xFFFFD700) : const Color(0xFF4A90E2),
                    ),
                  ),
                ).animate(target: _isListening || _isSpeaking? 1 : 0).scale().then().shimmer(),

                const SizedBox(height: 30),
                
                // YOU SAID
                ValueListenableBuilder(valueListenable: _dave.transcript, builder: (_, text, __) => 
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isListening? const Color(0xFFFFD700) : Colors.white24)
                  ),
                  child: Column(
                    children: [
                      Text("YOU", style: TextStyle(fontSize: 12, color: _isListening? const Color(0xFFFFD700) : Colors.white54)),
                      const SizedBox(height: 8),
                      Text(
                        text.isEmpty? "Tap the circle and talk Boss..." : text, // CHANGED TEXT
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ).animate().fade()),
                
                const SizedBox(height: 20),

                // DAVE RESPONSE
                ValueListenableBuilder(valueListenable: _dave.response, builder: (_, text, __) => 
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
                        text.isEmpty? "DAVE AI Online" : text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, color: Color(0xFF4A90E2), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),

                const SizedBox(height: 30),
                ValueListenableBuilder(valueListenable: _dave.status, builder: (_, status, __) => 
                Text(
                  status,
                  style: TextStyle(fontSize: 16, color: _isListening? const Color(0xFFFFD700) : Colors.white54),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
