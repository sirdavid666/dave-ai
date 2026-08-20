import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

// SIMPLE MODEL INSIDE SO WE DON'T NEED models/dave_models.dart
class DaveTask {
  String id;
  String title;
  DateTime? dueTime;
  bool done;

  DaveTask({required this.id, required this.title, this.dueTime, this.done = false});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dueTime': dueTime?.toIso8601String(),
      'done': done,
    };
  }

  factory DaveTask.fromMap(Map map) {
    return DaveTask(
      id: map['id'],
      title: map['title'],
      dueTime: map['dueTime'] != null ? DateTime.parse(map['dueTime']) : null,
      done: map['done'] ?? false,
    );
  }
}

// TOP LEVEL FUNCTION FOR WORKMANAGER
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Hive.initFlutter();
    final DaveService dave = DaveService.instance;
    await dave.init();

    if (task == "morningBriefing") {
      String briefing = await dave.buildMorningBriefing();
      await dave.speak(briefing);
      await dave.notifications.show(
        1, "🌅 DAVE AI Morning", briefing,
        const NotificationDetails(android: AndroidNotificationDetails('morning_channel', 'Morning Briefing', importance: Importance.max))
      );
    }
    if (task == "nightBriefing") {
      String briefing = await dave.buildNightBriefing();
      await dave.speak(briefing);
      await dave.notifications.show(
        2, "🌙 DAVE AI Night", briefing,
        const NotificationDetails(android: AndroidNotificationDetails('night_channel', 'Night Briefing', importance: Importance.max))
      );
    }
    return Future.value(true);
  });
}

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
  final String masterName = "DAVID";

  // YOUR CATCHPHRASES
  static const starting = [
    "We outside Boss", "Say no more", "I got you", "On God", 
    "No stress", "Locked in Boss", "On it Boss", "Consider it done Boss"
  ];
  static const greetings = [
    "Welcome back Boss", "Hey man", "Hey buddy", "Wazup Boss", "Yes Boss, I dey here"
  ];
  static const encouraging = ["You got this Boss", "God's got you Boss", "We move Boss"];
  static const done = ["All set Boss", "Job complete Boss"];
  static const jokes = [
    "Why did the AI go to therapy? Too many bytes.",
    "I told my computer I needed a break, now it won't stop sending me KitKats.",
    "What do you call a robot that does laundry? A washine."
  ];

  // YOUR PHRASES - FIXED: buddy not body
  final List<String> myGreetings = [
    "hey dave", "yo dave", "daveeee", "yo man", "hey man", "hey buddy",
    "what's up dude", "whats up dude", "what's up man", "wazup", "wazzup",
    "good morning", "good afternoon", "good evening", "you there", "you dey", "hello", "hi"
  ];
  final List<String> myCheckins = [
    "how are you", "you good", "you good?", "how buddy", "how's it going", 
    "how is it going", "everything cool", "you dey alright", "you ok"
  ];

  String pick(List<String> bank) => bank[_rand.nextInt(bank.length)];

  bool get catchPhrasesOn => settingsBox.get('catchPhrases_on', defaultValue: true) as bool;
  
  String withCatchphrase(String base, [List<String> bank = starting]) {
    if (!catchPhrasesOn) return base;
    return "${pick(bank)} $base";
  }

  // ADDED THIS FOR CHAT SCREEN
  Future<String> chat(String message) async {
    return getResponse(message);
  }

  Future<void> init() async {
    await Hive.initFlutter();
    conversationsBox = await Hive.openBox('conversations');
    userDataBox = await Hive.openBox('user_data');
    tasksBox = await Hive.openBox('tasks');
    settingsBox = await Hive.openBox('settings');

    if (userDataBox.get('name') == null) {
      userDataBox.put('name', masterName);
    }

    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await notifications.initialize(initSettings);

    await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.48);
    await tts.setPitch(1.0);
    recordActivity();

    await scheduleBriefings();
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

    if (myGreetings.any((g) => input.contains(g))) {
      return withCatchphrase(pick(greetings));
    }

    if (myCheckins.any((c) => input.contains(c))) {
      List<String> replies = [
        "I'm solid Boss, just waiting on you",
        "I'm good man, battery dey low small but we move",
        "I'm here for you Boss"
      ];
      return withCatchphrase(pick(replies));
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
      return withCatchphrase(pick(jokes));
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

    return withCatchphrase("I hear you Master $masterName. I can do time, date, battery, jokes, and reminders. Wetin you want me do?");
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
    final name = userDataBox.get('name', defaultValue: masterName) as String;
    final time = DateFormat('h:mm a').format(DateTime.now());
    return "Good morning Master $name. We outside. It's $time. Battery: $level%. Today we have ${tasksTodayCount} tasks. Let's go get it.";
  }

  Future<String> buildNightBriefing() async {
    final level = await battery.batteryLevel;
    final name = userDataBox.get('name', defaultValue: masterName) as String;
    final time = DateFormat('h:mm a').format(DateTime.now());
    return "Good night ${name.split(' ').first}. It's $time. Today we completed ${tasksDoneCount}/${tasksTodayCount} tasks. Not bad. Battery at $level%. Charge your phone. Proud of you Master $name. Rest now. Tomorrow we attack again.";
  }

  Future<void> scheduleBriefings() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    
    bool morningOn = settingsBox.get('morningBriefing_on', defaultValue: true) as bool;
    bool nightOn = settingsBox.get('nightBriefing_on', defaultValue: true) as bool;

    if(morningOn) {
      await Workmanager().registerPeriodicTask(
        "morningBriefing", "morningBriefing",
        frequency: const Duration(days: 1),
        initialDelay: _timeUntil(7, 0),
        constraints: Constraints(networkType: NetworkType.not_required),
      );
    }
    
    if(nightOn) {
      await Workmanager().registerPeriodicTask(
        "nightBriefing", "nightBriefing",
        frequency: const Duration(days: 1),
        initialDelay: _timeUntil(22, 0),
        constraints: Constraints(networkType: NetworkType.not_required),
      );
    }
  }

  Duration _timeUntil(int hour, int minute) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));
    return target.difference(now);
  }
}
