import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // REPLACED HIVE
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/dave_service.dart';
import 'pages/voice_page.dart';

const String MASTER_NAME = "DAVID";

final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance(); // INIT PREFS
  await DaveService.instance.init();
  await _initNotifications();
  await [Permission.microphone, Permission.notification, Permission.storage].request();
  runApp(const DaveAIApp());
}

Future<void> _initNotifications() async {
  const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(const InitializationSettings(android: android));
}

class DaveAIApp extends StatelessWidget {
  const DaveAIApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAVE AI', 
      debugShowCheckedModeBanner: false, 
      theme: ThemeData.dark(), 
      home: const SplashScreen()
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0A0A0F), Color(0xFF1A1A2E), Color(0xFF0A0A0F)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4A90E2).withOpacity(0.3)),
            child: const Icon(Icons.smart_toy, size: 100, color: Color(0xFF4A90E2)),
          ).animate().scale(duration: const Duration(milliseconds: 1000)).fade(),
          const SizedBox(height: 20),
          RichText(text: const TextSpan(children: [
            TextSpan(text: "DAVE ", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
            TextSpan(text: "AI", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
          ])).animate().fade(duration: const Duration(milliseconds: 500)),
          const SizedBox(height: 10),
          const Text("Loading Master DAVID...", style: TextStyle(color: Colors.white70, fontSize: 16)).animate().fade(delay: const Duration(milliseconds: 500)),
        ])),
      ]),
    );
  }
}

// JARVIS HOME WITH 4 TABS
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const VoicePage(), // JARVIS VOICE MODE
    const MemoryPage(), 
    const TasksPage(), 
    const SettingsPage()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF0A0A0F),
        selectedItemColor: const Color(0xFF4A90E2),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: "DAVE"),
          BottomNavigationBarItem(icon: Icon(Icons.memory), label: "Memory"),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: "Tasks"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}

// PLACEHOLDERS FOR NOW
class MemoryPage extends StatelessWidget {const MemoryPage({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Memory", style: TextStyle(color: Colors.white)));}
class TasksPage extends StatelessWidget {const TasksPage({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Tasks", style: TextStyle(color: Colors.white)));}
class SettingsPage extends StatelessWidget {const SettingsPage({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Settings", style: TextStyle(color: Colors.white)));}
