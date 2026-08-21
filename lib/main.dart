import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'pages/voice_page.dart';
import 'services/dave_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the Flutter UI first.
  // Do NOT initialize Whisper/Llama before runApp().
  runApp(
    const DaveAIApp(),
  );
}

class DaveAIApp extends StatelessWidget {
  const DaveAIApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAVE AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070A12),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String status = 'Starting DAVE AI...';
  bool failed = false;

  @override
  void initState() {
    super.initState();

    _startDAVE();
  }

  Future<void> _startDAVE() async {
    try {
      setState(() {
        status = 'Requesting permissions...';
      });

      // Request permissions after the Flutter UI exists.
      await Permission.microphone.request();
      await Permission.notification.request();

      if (!mounted) return;

      setState(() {
        status = 'Initializing DAVE...';
      });

      // Initialize DAVE after the UI is already running.
      await DaveService.instance.init();

      if (!mounted) return;

      setState(() {
        status = 'DAVE is ready.';
      });

      await Future.delayed(
        const Duration(milliseconds: 800),
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } catch (e) {
      debugPrint('DAVE STARTUP ERROR: $e');

      if (!mounted) return;

      setState(() {
        failed = true;
        status =
            'DAVE could not finish starting.\n\n'
            'You can still open the app and retry setup.';
      });

      // Give the user access to the UI even if initialization fails.
      await Future.delayed(
        const Duration(seconds: 1),
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF05070D),
              Color(0xFF101A32),
              Color(0xFF05070D),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 30,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.smart_toy,
                  size: 100,
                  color: Color(0xFF4A90E2),
                ),

                const SizedBox(height: 24),

                const Text(
                  'DAVE AI',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),

                if (failed) ...[
                  const SizedBox(height: 25),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    VoicePage(),
    MemoryPage(),
    TasksPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'DAVE',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory),
            label: 'Memory',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class MemoryPage extends StatelessWidget {
  const MemoryPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<String>(
        valueListenable: DaveService.instance.response,
        builder: (context, value, _) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAVE Memory',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  value.isEmpty
                      ? 'No recent response.'
                      : value,
                  style: const TextStyle(
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TasksPage extends StatelessWidget {
  const TasksPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text(
          'DAVE Tasks',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            FilledButton.icon(
              onPressed: () async {
                await DaveService.instance.retryModelSetup();
              },
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Retry AI Model Setup',
              ),
            ),

            const SizedBox(height: 20),

            ValueListenableBuilder<String>(
              valueListenable:
                  DaveService.instance.status,
              builder: (context, status, _) {
                return Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            const Text(
              'DAVE AI is designed to run its AI brain locally after the initial model download.',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
