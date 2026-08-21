import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/dave_service.dart';
import 'pages/voice_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SharedPreferences.getInstance();

  await _requestPermissions();

  await DaveService.instance.init();

  runApp(const DaveAIApp());
}

Future<void> _requestPermissions() async {
  await Permission.microphone.request();
  await Permission.notification.request();
}

class DaveAIApp extends StatelessWidget {
  const DaveAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAVE AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor:
            const Color(0xFF05070D),
        colorScheme:
            ColorScheme.fromSeed(
          seedColor:
              const Color(0xFF4A90E2),
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(
      const Duration(seconds: 2),
      () {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const HomeScreen(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF05070D),
              Color(0xFF10172A),
              Color(0xFF05070D),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      const Color(0xFF4A90E2)
                          .withOpacity(0.18),
                  border: Border.all(
                    color:
                        const Color(0xFF4A90E2)
                            .withOpacity(0.5),
                  ),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  size: 90,
                  color:
                      Color(0xFF4A90E2),
                ),
              )
                  .animate()
                  .scale(
                    duration:
                        const Duration(
                      milliseconds: 900,
                    ),
                  )
                  .fade(),

              const SizedBox(height: 25),

              const Text(
                'DAVE AI',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight:
                      FontWeight.bold,
                  letterSpacing: 3,
                ),
              )
                  .animate()
                  .fade(),

              const SizedBox(height: 10),

              const Text(
                'YOUR PRIVATE LOCAL AI',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 3,
                  color: Colors.white54,
                ),
              ),

              const SizedBox(height: 30),

              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  int index = 0;

  final pages = const [
    VoicePage(),
    MemoryPage(),
    TasksPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar:
          BottomNavigationBar(
        currentIndex: index,
        onTap: (value) {
          setState(() {
            index = value;
          });
        },
        type:
            BottomNavigationBarType.fixed,
        backgroundColor:
            const Color(0xFF080A10),
        selectedItemColor:
            const Color(0xFF4A90E2),
        unselectedItemColor:
            Colors.white38,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'DAVE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.memory),
            label: 'Memory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor:
          Color(0xFF05070D),
      body: Center(
        child: Text(
          'DAVE Memory',
          style: TextStyle(
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor:
          Color(0xFF05070D),
      body: Center(
        child: Text(
          'DAVE Tasks',
          style: TextStyle(
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor:
          Color(0xFF05070D),
      body: Center(
        child: Text(
          'DAVE Settings',
          style: TextStyle(
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}
