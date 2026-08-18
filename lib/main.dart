import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart'; // REPLACED android_alarm_manager_plus
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import 'dave_service.dart';
import 'splash_screen.dart';

// ---------------------------------------------------------------------
// WORKMANAGER TASK NAMES
// ---------------------------------------------------------------------
const String morningTask = "morningBriefingTask";
const String nightTask = "nightBriefingTask";

// THIS RUNS IN BACKGROUND AT 7:00 AM
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
  if (!(settingsBox.get('morning_briefing_on', defaultValue: true) as bool)) {
    return;
  }
  final battery = Battery();
  final level = await battery.batteryLevel;
  final name = userDataBox.get('name', defaultValue: 'Boss') as String;
  final time = DateFormat('h:mm a').format(DateTime.now());
  final taskCount = tasksBox.length;

  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
    const InitializationSettings(android: androidInit),
  );
  await notifications.show(
    9001,
    "Good morning Boss ${name.split(' ').first}",
    "It's $time. Battery: $level%. Today we have $taskCount tasks. Let's go get it.",
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'dave_briefings',
        'Dave Briefings',
        channelDescription: 'Morning and night briefings from Dave',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

// THIS RUNS IN BACKGROUND AT 10:00 PM
Future<void> _nightBriefingTask() async {
  await Hive.initFlutter();
  final userDataBox = await Hive.openBox('user_data');
  final tasksBox = await Hive.openBox('tasks');
  final settingsBox = await Hive.openBox('settings');
  if (!(settingsBox.get('night_briefing_on', defaultValue: true) as bool)) {
    return;
  }
  final battery = Battery();
  final level = await battery.batteryLevel;
  final name = userDataBox.get('name', defaultValue: 'Boss') as String;
  final time = DateFormat('h:mm a').format(DateTime.now());
  final total = tasksBox.length;
  int doneCount = 0;
  for (final v in tasksBox.values) {
    if (v is Map && v['done'] == true) doneCount++;
  }
  final streak = userDataBox.get('prayer_streak', defaultValue: 0) as int;

  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
    const InitializationSettings(android: androidInit),
  );
  await notifications.show(
    9002,
    "Good night Boss ${name.split(' ').first}",
    "It's $time. Completed $doneCount/$total tasks today. Battery at $level%. "
        "Prayer streak: $streak days. Rest now — tomorrow we attack again.",
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'dave_briefings',
        'Dave Briefings',
        channelDescription: 'Morning and night briefings from Dave',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

Future<void> _scheduleDailyBriefings() async {
  // 7:00 AM daily
  await Workmanager().registerPeriodicTask(
    "1",
    morningTask,
    frequency: const Duration(hours: 24),
    initialDelay: _getInitialDelay(7, 0),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
      requiresCharging: false,
    ),
  );
  
  // 10:00 PM daily  
  await Workmanager().registerPeriodicTask(
    "2",
    nightTask,
    frequency: const Duration(hours: 24),
    initialDelay: _getInitialDelay(22, 0),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
      requiresCharging: false,
    ),
  );
}

Duration _getInitialDelay(int hour, int minute) {
  final now = DateTime.now();
  var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled.difference(now);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Core data + services must be ready before the UI touches them.
  await DaveService.instance.init();

  // BACKGROUND WORKMANAGER FOR PROACTIVE MORNING/NIGHT BRIEFINGS
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await _scheduleDailyBriefings();

  // Ask for the permissions Dave actually needs, up front.
  try {
    await [
      Permission.microphone,
      Permission.notification,
    ].request();
  } catch (_) {
    // Non-fatal — pages re-check permission state before using mic/notifications.
  }

  runApp(const DaveAIApp());
}

class DaveAIApp extends StatelessWidget {
  const DaveAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAVE AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4A90E2),
          secondary: Color(0xFF8B5CF6),
          tertiary: Color(0xFFFFD700),
          surface: Color(0xFF0A0A0F),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0F),
          elevation: 0,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      home: const SplashScreen(),
    );
  }
}
