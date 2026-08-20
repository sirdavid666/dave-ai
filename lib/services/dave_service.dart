import 'dart:io';
import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:workmanager/workmanager.dart';
import 'package:flutter_gpt_llama/flutter_gpt_llama.dart'; // TINYLLAMA BRAIN
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

const String morningTask = "morningBriefing";
const String nightTask = "nightBriefing";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Hive.initFlutter();
    final DaveService dave = DaveService.instance;
    await dave.init();
    if (task == morningTask) {
      String briefing = await dave.buildMorningBriefing();
      await dave.speak(briefing);
      await dave.notifications.show(1, "🌅 DAVE AI Morning", briefing, const NotificationDetails(android: AndroidNotificationDetails('morning_channel', 'Morning Briefing', importance: Importance.max, playSound: true)));
    }
    if (task == nightTask) {
      String briefing = await dave.buildNightBriefing();
      await dave.speak(briefing);
      await dave.notifications.show(2, "🌙 DAVE AI Night", briefing, const NotificationDetails(android: AndroidNotificationDetails('night_channel', 'Night Briefing', importance: Importance.max, playSound: true)));
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

  bool _llmReady = false;
  final Random _rand = Random();
  final String masterName = "DAVID";

  // TINYLLAMA 669MB MODEL FROM YOUR GITHUB RELEASE
  final String modelUrl = "https://github.com/sirdavid666/dave-ai/releases/download/v1.0-brain/tinyllama.gguf";
  final String modelFileName = "tinyllama.gguf";

  // FAMILY CONTACTS - ADD MORE HERE BOSS
  final Map<String, String> familyContacts = {
    "dad": "08056710546", "father": "08056710546",
    "mum": "08055633348", "mother": "08055633348",
    "sister": "2347086930269", "sis": "2347086930269",
    "bro": "2349122362006", "brother": "2349122362006"
  };

  // CATCHPHRASES
  static const starting = ["We outside Boss", "Say no more", "I got you", "On God", "Locked in"];
  static const greetings = ["Welcome back Boss", "Hey man", "Wazup Boss", "Yes Boss, I'm here"];
  static const jokes = ["Why did the AI go to therapy? Too many bytes.", "I told my computer I needed a break, it said no, it has no cache"];
  final List<String> myGreetings = ["hey dave", "yo dave", "hello", "hi", "dave"];

  String pick(List<String> bank) => bank[_rand.nextInt(bank.length)];
  bool get catchPhrasesOn => settingsBox.get('catchPhrases_on', defaultValue: true) as bool;
  String withCatchphrase(String base, [List<String> bank = starting]) => catchPhrasesOn? "${pick(bank)} $base" : base;

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
    await _initLLM(); // Download + Load TinyLlama from YOUR release
    await scheduleBriefings();
  }

  // 1. TINYLLAMA BRAIN
  Future<void> _initLLM() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = "${dir.path}/$modelFileName";
      final modelFile = File(modelPath);

      if (!await modelFile.exists()) {
        await speak("Downloading AI brain. 669MB. Please use wifi Boss");
        final dio = Dio();
        await dio.download(modelUrl, modelPath, onReceiveProgress: (rec, total) {
          if(total > 0) print("Download: ${(rec/total*100).toStringAsFixed(0)}%");
        });
        await speak("Download complete Boss. Loading brain");
      }

      await LlamaFlutter.loadModel(modelPath); // CORRECT METHOD
      _llmReady = true;
      await speak("Brain online Boss");
    } catch (e) {
      _llmReady = false;
      await speak("Brain failed to load Boss. Using offline mode");
      print("LLM Error: $e");
    }
  }

  // 2. CHAT + ACTIONS
  Future<String> chat(String message) async {
    recordActivity();

    // Check actions first: Call, WhatsApp
    String? actionResult = await _handleActions(message);
    if(actionResult!= null) {
      await speak(actionResult);
      return actionResult;
    }

    if(!_llmReady) {
      String fallback = getResponse(message);
      await speak(fallback);
      return fallback;
    }

    try {
      final prompt = "User: $message\nAssistant:";
      final response = await LlamaFlutter.prompt(prompt); // CORRECT METHOD
      String result = response.trim();
      await speak(result);
      _saveConversation(message, result);
      return result;
    } catch (e) {
      String fallback = getResponse(message);
      await speak(fallback);
      return fallback;
    }
  }

  // 3. CALL + WHATSAPP HANDLER
  Future<String?> _handleActions(String text) async {
    String lower = text.toLowerCase();

    // CALL FAMILY
    for (String name in familyContacts.keys) {
      if(lower.contains("call $name")) {
        String number = familyContacts[name]!;
        await speak("Calling $name now Boss");
        await FlutterPhoneDirectCaller.callNumber(number);
        return "Calling $name";
      }
    }

    // WHATSAPP FAMILY
    if(lower.contains("message") && lower.contains("whatsapp")) {
      try {
        String name = lower.split("message")[1].split("on whatsapp")[0].trim();
        String msg = text.contains(":")? text.split(":")[1].trim() : "Hi Boss";
        String number = familyContacts[name]?? "";
        if(number.isEmpty) return "I don't have $name's number Boss";

        final Uri url = Uri.parse("https://wa.me/$number?text=${Uri.encodeComponent(msg)}");
        if(await canLaunchUrl(url)) {
          await launchUrl(url);
          return "Opening WhatsApp for $name Boss";
        }
      } catch(e) { print(e); }
    }
    return null;
  }

  // 4. VOICE
  Future<void> speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  // 5. MEMORY + ACTIVITY
  void recordActivity() => settingsBox.put('last_activity', DateTime.now().toIso8601String());
  void _saveConversation(String user, String dave) {
    List history = conversationsBox.get('chat_history', defaultValue: []);
    history.add({"user": user, "dave": dave, "time": DateTime.now().toString()});
    conversationsBox.put('chat_history', history);
  }

  // 6. RULE-BASED FALLBACK
  String getResponse(String rawInput) {
    final input = rawInput.toLowerCase().trim();
    if (myGreetings.any((g) => input.contains(g))) return withCatchphrase(pick(greetings));
    if (input.contains("time")) return withCatchphrase("It's ${DateFormat('h:mm a').format(DateTime.now())}, Boss.");
    if (input.contains("battery")) return withCatchphrase("Let me check Boss");
    if (input.contains("joke")) return withCatchphrase(pick(jokes));
    if (input.contains("remember")) return withCatchphrase("Got it Boss. Saved to memory");
    return withCatchphrase("I hear you Master $masterName");
  }

  // 7. PROACTIVE BRIEFINGS
  Future<String> buildMorningBriefing() async {
    int batt = await battery.batteryLevel;
    return "Good morning Master $masterName. Battery: $batt%. Let's go get it Boss.";
  }

  Future<String> buildNightBriefing() async {
    int batt = await battery.batteryLevel;
    return "Good night Master $masterName. Battery: $batt%. Rest now Boss.";
  }

  Future<void> scheduleBriefings() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(morningTask, morningTask, frequency: const Duration(hours: 24));
    await Workmanager().registerPeriodicTask(nightTask, nightTask, frequency: const Duration(hours: 24));
  }
}
