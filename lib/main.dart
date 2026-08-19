import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // NEW
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; // NEW
import 'dart:convert'; // NEW

import 'dave_service.dart';
import 'splash_screen.dart';

// ---------------------------------------------------------------------
// WORKMANAGER TASK NAMES
// ---------------------------------------------------------------------
const String morningTask = "morningBriefingTask";
const String nightTask = "nightBriefingTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == morningTask) {
      await _morningBriefingTask();
    } else if (task == nightTask) {
      await _nightBriefingTask();
    }
    return Future.value(true);
  });
}

Future<void> _morningBriefingTask() async {
  await Hive.initFlutter();
  final userDataBox = await Hive.openBox('user_data');
  final tasksBox = await Hive.openBox('tasks');
  final settingsBox = await Hive.openBox('settings');
  if (!(settingsBox.get('morning_briefing_on', defaultValue: true) as bool)) return;

  final battery = Battery();
  final level = await battery.batteryLevel;
  final name = userDataBox.get('name', defaultValue: 'Boss') as String;
  final time = DateFormat('h:mm a').format(DateTime.now());
  final taskCount = tasksBox.length;
  final weather = await _getWeatherString(); // NEW

  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(const InitializationSettings(android: androidInit));
  await notifications.show(
    9001, "Good morning Boss ${name.split(' ').first}",
    "It's $time. $weather Battery: $level%. Today we have $taskCount tasks.",
    const NotificationDetails(android: AndroidNotificationDetails('dave_briefings', 'Dave Briefings', importance: Importance.high, priority: Priority.high)),
  );
}

Future<void> _nightBriefingTask() async {
  await Hive.initFlutter();
  final userDataBox = await Hive.openBox('user_data');
  final tasksBox = await Hive.openBox('tasks');
  final settingsBox = await Hive.openBox('settings');
  if (!(settingsBox.get('night_briefing_on', defaultValue: true) as bool)) return;

  final battery = Battery();
  final level = await battery.batteryLevel;
  final name = userDataBox.get('name', defaultValue: 'Boss') as String;
  final time = DateFormat('h:mm a').format(DateTime.now());
  final total = tasksBox.length;
  int doneCount = 0;
  for (final v in tasksBox.values) { if (v is Map && v['done'] == true) doneCount++; }
  final streak = userDataBox.get('prayer_streak', defaultValue: 0) as int;

  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(const InitializationSettings(android: androidInit));
  await notifications.show(
    9002, "Good night Boss ${name.split(' ').first}",
    "It's $time. Completed $doneCount/$total tasks. Battery: $level%. Prayer streak: $streak days.",
    const NotificationDetails(android: AndroidNotificationDetails('dave_briefings', 'Dave Briefings', importance: Importance.high, priority: Priority.high)),
  );
}

Future<void> _scheduleDailyBriefings() async {
  await Workmanager().registerPeriodicTask("1", morningTask, frequency: const Duration(hours: 24), initialDelay: _getInitialDelay(7, 0), constraints: Constraints(networkType: NetworkType.not_required, requiresBatteryNotLow: false, requiresCharging: false));
  await Workmanager().registerPeriodicTask("2", nightTask, frequency: const Duration(hours: 24), initialDelay: _getInitialDelay(22, 0), constraints: Constraints(networkType: NetworkType.not_required, requiresBatteryNotLow: false, requiresCharging: false));
}

Duration _getInitialDelay(int hour, int minute) {
  final now = DateTime.now();
  var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
  if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
  return scheduled.difference(now);
}

// NEW: WEATHER FUNCTION
Future<String> _getWeatherString() async {
  try {
    // Using free open-meteo API. No key needed. Ibadan default
    final res = await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=7.3775&longitude=3.9470&current=temperature_2m,weathercode'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final temp = data['current']['temperature_2m'];
      return "Ibadan is ${temp}°C. ";
    }
  } catch (_) {}
  return "Weather unavailable offline. ";
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DaveService.instance.init();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await _scheduleDailyBriefings();
  try { await [Permission.microphone, Permission.notification].request(); } catch (_) {}
  runApp(const DaveAIApp());
}

class DaveAIApp extends StatelessWidget {
  const DaveAIApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAVE AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFF0A0A0F), colorScheme: const ColorScheme.dark(primary: Color(0xFF4A90E2), secondary: Color(0xFF8B5CF6), tertiary: Color(0xFFFFD700), surface: Color(0xFF0A0A0F))),
      home: const DaveHomePage(), // CHANGED: Was SplashScreen
    );
  }
}

// NEW: MAIN PAGE WITH ALL 5 UPGRADES
class DaveHomePage extends StatefulWidget {
  const DaveHomePage({super.key});
  @override
  State<DaveHomePage> createState() => _DaveHomePageState();
}

class _DaveHomePageState extends State<DaveHomePage> {
  String _status = "Tap mic and say 'Hey Dave'";
  bool _isListening = false;
  final List<Map<String, String>> _chat = []; // NEW: MEMORY
  final _tts = DaveService.instance.tts;
  final _stt = DaveService.instance.stt;

  @override
  void initState() {
    super.initState();
    _initSTT();
  }

  void _initSTT() async {
    await _stt.initialize();
    _stt.setRecognitionResultHandler((result) {
      if (result.finalResult) {
        _handleCommand(result.recognizedWords.toLowerCase());
      }
    });
  }

  void _handleCommand(String command) async {
    setState(() {
      _isListening = false;
      _chat.add({"role": "user", "text": command}); // MEMORY 1
    });

    String reply = "I didn't catch that Boss";

    // UPGRADE 4: FUZZY WAKE WORD
    if (command.contains("hey dave") || command.contains("a dave")) {
      if (command.contains("morning briefing")) {
        final weather = await _getWeatherString();
        reply = "Good morning Boss. $weather Today we dey attack.";
      } else {
        reply = "Yes Boss, I dey here";
      }
    }

    setState(() {
      _chat.add({"role": "dave", "text": reply}); // MEMORY 2
      _status = reply;
    });

    // UPGRADE 3: STREAMING TTS
    _tts.speak(reply);
  }

  void _toggleListening() async {
    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
    } else {
      await _stt.listen(localeId: "en_US");
      setState(() => _isListening = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DAVE AI")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder( // MEMORY CHAT UI
              itemCount: _chat.length,
              itemBuilder: (ctx, i) {
                final msg = _chat[i];
                return Align(
                  alignment: msg["role"] == "user"? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: msg["role"] == "user"? Colors.blue : Colors.grey[800], borderRadius: BorderRadius.circular(12)),
                    child: Text(msg["text"]!),
                  ),
                );
              },
            ),
          ),
          Text(_status),
          // UPGRADE 5: PULSING MIC
          GestureDetector(
            onTap: _toggleListening,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(shape: BoxShape.circle, color: _isListening? Colors.red : Colors.blue),
              child: Icon(_isListening? Icons.mic : Icons.mic_none, size: 40, color: Colors.white),
            ).animate(target: _isListening? 1 : 0).scale(duration: 600.ms).then().scale(duration: 600.ms), // PULSE
          ),
        ],
      ),
    );
  }
}
