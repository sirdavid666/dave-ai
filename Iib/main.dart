import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:particles_flutter/particles_flutter.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('dave_memory');
  await AndroidAlarmManager.initialize();
  runApp(const DaveApp());
}

class DaveApp extends StatelessWidget {
  const DaveApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAVE AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050510),
        primaryColor: const Color(0xFF00D4FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4FF),
          secondary: Color(0xFF7B2FFF),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// SPLASH SCREEN
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CircularParticle(
            awayRadius: 100,
            numberOfParticles: 100,
            speedOfParticles: 0.5,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            particleColor: const Color(0xFF00D4FF).withOpacity(0.5),
            onTapAnimation: false,
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, size: 80, color: Color(0xFF00D4FF)),
                const SizedBox(height: 20),
                DefaultTextStyle(
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  child: AnimatedTextKit(
                    animatedTexts: [TypewriterAnimatedText('Initializing DAVE...')],
                    totalRepeatCount: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// HOME SCREEN
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _memoryBox = Hive.box('dave_memory');
  final _tts = FlutterTts();
  final _stt = stt.SpeechToText();
  final _battery = Battery();
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initDave();
  }

  _initDave() async {
    await _requestPermissions();
    await _initNotifications();
    _scheduleDailyTasks();
    _checkBattery();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.5);
    _stt.initialize();
  }

  _requestPermissions() async {
    await [Permission.microphone, Permission.notification].request();
  }

  _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: android));
  }

  _scheduleDailyTasks() {
    AndroidAlarmManager.periodic(const Duration(days: 1), 0, _morningBrief, startAt: _nextInstance(7, 0));
    AndroidAlarmManager.periodic(const Duration(days: 1), 1, _nightBrief, startAt: _nextInstance(22, 0));
  }

  DateTime _nextInstance(int hour, int min) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, min);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }

  static _morningBrief() async {
    final tts = FlutterTts();
    await tts.speak("Good morning Boss David. This is your daily briefing. You have 0 reminders. Have a great day.");
  }

  static _nightBrief() async {
    final tts = FlutterTts();
    await tts.speak("Good night Boss. Time to rest. Dave is logging off.");
  }

  _checkBattery() async {
    final level = await _battery.batteryLevel;
    if (level < 20) {
      _speak("Boss, battery is at $level percent. Plug me in.");
    }
  }

  _speak(String text) async {
    await _tts.speak(text);
  }

  _listen() async {
    if (!_isListening) {
      bool available = await _stt.initialize();
      if (available) {
        setState(() => _isListening = true);
        _stt.listen(onResult: (result) {
          setState(() => _lastWords = result.recognizedWords);
        });
      }
    } else {
      setState(() => _isListening = false);
      _stt.stop();
      _processCommand(_lastWords);
    }
  }

  _processCommand(String cmd) {
    cmd = cmd.toLowerCase();
    if (cmd.contains('time')) {
      _speak("The time is ${DateFormat.jm().format(DateTime.now())}");
    } else if (cmd.contains('battery')) {
      _checkBattery();
    } else {
      _speak("Yes Boss, I heard: $cmd");
      _memoryBox.add({'text': cmd, 'time': DateTime.now()});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChatPage(speak: _speak, memory: _memoryBox),
      VoicePage(listen: _listen, isListening: _isListening, lastWords: _lastWords),
      MemoryPage(memory: _memoryBox),
      SettingsPage(),
    ];
    return Scaffold(
      body: Stack(
        children: [
          CircularParticle(
            awayRadius: 80,
            numberOfParticles: 80,
            speedOfParticles: 0.3,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            particleColor: const Color(0xFF7B2FFF).withOpacity(0.3),
          ),
          pages[_currentIndex],
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.black,
        selectedItemColor: const Color(0xFF00D4FF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Voice'),
          BottomNavigationBarItem(icon: Icon(Icons.memory), label: 'Memory'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// PAGES
class ChatPage extends StatelessWidget {
  final Function(String) speak;
  final Box memory;
  ChatPage({required this.speak, required this.memory});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text("DAVE AI", style: TextStyle(fontSize: 28, color: Color(0xFF00D4FF))),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: () => speak("Hello Boss David, how can I help you?"), child: const Text("Talk to Dave"))
    ]));
  }
}

class VoicePage extends StatelessWidget {
  final Function listen;
  final bool isListening;
  final String lastWords;
  VoicePage({required this.listen, required this.isListening, required this.lastWords});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      GestureDetector(
        onTap: () => listen(),
        child: CircleAvatar(
          radius: 60,
          backgroundColor: isListening ? Colors.red : const Color(0xFF00D4FF),
          child: Icon(isListening ? Icons.mic : Icons.mic_none, size: 50, color: Colors.white),
        ),
      ),
      const SizedBox(height: 20),
      Text(lastWords.isEmpty ? "Tap to talk" : lastWords, style: const TextStyle(color: Colors.white)),
    ]));
  }
}

class MemoryPage extends StatelessWidget {
  final Box memory;
  MemoryPage({required this.memory});
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: memory.values.map((e) => ListTile(
        title: Text(e['text'], style: const TextStyle(color: Colors.white)),
        subtitle: Text(e['time'].toString(), style: const TextStyle(color: Colors.grey)),
      )).toList(),
    );
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Settings", style: TextStyle(color: Colors.white, fontSize: 24)));
  }
}
