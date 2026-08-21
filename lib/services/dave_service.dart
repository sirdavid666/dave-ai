import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:workmanager/workmanager.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart'; // FIX 1: Removed alias
import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:record/record.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const String GITHUB_BASE = "https://github.com/sirdavid666/DAVE/releases/download/v0.1.0/";
const String morningTask = "morningBriefing";
const String nightTask = "nightBriefing";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final DaveService dave = DaveService.instance;
    await dave.initBackground();
    if (task == morningTask) {
      String briefing = await dave.buildMorningBriefing();
      await dave.speak(briefing);
      await dave.notifications.show(1, "🌅 DAVE AI Morning", briefing, const NotificationDetails(android: AndroidNotificationDetails('morning_channel', 'Morning Briefing', importance: Importance.max)));
    }
    if (task == nightTask) {
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

  final String masterName = "David";
  final FlutterTts tts = FlutterTts();
  final Battery battery = Battery();
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  final WhisperController _whisper = WhisperController();
  final Llama _llama = Llama(); // FIX 2: No llama. prefix
  final AudioRecorder _recorder = AudioRecorder();
  final Dio _dio = Dio();
  late SharedPreferences _prefs;

  StreamSubscription<String>? _llamaSubscription;
  String? _whisperModelPath;
  String? _llamaModelPath;
  bool _llmReady = false;
  bool _isSpeaking = false;
  final Random _rand = Random();

  final Map<String, String> familyContacts = {
    "dad": "08056710546", "father": "08056710546", "daddy": "08056710546",
    "mum": "08055633348", "mother": "08055633348", "mummy": "08055633348",
    "sister": "+2347086930269", "sis": "+2347086930269",
    "brother": "+2349122362006", "bro": "+2349122362006"
  };

  static const starting = ["We outside Boss", "Say no more", "I got you", "On God", "Locked in"];
  static const greetings = ["Welcome back Boss", "Hey man", "Wazup Boss", "Yes Boss, I'm here"];
  static const jokes = ["Why did the AI go to therapy? Too many bytes."];
  final List<String> myGreetings = ["hey dave", "yo dave", "hello", "hi", "dave"];

  ValueNotifier<String> status = ValueNotifier("Starting DAVE...");
  ValueNotifier<String> transcript = ValueNotifier("");
  ValueNotifier<String> response = ValueNotifier("");

  String pick(List<String> bank) => bank[_rand.nextInt(bank.length)];
  bool get catchPhrasesOn => _prefs.getBool('catchPhrases_on')?? true;
  String withCatchphrase(String base, [List<String> bank = starting]) => catchPhrasesOn? "${pick(bank)} $base" : base;

  Future<void> initBackground() async { _prefs = await SharedPreferences.getInstance(); }

  Future<void> init() async {
    await initBackground();
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await notifications.initialize(initSettings);
    await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.48);
    tts.setCompletionHandler(() { _isSpeaking = false; status.value = 'Ready — Tap to talk Boss'; });
    recordActivity();
    await _initModels();
    await scheduleBriefings();
  }

  Future<String> _downloadAndCombineModel(String baseName, int parts, String extension) async {
    final directory = await getApplicationDocumentsDirectory();
    final modelsDirectory = Directory('${directory.path}/DAVE/release');
    if (!await modelsDirectory.exists()) await modelsDirectory.create(recursive: true);
    final String finalPath = '${modelsDirectory.path}/$baseName.$extension';
    final File finalFile = File(finalPath);
    if (await finalFile.exists()) return finalPath;
    for(int i = 1; i <= parts; i++) {
      String partName = '${baseName}-${i.toString().padLeft(3, '0')}.$extension';
      String partUrl = '$GITHUB_BASE$partName';
      String partPath = '${modelsDirectory.path}/$partName';
      if(!await File(partPath).exists()) {
        status.value = "Downloading $partName...";
        await _dio.download(partUrl, partPath);
      }
    }
    status.value = "Combining $baseName...";
    final sink = finalFile.openWrite();
    for(int i = 1; i <= parts; i++) {
      String partName = '${baseName}-${i.toString().padLeft(3, '0')}.$extension';
      String partPath = '${modelsDirectory.path}/$partName';
      await sink.addStream(File(partPath).openRead());
    }
    await sink.close();
    return finalPath;
  }

  Future<void> _initModels() async {
    try {
      status.value = "Checking/Downloading Models...";
      _llamaModelPath = await _downloadAndCombineModel('tinyllama', 32, 'gguf');
      _whisperModelPath = await _downloadAndCombineModel('ggml-base', 7, 'bin');
      status.value = "Loading AI Brain...";
      await _llama.loadModel(modelPath: _llamaModelPath!);
      _llmReady = true;
      status.value = 'Ready — Tap to talk Boss';
      await speak("Brain online Boss. Tap to talk");
    } catch (e) {
      _llmReady = false;
      status.value = "Brain failed: $e";
      await speak("Brain failed to load Boss");
      debugPrint("LLM Error: $e");
    }
  }

  Future<void> startListening() async {
    if (!_llmReady || _isSpeaking) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) { status.value = "Microphone permission needed"; return; }
    status.value = "DAVE is listening...";
    transcript.value = "";
    response.value = "";
    final command = await _captureCommand();
    if (command == null || command.isEmpty) { 
      await speak('I did not hear a command.'); 
      status.value = 'Ready — Tap to talk Boss';
      return; 
    }
    await chat(command);
  }

  Future<String?> _captureCommand() async {
    // FIX 3: record 4.4.4 uses this
    await _recorder.start(path: null, encoder: AudioEncoder.wav);
    await Future.delayed(const Duration(seconds: 4));
    final path = await _recorder.stop();
    if(path == null) return null;
    
    // FIX 4: whisper_ggml 2.6.0 uses 'path' and 'lang'
    final result = await _whisper.transcribe(
      path: path,
      lang: 'en',
    );
    return result.text;
  }

  Future<String> chat(String message) async {
    recordActivity();
    transcript.value = message;
    String? actionResult = await _handleActions(message);
    if(actionResult!= null) { response.value = actionResult; return actionResult; }
    if(!_llmReady) {
      String fallback = getResponse(message);
      await speak(fallback);
      response.value = fallback;
      return fallback;
    }
    try {
      status.value = "Thinking offline...";
      final buffer = StringBuffer();
      final prompt = 'You are DAVE AI, voice assistant of Master $masterName. Be concise. User: $message\nAssistant:';
      _llamaSubscription = _llama.generate(prompt: prompt, maxTokens: 150, temperature: 0.7).listen((token) {
        buffer.write(token); response.value = buffer.toString();
      });
      await _llamaSubscription!.asFuture<void>();
      String result = buffer.toString().trim();
      _saveConversation(message, result);
      await speak(result);
      status.value = 'Ready — Tap to talk Boss';
      return result;
    } catch (e) {
      String fallback = getResponse(message);
      await speak(fallback);
      response.value = fallback;
      return fallback;
    }
  }

  Future<String?> _handleActions(String text) async {
    String lower = text.toLowerCase();
    for (String name in familyContacts.keys) {
      if(lower.contains("call $name")) {
        String number = familyContacts[name]!;
        await speak("Calling $name now Boss");
        final Uri telUri = Uri.parse('tel:$number');
        if (await canLaunchUrl(telUri)) { await launchUrl(telUri); }
        return "Calling $name";
      }
    }
    if(lower.contains("message") && lower.contains("whatsapp")) {
      try {
        String name = lower.split("message")[1].split("on whatsapp")[0].trim();
        String msg = text.contains(":")? text.split(":")[1].trim() : "Hi Boss";
        String number = familyContacts[name]?? "";
        if(number.isEmpty) return "I don't have $name's number Boss";
        final Uri url = Uri.parse("https://wa.me/$number?text=${Uri.encodeComponent(msg)}");
        if(await canLaunchUrl(url)) { await launchUrl(url); return "Opening WhatsApp for $name Boss"; }
      } catch(e) { print(e); }
    }
    return null;
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    _isSpeaking = true;
    status.value = "DAVE is speaking...";
    await tts.stop();
    await tts.speak(text);
  }

  void recordActivity() => _prefs.setString('last_activity', DateTime.now().toIso8601String());
  void _saveConversation(String user, String dave) {
    List<String> history = _prefs.getStringList('chat_history')?? [];
    history.add(jsonEncode({"user": user, "dave": dave, "time": DateTime.now().toString()}));
    _prefs.setStringList('chat_history', history);
  }
  String getResponse(String rawInput) {
    final input = rawInput.toLowerCase().trim();
    if (myGreetings.any((g) => input.contains(g))) return withCatchphrase(pick(greetings));
    if (input.contains("time")) return withCatchphrase("It's ${DateFormat('h:mm a').format(DateTime.now())}, Boss.");
    if (input.contains("battery")) return withCatchphrase("Let me check Boss");
    if (input.contains("joke")) return withCatchphrase(pick(jokes));
    if (input.contains("remember")) return withCatchphrase("Got it Boss. Saved to memory");
    return withCatchphrase("I hear you Master $masterName");
  }
  Future<String> buildMorningBriefing() async { int batt = await battery.batteryLevel; return "Good morning Master $masterName. Battery: $batt%. Let's go get it Boss."; }
  Future<String> buildNightBriefing() async { int batt = await battery.batteryLevel; return "Good night Master $masterName. Battery: $batt%. Rest now Boss."; }
  Future<void> scheduleBriefings() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(morningTask, morningTask, frequency: const Duration(hours: 24));
    await Workmanager().registerPeriodicTask(nightTask, nightTask, frequency: const Duration(hours: 24));
  }
  void dispose() { _llamaSubscription?.cancel(); _recorder.dispose(); tts.stop(); _llama.dispose(); }
}
