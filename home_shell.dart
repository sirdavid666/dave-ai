import 'package:flutter/material.dart';

import 'dave_service.dart';
import 'chat_page.dart';
import 'voice_page.dart';
import 'memory_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  DateTime? _lastMorningSpoken;
  DateTime? _lastNightSpoken;

  final _pages = const [
    ChatPage(),
    VoicePage(),
    MemoryPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // While the app is open, this timer covers two things the background
    // isolate can't reliably do: SPEAKING the 7am/10pm briefing out loud,
    // and the "Boss you good?" 4-hour idle nudge.
    _startForegroundTicker();
  }

  void _startForegroundTicker() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 1));
      if (!mounted) return false;
      await _checkForegroundEvents();
      return true;
    });
  }

  Future<void> _checkForegroundEvents() async {
    final svc = DaveService.instance;
    final now = DateTime.now();
    final proactiveOn =
        svc.settingsBox.get('proactive_mode_on', defaultValue: true) as bool;
    if (!proactiveOn) return;

    // Morning briefing spoken window: 7:00-7:01
    final morningOn =
        svc.settingsBox.get('morning_briefing_on', defaultValue: true) as bool;
    if (morningOn &&
        now.hour == 7 &&
        now.minute == 0 &&
        (_lastMorningSpoken == null ||
            _lastMorningSpoken!.day != now.day)) {
      _lastMorningSpoken = now;
      final text = await svc.buildMorningBriefing();
      svc.speak(text);
    }

    // Night briefing spoken window: 22:00-22:01
    final nightOn =
        svc.settingsBox.get('night_briefing_on', defaultValue: true) as bool;
    if (nightOn &&
        now.hour == 22 &&
        now.minute == 0 &&
        (_lastNightSpoken == null || _lastNightSpoken!.day != now.day)) {
      _lastNightSpoken = now;
      final text = await svc.buildNightBriefing();
      svc.speak(text);
    }

    // 4-hour idle nudge.
    if (svc.idleFourHours) {
      svc.speak("Boss you good? Need motivation?");
      svc.recordActivity(); // avoid repeating every minute
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF12121A),
        selectedItemColor: const Color(0xFFFFD700),
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: "Chat"),
          BottomNavigationBarItem(icon: Icon(Icons.mic_none), label: "Voice"),
          BottomNavigationBarItem(
              icon: Icon(Icons.psychology_outlined), label: "Memory"),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: "Settings"),
        ],
      ),
    );
  }
}
