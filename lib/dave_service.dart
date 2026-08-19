import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models/dave_models.dart';

class DaveService {
  DaveService._internal();
  static final DaveService instance = DaveService._internal();

  final FlutterTts tts = FlutterTts();
  final Battery battery = Battery();
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  late Box conversationsBox;
  late Box userDataBox;
  late Box tasksBox;
  late Box settingsBox;

  final Random _rand = Random();

  static const greetings = ["Welcome back Boss", "We outside Boss", "Yes Boss, I dey here"];
  static const starting = ["On it Boss", "Consider it done Boss", "Locked in Boss"];
  static const encouraging = ["You got this Boss", "God's got you Boss", "We move Boss"];
  static const done = ["All set Boss", "Job complete Boss"];
  static const jokes = [
    "Why did the AI go to therapy? Too many bytes.",
    "I told my computer I needed a break, now it won't stop sending me KitKats.",
    "What do you call a robot that does laundry? A washine."
  ];

  String pick(List<String> bank) => bank[_rand.nextInt(bank.length)];

  bool get catchPhrasesOn => settingsBox.get('catchPhrases_on', defaultValue: true) as bool;
  
  String withCatchphrase(String base, [List<String> bank = starting]) {
    if (!catchPhrasesOn) return base;
    return "${pick(bank)} $base";
  }

  Future<void> init() async {
    await Hive.initFlutter();
    conversationsBox = await Hive.openBox('conversations');
    userDataBox = await Hive.openBox('user_data');
    tasksBox = await Hive.openBox('tasks');
    settingsBox = await Hive.openBox('settings');

    if (userDataBox.get('name') == null) {
      userDataBox.put('name', 'David Emeoluma');
    }

    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await notifications.initialize(initSettings);

    await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.48);
    await tts.setPitch(1.0);
    recordActivity();
  }

  Future<void> speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  void recordActivity() {
    settingsBox.put('last_activity', DateTime.now().toIso8601String());
  }

  bool get isAfterFourHours {
    final lastStr = settingsBox.get('last_activity') as String?;
    if (lastStr == null) return false;
    final last = DateTime.parse(lastStr);
    return DateTime.now().difference(last).inHours >= 4;
  }

  String getResponse(String rawInput) {
    recordActivity();
    final input = rawInput.toLowerCase().trim();
    if (input.isEmpty) return "I didn't catch that, Boss. Say again?";

    final reminderMatch = RegExp(r'remind me to (.+) at (\d{1,2}):(\d{2})\s?(am|pm)?', caseSensitive: false).firstMatch(input);
    if (reminderMatch != null) {
      return _handleReminder(reminderMatch);
    }

    if (input.contains("hello") || input.contains("hi") || input.contains("good morning") || input.contains("good afternoon") || input.contains("good evening")) {
      return pick(greetings);
    }

    if (input.contains("time")) {
      return withCatchphrase("It's ${DateFormat('h:mm a').format(DateTime.now())}, Boss.");
    }

    if (input.contains("date") || input.contains("today")) {
      return withCatchphrase("Today is ${DateFormat('EEEE, MMM d, y').format(DateTime.now())}.");
    }

    if (input.contains("battery")) {
      return "Checking battery for you, Boss - see the live reading in Settings.";
    }

    if (input.contains("joke")) {
      return pick(jokes);
    }

    if (input.contains("thank")) {
      return "Anytime, Boss. That's what I'm here for.";
    }

    if (input.contains("tired") || input.contains("stressed") || input.contains("sad") || input.contains("down")) {
      return "${pick(encouraging)} Take a breath - you've handled worse than this.";
    }

    if (input.contains("prayer")) {
      final streak = userDataBox.get('prayer_streak', defaultValue: 0) as int;
      return "Your current prayer streak is $streak days, Boss. ${pick(encouraging)}";
    }

    return "I'm offline, Boss - I can do time, date, jokes, reminders, and track your memory & tasks. Try 'remind me to pray at 5am'.";
  }

  String _handleReminder(RegExpMatch match) {
    final taskTitle = match.group(1)!.trim();
    final hourRaw = int.parse(match.group(2)!);
    final minute = match.group(3) != null ? int.parse(match.group(3)!) : 0;
    final meridium = match.group(4);

    int hour = hourRaw;
    if (meridium == 'pm' && hour < 12) hour += 12;
    if (meridium == 'am' && hour == 12) hour = 0;

    var due = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, hour, minute);
    if (due.isBefore(DateTime.now())) {
      due = due.add(const Duration(days: 1));
    }

    final task = DaveTask(id: DateTime.now().millisecondsSinceEpoch.toString(), title: taskTitle, dueTime: due);
    tasksBox.put(task.id, task.toMap());
    _scheduleTaskNotification(task);

    final timeStr = DateFormat('h:mm a').format(due);
    return withCatchphrase("I'll remind you to $taskTitle at $timeStr.");
  }

  Future<void> _scheduleTaskNotification(DaveTask task) async {
    if (task.dueTime == null) return;
    final scheduled = tz.TZDateTime.from(task.dueTime!, tz.local);
    await notifications.zonedSchedule(
      task.id.hashCode, "DAVE AI Reminder", task.title, scheduled,
      const NotificationDetails(android: AndroidNotificationDetails('dave_reminders', 'Dave Reminders', channelDescription: 'Task and prayer reminders from Dave', importance: Importance.high, priority: Priority.high)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  List<DaveTask> get allTasks => tasksBox.values.map((n) => DaveTask.fromMap(Map.from(n))).toList();
  int get tasksTodayCount => allTasks.length;
  int get tasksDoneCount => allTasks.where((t) => t.done).length;

  void toggleTaskDone(DaveTask task) {
    task.done = !task.done;
    tasksBox.put(task.id, task.toMap());
  }

  void deleteTask(DaveTask task) => tasksBox.delete(task.id);

  Map<String, dynamic> get memoryFacts => Map<String, dynamic>.from(userDataBox.toMap());
  void addMemoryFact(String key, String value) => userDataBox.put(key, value);
  void deleteMemoryFact(String key) => userDataBox.delete(key);

  Future<int> currentBatteryLevel() async => await battery.batteryLevel;

  Future<String> buildMorningBriefing() async {
    final level = await battery.batteryLevel;
    final name = userDataBox.get('name', defaultValue: 'Boss') as String;
    final time = DateFormat('h:mm a').format(DateTime.now());
    return "Good morning $name. It's $time. Battery: $level%. Today we have ${tasksTodayCount} tasks. Let's go get it.";
  }

  Future<String> buildNightBriefing() async {
    final level = await battery.batteryLevel;
    final name = userDataBox.get('name', defaultValue: 'Boss') as String;
    final time = DateFormat('h:mm a').format(DateTime.now());
    return "Good night ${name.split(' ').first}. It's $time. Today we completed ${tasksDoneCount}/${tasksTodayCount} tasks. Not bad. Battery at $level%. Charge your phone. Proud of you for not breaking your prayer streak. Rest now. Tomorrow we attack again.";
  }

  // This is a placeholder for now so the app builds
  // We will add real notifications later after the APK works
  Future<void> scheduleBriefings() async {
    print("DAVE: Briefings scheduled - placeholder");
  }
}
