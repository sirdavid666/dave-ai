import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:workmanager/workmanager.dart';

const String githubBase =
    'https://github.com/sirdavid666/DAVE/releases/download/v0.1.0/';

const String morningTask = 'morningBriefing';
const String nightTask = 'nightBriefing';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final dave = DaveService.instance;

      await dave.initBackground();

      if (task == morningTask) {
        final text = await dave.buildMorningBriefing();

        await dave.notifications.show(
          1,
          '🌅 DAVE AI Morning',
          text,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'morning_channel',
              'Morning Briefing',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }

      if (task == nightTask) {
        final text = await dave.buildNightBriefing();

        await dave.notifications.show(
          2,
          '🌙 DAVE AI Night',
          text,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'night_channel',
              'Night Briefing',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  });
}

class DaveService {
  DaveService._internal();

  static final DaveService instance = DaveService._internal();

  final String masterName = 'David';

  final FlutterTts tts = FlutterTts();
  final Battery battery = Battery();
  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  final AudioRecorder _recorder = AudioRecorder();
  final Whisper _whisper = const Whisper(
    model: WhisperModel.base,
  );

  final LlamaController _llama = LlamaController();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(minutes: 10),
    ),
  );

  late SharedPreferences _prefs;

  StreamSubscription<String>? _generationSubscription;

  String? _llamaModelPath;
  String? _whisperModelPath;

  bool _llmReady = false;
  bool _whisperReady = false;
  bool _initialized = false;
  bool _isSpeaking = false;
  bool _isListening = false;

  final Random _random = Random();

  final Map<String, String> familyContacts = {
    'dad': '08056710546',
    'father': '08056710546',
    'daddy': '08056710546',
    'mum': '08055633348',
    'mother': '08055633348',
    'mummy': '08055633348',
    'sister': '+2347086930269',
    'sis': '+2347086930269',
    'brother': '+2349122362006',
    'bro': '+2349122362006',
  };

  static const starting = [
    'We outside Boss.',
    'Say no more.',
    'I got you.',
    'Locked in.',
    'On it Boss.',
  ];

  static const greetings = [
    'Welcome back Boss.',
    'Hey man.',
    'What is up Boss?',
    'Yes Boss, I am here.',
  ];

  static const jokes = [
    'Why did the AI go to therapy? Too many bytes.',
  ];

  final List<String> myGreetings = [
    'hey dave',
    'yo dave',
    'hello',
    'hi',
    'dave',
  ];

  final ValueNotifier<String> status =
      ValueNotifier<String>('Starting DAVE...');

  final ValueNotifier<String> transcript =
      ValueNotifier<String>('');

  final ValueNotifier<String> response =
      ValueNotifier<String>('');

  String pick(List<String> values) {
    return values[_random.nextInt(values.length)];
  }

  bool get catchPhrasesOn {
    return _prefs.getBool('catchPhrases_on') ?? true;
  }

  String withCatchphrase(
    String text, [
    List<String> bank = starting,
  ]) {
    if (!catchPhrasesOn) {
      return text;
    }

    return '${pick(bank)} $text';
  }

  bool get isReady => _llmReady;

  bool get isWhisperReady => _whisperReady;

  Future<void> initBackground() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await initBackground();

    status.value = 'Initializing DAVE...';

    await _initializeNotifications();
    await _initializeTts();

    await _initializeModels();

    _initialized = true;

    await scheduleBriefings();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await notifications.initialize(settings);
  }

  Future<void> _initializeTts() async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.48);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);

    tts.setCompletionHandler(() {
      _isSpeaking = false;
      status.value = 'Ready — Tap to talk Boss';
    });
  }

  Future<Directory> _modelDirectory() async {
    final directory = await getApplicationDocumentsDirectory();

    final modelDirectory =
        Directory('${directory.path}/DAVE/models');

    if (!await modelDirectory.exists()) {
      await modelDirectory.create(recursive: true);
    }

    return modelDirectory;
  }

  Future<Directory> _recordingDirectory() async {
    final directory = await getTemporaryDirectory();

    final recordings =
        Directory('${directory.path}/dave_recordings');

    if (!await recordings.exists()) {
      await recordings.create(recursive: true);
    }

    return recordings;
  }

  Future<String?> _findExistingModel(
    Directory directory,
    String finalName,
  ) async {
    final file = File('${directory.path}/$finalName');

    if (await file.exists()) {
      final length = await file.length();

      if (length > 1024 * 1024) {
        return file.path;
      }
    }

    return null;
  }

  Future<String> _downloadAndCombineModel({
    required String finalName,
    required String baseName,
    required int parts,
    required String extension,
  }) async {
    final directory = await _modelDirectory();

    final existing =
        await _findExistingModel(directory, finalName);

    if (existing != null) {
      return existing;
    }

    final finalFile =
        File('${directory.path}/$finalName');

    final temporaryFile =
        File('${directory.path}/$finalName.downloading');

    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }

    final sink = temporaryFile.openWrite();

    try {
      for (int i = 1; i <= parts; i++) {
        final number = i.toString().padLeft(3, '0');

        final correctName =
            '$baseName-$number.$extension';

        final possibleNames = <String>[
          correctName,
        ];

        // Your GitHub release showed a possible historical typo
        // ".guff" on TinyLlama. We support it as a fallback.
        if (extension == 'gguf') {
          possibleNames.add(
            '$baseName-$number.guff',
          );
        }

        File? downloadedPart;

        for (final remoteName in possibleNames) {
          final localPart =
              File('${directory.path}/$remoteName');

          if (await localPart.exists() &&
              await localPart.length() > 1024 * 1024) {
            downloadedPart = localPart;
            break;
          }

          try {
            status.value =
                'Downloading AI brain $i/$parts...';

            await _dio.download(
              '$githubBase$remoteName',
              localPart.path,
              deleteOnError: true,
              onReceiveProgress: (received, total) {
                if (total > 0) {
                  final percent =
                      (received / total * 100).round();

                  status.value =
                      'Downloading $i/$parts • $percent%';
                }
              },
            );

            if (await localPart.exists() &&
                await localPart.length() > 1024 * 1024) {
              downloadedPart = localPart;
              break;
            }
          } catch (_) {
            if (await localPart.exists()) {
              await localPart.delete();
            }
          }
        }

        if (downloadedPart == null) {
          throw Exception(
            'Could not download model part $i/$parts.',
          );
        }

        await sink.addStream(
          downloadedPart.openRead(),
        );
      }

      await sink.close();

      status.value = 'Finalizing AI brain...';

      if (await finalFile.exists()) {
        await finalFile.delete();
      }

      await temporaryFile.rename(finalFile.path);

      return finalFile.path;
    } catch (_) {
      await sink.close();

      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }

      rethrow;
    }
  }

  Future<void> _initializeModels() async {
    try {
      status.value = 'Preparing DAVE AI...';

      /*
       * TinyLlama:
       *
       * 32 × 20 MB-ish pieces
       * -> one local TinyLlama GGUF
       *
       * Whisper:
       *
       * 7 × 20 MB-ish pieces
       * -> one local Whisper base GGML
       */

      _llamaModelPath =
          await _downloadAndCombineModel(
        finalName: 'tinyllama.gguf',
        baseName: 'tinyllama',
        parts: 32,
        extension: 'gguf',
      );

      status.value = 'Loading DAVE brain...';

      await _llama.loadModel(
        modelPath: _llamaModelPath!,
        threads: 4,
        contextSize: 2048,
      );

      _llmReady = true;

      status.value =
          'Preparing voice recognition...';

      _whisperModelPath =
          await _downloadAndCombineModel(
        finalName: 'ggml-base.bin',
        baseName: 'ggml-base',
        parts: 7,
        extension: 'bin',
      );

      _whisperReady = true;

      status.value =
          'DAVE is online — Tap to talk Boss';

      await speak(
        'Brain online Boss. DAVE is ready.',
      );
    } catch (e, stack) {
      _llmReady = false;
      _whisperReady = false;

      debugPrint('DAVE MODEL ERROR: $e');
      debugPrint('$stack');

      status.value =
          'AI setup failed. Connect to internet and retry.';

      response.value =
          'I could not finish setting up my local brain.';
    }
  }

  Future<void> retryModelSetup() async {
    await _initializeModels();
  }

  Future<void> startListening() async {
    if (_isListening) {
      return;
    }

    if (!_llmReady) {
      status.value =
          'DAVE brain is not ready yet.';
      return;
    }

    if (!_whisperReady) {
      status.value =
          'Voice recognition is not ready yet.';
      return;
    }

    if (_isSpeaking) {
      await tts.stop();
      _isSpeaking = false;
    }

    final permission =
        await _recorder.hasPermission();

    if (!permission) {
      status.value =
          'Microphone permission needed.';
      return;
    }

    _isListening = true;

    try {
      status.value =
          'DAVE is listening...';

      transcript.value = '';
      response.value = '';

      final command =
          await _captureCommand();

      if (command == null ||
          command.trim().isEmpty) {
        await speak(
          'I did not hear a command, Boss.',
        );
        return;
      }

      await chat(command);
    } catch (e) {
      debugPrint('LISTEN ERROR: $e');

      status.value =
          'Voice input failed.';

      await speak(
        'Something went wrong with my ears, Boss.',
      );
    } finally {
      _isListening = false;

      if (!_isSpeaking) {
        status.value =
            'Ready — Tap to talk Boss';
      }
    }
  }

  Future<String?> _captureCommand() async {
    final directory =
        await _recordingDirectory();

    final path =
        '${directory.path}/command_${DateTime.now().millisecondsSinceEpoch}.wav';

    final config = const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
    );

    await _recorder.start(
      config,
      path: path,
    );

    await Future.delayed(
      const Duration(seconds: 4),
    );

    final recordedPath =
        await _recorder.stop();

    if (recordedPath == null) {
      return null;
    }

    final audioFile =
        File(recordedPath);

    if (!await audioFile.exists()) {
      return null;
    }

    final result =
        await _whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: recordedPath,
        language: 'en',
        threads: 4,
        noContext: true,
        suppressNonSpeechTokens: true,
        keepModelLoaded: true,
      ),
      modelPath: _whisperModelPath!,
    );

    try {
      await audioFile.delete();
    } catch (_) {}

    return result.text.trim();
  }

  Future<String> chat(String message) async {
    final cleanMessage =
        message.trim();

    if (cleanMessage.isEmpty) {
      return '';
    }

    recordActivity();

    transcript.value =
        cleanMessage;

    final actionResult =
        await _handleActions(cleanMessage);

    if (actionResult != null) {
      response.value = actionResult;
      return actionResult;
    }

    if (!_llmReady) {
      final fallback =
          getResponse(cleanMessage);

      response.value = fallback;

      await speak(fallback);

      return fallback;
    }

    try {
      status.value =
          'DAVE is thinking...';

      final buffer =
          StringBuffer();

      final prompt = '''
You are DAVE AI, a private personal AI assistant belonging to David.

Your personality:
- Friendly
- Intelligent
- Helpful
- Funny when appropriate
- Encouraging
- Concise
- Natural like a trusted personal assistant

Call the user Boss when it feels natural.

You are running completely locally on the user's Android phone.
Do not claim to have internet access.
Do not invent actions you cannot perform.

User:
$cleanMessage

DAVE:
''';

      await _generationSubscription?.cancel();

      final completer =
          Completer<void>();

      _generationSubscription =
          _llama.generate(
        prompt: prompt,
        maxTokens: 180,
        temperature: 0.7,
        topP: 0.9,
        repeatPenalty: 1.1,
      ).listen(
        (token) {
          buffer.write(token);
          response.value =
              buffer.toString();
        },
        onError: (error, stack) {
          if (!completer.isCompleted) {
            completer.completeError(
              error,
              stack,
            );
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      await completer.future;

      final result =
          buffer.toString().trim();

      if (result.isEmpty) {
        throw Exception(
          'DAVE generated an empty response.',
        );
      }

      _saveConversation(
        cleanMessage,
        result,
      );

      await speak(result);

      status.value =
          'Ready — Tap to talk Boss';

      return result;
    } catch (e) {
      debugPrint(
        'LLAMA GENERATION ERROR: $e',
      );

      final fallback =
          getResponse(cleanMessage);

      response.value = fallback;

      await speak(fallback);

      status.value =
          'Ready — Tap to talk Boss';

      return fallback;
    }
  }

  Future<String?> _handleActions(
    String text,
  ) async {
    final lower =
        text.toLowerCase();

    for (final name
        in familyContacts.keys) {
      if (lower.contains('call $name')) {
        final number =
            familyContacts[name]!;

        await speak(
          'Calling $name now Boss.',
        );

        final uri =
            Uri.parse('tel:$number');

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return 'Calling $name';
        }

        return 'I could not open the phone dialer.';
      }
    }

    if (lower.contains('whatsapp') &&
        lower.contains('message')) {
      try {
        final afterMessage =
            lower.split('message').last;

        String name = afterMessage;

        if (name.contains('on whatsapp')) {
          name =
              name.split('on whatsapp').first;
        }

        if (name.contains('whatsapp')) {
          name =
              name.split('whatsapp').first;
        }

        name = name.trim();

        final number =
            familyContacts[name] ?? '';

        if (number.isEmpty) {
          return 'I do not have $name in my contacts.';
        }

        final message =
            text.contains(':')
                ? text.split(':').sublist(1).join(':').trim()
                : 'Hi';

        final url = Uri.parse(
          'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
        );

        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.externalApplication,
          );

          return 'Opening WhatsApp for $name Boss.';
        }
      } catch (e) {
        debugPrint(
          'WHATSAPP ERROR: $e',
        );
      }
    }

    return null;
  }

  Future<void> speak(
    String text,
  ) async {
    if (text.trim().isEmpty) {
      return;
    }

    _isSpeaking = true;

    status.value =
        'DAVE is speaking...';

    await tts.stop();

    await tts.speak(text);
  }

  void recordActivity() {
    _prefs.setString(
      'last_activity',
      DateTime.now().toIso8601String(),
    );
  }

  void _saveConversation(
    String user,
    String dave,
  ) {
    final history =
        _prefs.getStringList(
              'chat_history',
            ) ??
            <String>[];

    history.add(
      jsonEncode({
        'user': user,
        'dave': dave,
        'time':
            DateTime.now().toIso8601String(),
      }),
    );

    // Keep the local memory from growing forever.
    if (history.length > 100) {
      history.removeRange(
        0,
        history.length - 100,
      );
    }

    _prefs.setStringList(
      'chat_history',
      history,
    );
  }

  String getResponse(
    String rawInput,
  ) {
    final input =
        rawInput.toLowerCase().trim();

    if (myGreetings.any(
      (g) => input.contains(g),
    )) {
      return withCatchphrase(
        pick(greetings),
      );
    }

    if (input.contains('time')) {
      return withCatchphrase(
        "It's ${DateFormat('h:mm a').format(DateTime.now())}, Boss.",
      );
    }

    if (input.contains('battery')) {
      return withCatchphrase(
        'Let me check your battery, Boss.',
      );
    }

    if (input.contains('joke')) {
      return withCatchphrase(
        pick(jokes),
      );
    }

    if (input.contains('remember')) {
      return withCatchphrase(
        'Got it Boss. I saved that locally.',
      );
    }

    return withCatchphrase(
      'I hear you, Master $masterName.',
    );
  }

  Future<String> buildMorningBriefing() async {
    final batt =
        await battery.batteryLevel;

    return 'Good morning Master $masterName. '
        'Battery is at $batt percent. '
        'Let us make today count, Boss.';
  }

  Future<String> buildNightBriefing() async {
    final batt =
        await battery.batteryLevel;

    return 'Good night Master $masterName. '
        'Battery is at $batt percent. '
        'Rest well, Boss.';
  }

  Future<void> scheduleBriefings() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );

      await Workmanager().registerPeriodicTask(
        morningTask,
        morningTask,
        frequency:
            const Duration(hours: 24),
        existingWorkPolicy:
            ExistingPeriodicWorkPolicy.keep,
      );

      await Workmanager().registerPeriodicTask(
        nightTask,
        nightTask,
        frequency:
            const Duration(hours: 24),
        existingWorkPolicy:
            ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint(
        'WORKMANAGER ERROR: $e',
      );
    }
  }

  Future<void> dispose() async {
    await _generationSubscription?.cancel();

    try {
      await _whisper.releaseModel();
    } catch (_) {}

    try {
      await _llama.stop();
    } catch (_) {}

    try {
      await _llama.dispose();
    } catch (_) {}

    await _recorder.dispose();

    await tts.stop();
  }
}
