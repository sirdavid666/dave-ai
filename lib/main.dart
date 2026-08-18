import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('dave_memory');
  runApp(const DaveAI());
}

class DaveAI extends StatelessWidget {
  const DaveAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAVE AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.blueAccent,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final Battery _battery = Battery();
  final Box _box = Hive.box('dave_memory');
  bool _isListening = false;
  String _lastWords = "Tap mic to talk to DAVE";
  String _time = "";
  int _batteryLevel = 100;

  @override
  void initState() {
    super.initState();
    _init();
    _updateTime();
    _updateBattery();
  }

  _init() async {
    await _speech.initialize();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _requestPermissions();
  }

  _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.notification.request();
  }

  _updateTime() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _time = DateFormat('hh:mm a').format(DateTime.now());
      });
    });
  }

  _updateBattery() async {
    _batteryLevel = await _battery.batteryLevel;
    setState(() {});
  }

  _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
          });
          if (result.finalResult) {
            _processCommand(_lastWords);
          }
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  _processCommand(String command) async {
    command = command.toLowerCase();
    String response = "Yes Boss";

    if (command.contains("time")) {
      response = "The time is $_time";
    } else if (command.contains("battery")) {
      _updateBattery();
      response = "Battery is at $_batteryLevel percent";
    } else if (command.contains("hello")) {
      response = "Hello Boss David. How can I help you?";
    } else {
      response = "I heard: $command. Still learning boss";
    }

    await _speak(response);
  }

  _speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.blue.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_time,
                  style: const TextStyle(fontSize: 40, color: Colors.white))
                  .animate().fadeIn(duration: 1.seconds),
              const SizedBox(height: 20),
              AnimatedTextKit(
                animatedTexts: [
                  TyperAnimatedText(_lastWords,
                      textStyle: const TextStyle(fontSize: 20, color: Colors.blueAccent)),
                ],
                isRepeatingAnimation: true,
              ),
              const SizedBox(height: 50),
              GestureDetector(
                onTap: _listen,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red : Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ).animate(target: _isListening ? 1 : 0)
                  .scale(duration: 600.ms, curve: Curves.easeInOut),
              const SizedBox(height: 20),
              Text("Battery: $_batteryLevel%",
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
