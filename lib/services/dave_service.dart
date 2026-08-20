import 'dart:io';
import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:workmanager/workmanager.dart';
import 'package:flutter_llama/flutter_llama.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Hive.initFlutter();
    final DaveService dave = DaveService.instance;
    await dave.init();
    if (task == "morningBriefing") {
      String briefing = await dave.buildMorningBriefing();
      await dave.speak(briefing);
      await dave.notifications.show(1, "🌅 DAVE AI Morning", briefing, const NotificationDetails(android: AndroidNotificationDetails('morning_channel', 'Morning Briefing', importance: Importance.max)));
    }
    if (task == "nightBriefing") {
      String briefing = await dave.buildNightBriefing();
      await dave.speak(briefing);
      await dave.notifications.show(2, "🌙 DAVE AI Night", briefing, const NotificationDetails(android: AndroidNotificationDetails('night_channel', 'Night Briefing', importance: Importance.max)));
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
  FlutterLlama? _llama;
  bool _llmReady = false;
  final Random _rand = Random();
  final String masterName = "DAVID";
  final String modelUrl = "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";
  final String modelFileName = "tinyllama.gguf";
  final Map<String, String> familyContacts = {"dad": "08056710546", "father": "08056710546", "mum": "08055633348", "mother": "08055633348", "sister": "2347086930269", "sis": "2347086930269", "bro": "2349122362006", "brother": "2349122362006"};
  static const starting = ["We outside Boss", "Say no more", "I got you", "On God"];
  static const greetings = ["Welcome back Boss", "Hey man", "Wazup Boss"];
  static const jokes = ["Why did the AI go to therapy? Too many bytes."];
  final List<String> myGreetings = ["hey dave", "yo dave", "hello", "hi"];
  String pick(List<String> bank) => bank[_rand.nextInt(bank.length)];
  bool get catchPhrasesOn => settingsBox.get('catchPhrases_on', defaultValue: true) as bool;
  String withCatchphrase(String base, [List<String> bank = starting]) => catchPhrasesOn? "${pick(bank)} $base" : base;

  Future<String> chat(String message) async {
    recordActivity();
    if(!_llmReady) return "Brain still downloading Boss, wait 2 minutes on wifi";
    String? actionResult = await _handleActions(message);
    if(actionResult!= null) return actionResult;
    String systemPrompt = "User: $message\nAssistant:";
    try {
      String response = await _llama!.prompt(systemPrompt);
      response = response.replaceAll("Assistant:", "").trim();
      await speak(response);
      return response;
    } catch (e) {
      String fallback = getResponse(message);
      await speak(fallback);
      return fallback;
    }
  }

  Future<void> _initLLM() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = "${dir.path}/$modelFileName";
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        await speak("Downloading AI brain. 669MB. Please use wifi Boss");
        final dio = Dio();
        await dio.download(modelUrl, modelPath);
        await speak("Download complete Boss. Loading brain");
      }
      _llama = FlutterLlama();
      await _llama!.loadModel(modelPath);
      _llmReady = true;
      await speak("Brain online Boss");
    } catch (e) {
      _llmReady = false;
      await speak("Brain failed to load Boss");
      print("LLM Error: $e");
    }
  }

  Future<void> init() async {
    await Hive.initFlutter();
    conversationsBox = await Hive.openBox('conversations');
    userDataBox = await Hive.openBox('user_data');
    tasksBox = await Hive.openBox('tasks');
    settingsBox = await Hive.openBox('settings');
    if (userDataBox.get('name') == null) userDataBox.put('name', masterName);
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await notifications.initialize(initSettings);
    await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.48);
    await tts.setPitch(1.0);
    recordActivity();
    await _initLLM();
    await scheduleBriefings();
  }

  Future<String?> _handleActions(String text) async {
    text = text.toLowerCase();
    for (String name in familyContacts.keys) {
      if(text.contains("call $name")) {
        String number = familyContacts[name]!;
        await speak("Calling $name now Boss");
        await FlutterPhoneDirectCaller.callNumber(number);
        return "Calling $name";
      }
    }
    return null;
  }
  Future<void> speak(String text) async { await tts.stop(); await tts.speak(text); }
  void recordActivity() => settingsBox.put('last_activity', DateTime.now().toIso8601String());
  String getResponse(String rawInput) {
    final input = rawInput.toLowerCase().trim();
    if (myGreetings.any((g) => input.contains(g))) return withCatchphrase(pick(greetings));
    if (input.contains("time")) return withCatchphrase("It's ${DateFormat('h:mm a').format(DateTime.now())}, Boss.");
    if (input.contains("joke")) return withCatchphrase(pick(jokes));
    return withCatchphrase("I hear you Master $masterName");
  }
  Future<String> buildMorningBriefing() async => "Good morning Master $masterName. Battery: ${await battery.batteryLevel}%. Let's go get it.";
  Future<String> buildNightBriefing() async => "Good night Master $masterName. Battery: ${await battery.batteryLevel}%. Rest now.";
  Future<void> scheduleBriefings() async => await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
}
