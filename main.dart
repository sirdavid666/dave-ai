import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import 'dave_service.dart';
import 'splash_screen.dart';

// ---------------------------------------------------------------------
// IMPORTANT NOTE ON BACKGROUND BRIEFINGS:
// android_alarm_manager_plus fires this callback in a separate background
// isolate where the app UI isn't running. Speaking reliably via flutter_tts
// from a background isolate is not dependable on modern Android (OEM
// battery restrictions frequently kill it). So this callback instead posts
// a local NOTIFICATION with the full briefing text — it always works,
// even with the app closed. If DAVE AI is open in the foreground when
// 7:00 AM / 10:00 PM hits, the Voice tab additionally SPEAKS the briefing
// out loud (see home_shell.dart timer check). This is the reliable
// real-world version of "proactive Jarvis mode" on Android.
// ---------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> morningBriefingCallback() async {
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

@pragma('vm:entry-point')
Future<void> nightBriefingCallback() async {
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
  await AndroidAlarmManager.periodic(
    const Duration(hours: 24),
    1001,
    morningBriefingCallback,
    startAt: _nextInstanceOfTime(7, 0),
    exact: true,
    wakeup: true,
    rescheduleOnReboot: true,
  );
  // 10:00 PM daily
  await AndroidAlarmManager.periodic(
    const Duration(hours: 24),
    1002,
    nightBriefingCallback,
    startAt: _nextInstanceOfTime(22, 0),
    exact: true,
    wakeup: true,
    rescheduleOnReboot: true,
  );
}

DateTime _nextInstanceOfTime(int hour, int minute) {
  final now = DateTime.now();
  var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Core data + services must be ready before the UI touches them.
  await DaveService.instance.init();

  // Background alarm manager for proactive morning/night briefings.
  await AndroidAlarmManager.initialize();
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
