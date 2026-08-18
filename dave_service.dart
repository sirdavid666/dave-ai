import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import 'models/dave_models.dart';

/// DaveService is the single brain of the app: personality, catchphrases,
/// rule-based responses, task parsing, and all the Hive/TTS/notification
/// plumbing. Pages call into this instead of touching Hive/TTS directly.
class DaveService {
  DaveService._internal();
  static final DaveService instance = DaveService._internal();

  final FlutterTts tts = FlutterTts();
  final Battery _battery = Battery();
  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  late Box conversationsBox;
  late Box userDataBox;
  late Box tasksBox;
  late Box settingsBox;

  final Random _rand = Random();

  // ---------------- CATCHPHRASES ----------------
  static const greetings = [
    "Welcome back Boss",
    "We outside Boss",
    "Yes Boss, I dey here",
  ];
  static const starting = [
    "On it Boss",
    "Consider it done Boss",
    "Locked in Boss",
  ];
  static const encouraging = [
    "You got this Boss",
    "God's got you Boss",
    "We move Boss",
  ];
  static const done = [
    "All set Boss",
    "Job complete Boss",
  ];

  String pick(List<String> bank) => bank[_rand.nextInt(bank.length)];

  bool get catchphrasesOn =>
      settingsBox.get('catchphrases_on', defaultValue: true) as bool;

  /// Wraps a base reply with a random catchphrase prefix, if enabled.
  String withCatchphrase(String base, {List<String>? bank}) {
    if (!catchphrasesOn) return base;
    final phrase = pick(bank ?? starting);
    return "$phrase. $base";
  }

  // ---------------- INIT ----------------
  Future<void> init() async {
    await Hive.initFlutter();
    conversationsBox = await Hive.openBox('conversations');
    userDataBox = await Hive.openBox('user_data');
    tasksBox = await Hive.openBox('tasks');
    settingsBox = await Hive.openBox('settings');

    // Seed default memory facts on first run.
    if (userDataBox.get('name') == null) {
      userDataBox.put('name', 'David Ewaoluwa');
    }

    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await notifications.initialize(initSettings);

    await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.48);
    await tts.setPitch(1.0);

    _recordActivity();
  }

  Future<void> speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  // ---------------- ACTIVITY TRACKING (for the 4-hour nudge) ----------------
  void _recordActivity() {
    settingsBox.put('last_activity', DateTime.now().toIso8601String());
  }

  /// Call this from every page interaction (chat send, voice command, etc.)
  void recordActivity() => _recordActivity();

  bool get idleFourHours {
    final lastStr = settingsBox.get('last_activity') as String?;
    if (lastStr == null) return false;
    final last = DateTime.parse(lastStr);
    return DateTime.now().difference(last).inHours >= 4;
  }

  // ---------------- RULE-BASED BRAIN ----------------
  /// Returns Dave's reply to free text input. Also handles task parsing
  /// ("remind me to X at Y") and stores the task if matched.
  String getResponse(String rawInput) {
    recordActivity();
    final input = rawInput.toLowerCase().trim();
    if (input.isEmpty) return "I didn't catch that, Boss. Say again?";

    // Reminder parsing: "remind me to <task> at <time>"
    final reminderMatch = RegExp(
      r'remind me to (.+?) at (\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
    ).firstMatch(input);
    if (reminderMatch != null) {
      return _handleReminder(reminderMatch);
    }

    if (input.contains("hello") ||
        input.contains("hi") ||
        input.contains("good morning") ||
        input.contains("good afternoon") ||
        input.contains("good evening")) {
      return pick(greetings);
    }

    if (input.contains("time")) {
      return withCatchphrase(
        "It's ${DateFormat('h:mm a').format(DateTime.now())}, Boss.",
        bank: greetings,
      );
    }

    if (input.contains("date") || input.contains("today")) {
      return withCatchphrase(
        "Today is ${DateFormat('EEEE, MMMM d, y').format(DateTime.now())}.",
        bank: greetings,
      );
    }

    if (input.contains("battery")) {
      return "Checking battery for you, Boss — see the live reading in Settings.";
    }

    if (input.contains("joke")) {
      final jokes = [
        "Why did the AI go to therapy? Too many bytes.",
        "I told my computer I needed a break, now it won't stop sending me KitKats.",
        "What do you call a robot that does laundry? A washine.",
      ];
      return pick(jokes);
    }

    if (input.contains("thank")) {
      return "Anytime, Boss. That's what I'm here for.";
    }

    if (input.contains("tired") ||
        input.contains("stressed") ||
        input.contains("sad") ||
        input.contains("down")) {
      return "${pick(encouraging)}. Take a breath — you've handled worse than this.";
    }

    if (input.contains("streak") || input.contains("prayer")) {
      final streak = userDataBox.get('prayer_streak', defaultValue: 0) as int;
      return "Your current prayer streak is $streak days, Boss. ${pick(encouraging)}.";
    }

    return "I'm offline, Boss — I can do time, date, jokes, reminders, "
        "and track your memory & tasks. Try 'remind me to pray at 5am'.";
  }

  String _handleReminder(RegExpMatch match) {
    final taskTitle = match.group(1)!.trim();
    final hourRaw = int.parse(match.group(2)!);
    final minute = match.group(3) != null ? int.parse(match.group(3)!) : 0;
    final meridiem = match.group(4);

    int hour = hourRaw;
    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == null && hour < 7) {
      // Heuristic: bare small hours like "5" with no am/pm and no context
      // default to AM (matches your "pray at 5am" example).
      hour = hourRaw;
    }

    var due = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      minute,
    );
    if (due.isBefore(DateTime.now())) {
      due = due.add(const Duration(days: 1));
    }

    final task = DaveTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: taskTitle,
      dueTime: due,
    );
    tasksBox.put(task.id, task.toMap());
    _scheduleTaskNotification(task);

    final timeStr = DateFormat('h:mm a').format(due);
    return withCatchphrase(
      "I'll remind you to $taskTitle at $timeStr.",
      bank: starting,
    );
  }

  Future<void> _scheduleTaskNotification(DaveTask task) async {
    if (task.dueTime == null) return;
    final scheduled = tz.TZDateTime.from(task.dueTime!, tz.local);
    await notifications.zonedSchedule(
      task.id.hashCode,
      "DAVE AI Reminder",
      task.title,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dave_reminders',
          'Dave Reminders',
          channelDescription: 'Task and prayer reminders from Dave',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ---------------- TASKS ----------------
  List<DaveTask> get allTasks =>
      tasksBox.values.map((m) => DaveTask.fromMap(m as Map)).toList();

  int get tasksTodayCount => allTasks.length;
  int get tasksDoneCount => allTasks.where((t) => t.done).length;

  void toggleTaskDone(DaveTask task) {
    task.done = !task.done;
    tasksBox.put(task.id, task.toMap());
  }

  void deleteTask(DaveTask task) => tasksBox.delete(task.id);

  // ---------------- MEMORY (facts/goals/preferences) ----------------
  Map<String, dynamic> get memoryFacts =>
      Map<String, dynamic>.from(userDataBox.toMap());

  void addMemoryFact(String key, String value) => userDataBox.put(key, value);
  void deleteMemoryFact(String key) => userDataBox.delete(key);

  // ---------------- BRIEFINGS ----------------
  Future<String> buildMorningBriefing() async {
    final level = await _battery.batteryLevel;
    final name = userDataBox.get('name', defaultValue: 'Boss') as String;
    final time = DateFormat('h:mm a').format(DateTime.now());
    return "Good morning Boss ${name.split(' ').first}. It's $time. "
        "Battery: $level%. Today we have $tasksTodayCount tasks. Let's go get it.";
  }

  Future<String> buildNightBriefing() async {
    final level = await _battery.batteryLevel;
    final name = userDataBox.get('name', defaultValue: 'Boss') as String;
    final time = DateFormat('h:mm a').format(DateTime.now());
    final streak = userDataBox.get('prayer_streak', defaultValue: 0) as int;
    return "Good night Boss ${name.split(' ').first}. It's $time. "
        "Today we completed $tasksDoneCount/$tasksTodayCount tasks. Not bad. "
        "Battery at $level%. Charge your phone. Proud of you for keeping a "
        "$streak-day prayer streak. Rest now. Tomorrow we attack again.";
  }

  Future<int> currentBatteryLevel() => _battery.batteryLevel;
}
