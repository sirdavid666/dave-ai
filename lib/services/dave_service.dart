import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:workmanager/workmanager.dart';

const String githubBase =
    'https://github.com/sirdavid666/dave-ai/releases/download/v0.1.0/';

const String morningTask = 'morningBriefing';
const String nightTask = 'nightBriefing';

Future<void> _speakBlocking(
  FlutterTts tts,
  String text,
) async {
  if (text.trim().isEmpty) {
    return;
  }

  final completer = Completer<void>();

  tts.setCompletionHandler(() {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });

  tts.setErrorHandler((msg) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });

  await tts.stop();
  await tts.speak(text);

  await completer.future.timeout(
    const Duration(seconds: 60),
    onTimeout: () {},
  );
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      final dave = DaveService.instance;

      await dave.initBackground();
      await dave.initializeBackgroundNotifications();

      if (task == morningTask) {
        final text = await dave.buildMorningBriefing();

        await dave.notifications.show(
          1,
          'DAVE AI Morning',
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

        await _speakBlocking(dave.tts, text);
      }

      if (task == nightTask) {
        final text = await dave.buildNightBriefing();

        await dave.notifications.show(
          2,
          'DAVE AI Night',
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

        await _speakBlocking(dave.tts, text);
      }

      return true;
    } catch (e, stack) {
      debugPrint('WORKMANAGER CALLBACK ERROR: $e');
      debugPrint('$stack');
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

  final WhisperController _whisper = WhisperController();

  final LlamaController _llama = LlamaController();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 15),
      sendTimeout: const Duration(minutes: 15),
    ),
  );

  late SharedPreferences _prefs;

  StreamSubscription<String>? _generationSubscription;

  String? _llamaModelPath;

  bool _llmReady = false;
  bool _whisperReady = false;
  bool _initialized = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _downloading = false;

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

  static const List<String> starting = [
    'We outside Boss.',
    'Say no more.',
    'I got you.',
    'Locked in.',
    'On it Boss.',
  ];

  static const List<String> greetings = [
    'Welcome back Boss.',
    'Hey Boss.',
    'What is up Boss?',
    'Yes Boss, I am here.',
  ];

  static const List<String> jokes = [
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

  final ValueNotifier<List<Map<String, dynamic>>> tasks =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  bool get isReady => _llmReady;

  bool get isWhisperReady => _whisperReady;

  bool get isDownloading => _downloading;

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

  Future<void> initBackground() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> initializeBackgroundNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await notifications.initialize(settings);

    tz_data.initializeTimeZones();

    await _loadTasks();
  }

  Future<void> init() async {
  if (_initialized) {
    return;
  }

  try {
    await initBackground();
  } catch (e) {
    debugPrint('PREFS ERROR: $e');
  }

  status.value = 'Initializing DAVE...';

  try {
    await _initializeNotifications();
  } catch (e, s) {
    debugPrint('NOTIFICATION ERROR: $e');
    debugPrint('$s');
  }

  try {
    await _initializeTts();
  } catch (e, s) {
    debugPrint('TTS ERROR: $e');
    debugPrint('$s');
  }

  try {
    await _initializeModels();
  } catch (e, s) {
    debugPrint('MODEL ERROR: $e');
    debugPrint('$s');
  }

  try {
    await scheduleBriefings();
  } catch (e, s) {
    debugPrint('WORKMANAGER ERROR: $e');
    debugPrint('$s');
  }

  _initialized = true;

  status.value =
      'DAVE opened successfully.';
  }

  Future<void> _initializeNotifications() async {
    await initializeBackgroundNotifications();

    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _initializeTts() async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.48);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);

    tts.setCompletionHandler(() {
      _isSpeaking = false;

      if (!_isListening) {
        status.value = 'Ready — Tap to talk Boss';
      }
    });

    tts.setErrorHandler((message) {
      _isSpeaking = false;
      debugPrint('TTS ERROR: $message');
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

    if (!await file.exists()) {
      return null;
    }

    final length = await file.length();

    if (length < 1024 * 1024) {
      return null;
    }

    return file.path;
  }

  Future<String> _downloadSingleModel({
    required String finalName,
    required String url,
  }) async {
    final directory = await _modelDirectory();

    final existing = await _findExistingModel(
      directory,
      finalName,
    );

    if (existing != null) {
      return existing;
    }

    _downloading = true;

    final finalFile =
        File('${directory.path}/$finalName');

    final temporaryFile =
        File('${directory.path}/$finalName.part');

    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }

    try {
      status.value = 'Downloading DAVE brain...';

      await _dio.download(
        url,
        temporaryFile.path,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final percent =
                (received / total * 100).round();

            status.value =
                'Downloading DAVE brain • $percent%';
          }
        },
      );

      final length = await temporaryFile.length();

      if (length < 10 * 1024 * 1024) {
        await temporaryFile.delete();

        throw Exception(
          'Downloaded model is unexpectedly small.',
        );
      }

      if (await finalFile.exists()) {
        await finalFile.delete();
      }

      await temporaryFile.rename(finalFile.path);

      return finalFile.path;
    } finally {
      _downloading = false;

      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  Future<String> _downloadAndCombineModel({
    required String finalName,
    required String baseName,
    required int parts,
    required String extension,
  }) async {
    final directory = await _modelDirectory();

    final existing = await _findExistingModel(
      directory,
      finalName,
    );

    if (existing != null) {
      return existing;
    }

    _downloading = true;

    final finalFile =
        File('${directory.path}/$finalName');

    final temporaryFile =
        File('${directory.path}/$finalName.part');

    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }

    try {
      final sink = temporaryFile.openWrite();

      try {
        for (int i = 1; i <= parts; i++) {
          final number = i.toString().padLeft(3, '0');

          final names = <String>[
            '$baseName-$number.$extension',
          ];

          if (extension == 'gguf') {
            names.add('$baseName-$number.guff');
          }

          File? partFile;

          for (final remoteName in names) {
            final localFile =
                File('${directory.path}/$remoteName');

            if (await localFile.exists()) {
              final existingLength =
                  await localFile.length();

              if (existingLength > 1024 * 1024) {
                partFile = localFile;
                break;
              }
            }

            status.value =
                'Downloading AI model $i/$parts...';

            try {
              await _dio.download(
                '$githubBase$remoteName',
                localFile.path,
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

              if (await localFile.exists()) {
                final length =
                    await localFile.length();

                if (length > 1024 * 1024) {
                  partFile = localFile;
                  break;
                }
              }
            } catch (e) {
              debugPrint(
                'MODEL PART ERROR $remoteName: $e',
              );

              if (await localFile.exists()) {
                await localFile.delete();
              }
            }
          }

          if (partFile == null) {
            throw Exception(
              'Could not download model part $i/$parts.',
            );
          }

          status.value =
              'Preparing model $i/$parts...';

          await sink.addStream(
            partFile.openRead(),
          );

          try {
            await partFile.delete();
          } catch (_) {}
        }

        await sink.close();
      } catch (_) {
        await sink.close();
        rethrow;
      }

      status.value =
          'Finalizing $finalName...';

      if (await finalFile.exists()) {
        await finalFile.delete();
      }

      await temporaryFile.rename(
        finalFile.path,
      );

      final finalSize =
          await finalFile.length();

      if (finalSize < 10 * 1024 * 1024) {
        await finalFile.delete();

        throw Exception(
          'Combined model is unexpectedly small.',
        );
      }

      return finalFile.path;
    } finally {
      _downloading = false;

      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  Future<void> _initializeModels() async {
    try {
      status.value =
          'Preparing DAVE AI brain...';

      _llamaModelPath =
          await _downloadSingleModel(
        finalName: 'qwen2.5-0.5b-instruct-q2_k.gguf',
        url:
            'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q2_k.gguf?download=true',
      );

      status.value =
          'Loading DAVE brain...';

      await _llama.loadModel(
        modelPath: _llamaModelPath!,
        threads: 2,
        contextSize: 512,
      );

      _llmReady = true;

      status.value =
          'Preparing DAVE ears...';

      final whisperPath =
          await _whisper.getPath(WhisperModel.base);

      final whisperFile = File(whisperPath);

      final needsDownload = !await whisperFile.exists() ||
          await whisperFile.length() < 10 * 1024 * 1024;

      if (needsDownload) {
        status.value =
            'Downloading DAVE ears...';

        await _whisper.downloadModel(WhisperModel.base);
      }

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
          'AI setup failed: $e';

      response.value =
          'I could not finish setting up my local brain. '
          'Please retry the model setup.';
    }
  }

  Future<void> retryModelSetup() async {
    if (_downloading) {
      return;
    }

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
          'DAVE voice recognition is not ready yet.';
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
    } catch (e, stack) {
      debugPrint('LISTEN ERROR: $e');
      debugPrint('$stack');

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

    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
    );

    await _recorder.start(
      config,
      path: path,
    );

    status.value =
        'Listening for 6 seconds...';

    await Future.delayed(
      const Duration(seconds: 6),
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

    try {
      final result =
          await _whisper.transcribe(
        model: WhisperModel.base,
        audioPath: recordedPath,
        lang: 'en',
        noContext: true,
        suppressNonSpeechTokens: true,
        keepModelLoaded: true,
      );

      return result?.transcription.text.trim();
    } finally {
      try {
        await audioFile.delete();
      } catch (_) {}
    }
  }

  Future<String> chat(
    String message,
  ) async {
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
      response.value =
          actionResult;

      await speak(actionResult);

      return actionResult;
    }

    if (!_llmReady) {
      final fallback =
          getResponse(cleanMessage);

      response.value =
          fallback;

      await speak(fallback);

      return fallback;
    }

    try {
      status.value =
          'DAVE is thinking...';

      final buffer =
          StringBuffer();

      final fullHistory =
          getConversationHistory();

      final recentHistory =
          fullHistory.length > 3
              ? fullHistory.sublist(
                  fullHistory.length - 3,
                )
              : fullHistory;

      final historyBlock =
          recentHistory.map((entry) {
        final u =
            (entry['user'] ?? '')
                .toString();

        final d =
            (entry['dave'] ?? '')
                .toString();

        return '<|im_start|>user\n$u<|im_end|>\n<|im_start|>assistant\n$d<|im_end|>';
      }).join('\n');

      final pendingTasks =
          tasks.value
              .where(
                (t) => t['done'] != true,
              )
              .map(
                (t) => t['text'],
              )
              .take(6)
              .join('; ');

      final prompt = '''
<|im_start|>system
You are DAVE AI, a private personal assistant belonging to David.
Personality: friendly, intelligent, helpful, funny when appropriate, concise.
Call David "Boss" naturally when appropriate.
You run locally on his Android phone and do not have internet access during normal conversation.
Do not claim to have performed an action unless the app actually performed it.
Do not invent information.
Reply only as DAVE. Never write David's next message.
${pendingTasks.isNotEmpty ? "Boss's current pending tasks: $pendingTasks" : ''}
<|im_end|>
$historyBlock
<|im_start|>user
$cleanMessage<|im_end|>
<|im_start|>assistant
''';

      const stopMarkers = [
        '<|im_end|>',
        '<|im_start|>',
        '\nBoss:',
        '\nUser:',
        '\nDAVE:',
      ];

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

          final current =
              buffer.toString();

          for (final marker in stopMarkers) {
            final index =
                current.indexOf(marker);

            if (index != -1) {
              final trimmed =
                  current.substring(0, index);

              response.value =
                  trimmed;

              if (!completer.isCompleted) {
                completer.complete();
              }

              _generationSubscription?.cancel();

              return;
            }
          }

          response.value =
              current;
        },
        onError: (
          Object error,
          StackTrace stack,
        ) {
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

      var result =
          response.value.trim();

      if (result.isEmpty) {
        result =
            buffer.toString().trim();
      }

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
    } catch (e, stack) {
      debugPrint(
        'LLAMA GENERATION ERROR: $e',
      );
      debugPrint('$stack');

      final fallback =
          getResponse(cleanMessage);

      response.value =
          fallback;

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

    final reminderMatch = RegExp(
      r'remind me to (.+?) in (\d+)\s*(minute|minutes|min|mins|hour|hours|hr|hrs)',
    ).firstMatch(lower);

    if (reminderMatch != null) {
      final task =
          reminderMatch.group(1)!.trim();

      final amount =
          int.tryParse(
            reminderMatch.group(2)!,
          ) ??
              0;

      final unit =
          reminderMatch.group(3)!;

      final isHours =
          unit.startsWith('hour') ||
              unit.startsWith('hr');

      final duration = isHours
          ? Duration(hours: amount)
          : Duration(minutes: amount);

      return await addTask(
        task,
        remindIn: duration,
      );
    }

    if (lower.startsWith('remind me to ')) {
      final task =
          lower
              .replaceFirst('remind me to ', '')
              .trim();

      return await addTask(task);
    }

    if (lower.startsWith('add task ') ||
        lower.startsWith('add a task ')) {
      final task =
          lower
              .replaceFirst(
                RegExp(r'add a? task'),
                '',
              )
              .trim();

      return await addTask(task);
    }

    if (RegExp(r'add (.+) to my tasks?')
        .hasMatch(lower)) {
      final match = RegExp(
        r'add (.+) to my tasks?',
      ).firstMatch(lower)!;

      final task =
          match.group(1)!.trim();

      return await addTask(task);
    }

    for (final name
        in familyContacts.keys) {
      final matchesCall =
          lower.contains('call $name') ||
              lower.contains('call my $name');

      if (matchesCall) {
        final number =
            familyContacts[name]!;

        final uri =
            Uri.parse('tel:$number');

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);

          return 'Calling $name Boss.';
        }

        return 'I could not open the phone dialer.';
      }
    }

    if (lower.contains('whatsapp') &&
        lower.contains('message')) {
      try {
        String name =
            lower
                .split('message')
                .last;

        if (name.contains('on whatsapp')) {
          name =
              name
                  .split('on whatsapp')
                  .first;
        }

        name =
            name
                .replaceAll(
                  'whatsapp',
                  '',
                )
                .trim();

        final number =
            familyContacts[name] ?? '';

        if (number.isEmpty) {
          return 'I do not have $name in my saved contacts.';
        }

        final message =
            text.contains(':')
                ? text
                    .split(':')
                    .sublist(1)
                    .join(':')
                    .trim()
                : 'Hi';

        final url =
            Uri.parse(
          'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
        );

        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode:
                LaunchMode.externalApplication,
          );

          return 'Opening WhatsApp for $name Boss.';
        }

        return 'I could not open WhatsApp.';
      } catch (e) {
        debugPrint(
          'WHATSAPP ERROR: $e',
        );

        return 'WhatsApp action failed.';
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
      DateTime.now()
          .toIso8601String(),
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
            DateTime.now()
                .toIso8601String(),
      }),
    );

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

  List<Map<String, dynamic>>
      getConversationHistory() {
    final history =
        _prefs.getStringList(
              'chat_history',
            ) ??
            <String>[];

    final result =
        <Map<String, dynamic>>[];

    for (final item in history) {
      try {
        final decoded =
            jsonDecode(item);

        if (decoded
            is Map<String, dynamic>) {
          result.add(decoded);
        }
      } catch (_) {}
    }

    return result;
  }

  Future<void> _loadTasks() async {
    final stored =
        _prefs.getStringList('tasks') ??
            <String>[];

    final loaded =
        <Map<String, dynamic>>[];

    for (final item in stored) {
      try {
        final decoded =
            jsonDecode(item);

        if (decoded
            is Map<String, dynamic>) {
          loaded.add(decoded);
        }
      } catch (_) {}
    }

    tasks.value = loaded;
  }

  Future<void> _saveTasks() async {
    final encoded =
        tasks.value
            .map((task) => jsonEncode(task))
            .toList();

    await _prefs.setStringList(
      'tasks',
      encoded,
    );
  }

  Future<String> addTask(
    String text, {
    Duration? remindIn,
  }) async {
    final cleanText =
        text.trim();

    if (cleanText.isEmpty) {
      return 'I need something to add, Boss.';
    }

    final id =
        DateTime.now()
            .millisecondsSinceEpoch;

    DateTime? remindAt;

    if (remindIn != null) {
      remindAt =
          DateTime.now().add(remindIn);
    }

    final task = <String, dynamic>{
      'id': id,
      'text': cleanText,
      'done': false,
      'remindAt':
          remindAt?.toIso8601String(),
    };

    tasks.value = [
      ...tasks.value,
      task,
    ];

    await _saveTasks();

    if (remindAt != null) {
      try {
        await notifications.zonedSchedule(
          id.remainder(2147483647),
          'DAVE Reminder',
          cleanText,
          tz.TZDateTime.from(
            remindAt,
            tz.UTC,
          ),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'reminder_channel',
              'Reminders',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode:
              AndroidScheduleMode
                  .inexactAllowWhileIdle,
        );
      } catch (e, stack) {
        debugPrint('REMINDER SCHEDULE ERROR: $e');
        debugPrint('$stack');
      }

      return 'Got it Boss. I will remind you to $cleanText.';
    }

    return 'Added to your tasks, Boss: $cleanText.';
  }

  Future<void> completeTask(int id) async {
    tasks.value = tasks.value.map((task) {
      if (task['id'] == id) {
        return {
          ...task,
          'done': true,
        };
      }

      return task;
    }).toList();

    await _saveTasks();
  }

  Future<void> deleteTask(int id) async {
    tasks.value = tasks.value
        .where((task) => task['id'] != id)
        .toList();

    await _saveTasks();

    try {
      await notifications.cancel(
        id.remainder(2147483647),
      );
    } catch (_) {}
  }

  String getResponse(
    String rawInput,
  ) {
    final input =
        rawInput
            .toLowerCase()
            .trim();

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

  Duration _durationUntil(
    int hour,
    int minute,
  ) {
    final now = DateTime.now();

    var target = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (target.isBefore(now)) {
      target =
          target.add(const Duration(days: 1));
    }

    return target.difference(now);
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
        initialDelay:
            _durationUntil(7, 0),
      );

      await Workmanager().registerPeriodicTask(
        nightTask,
        nightTask,
        frequency:
            const Duration(hours: 24),
        initialDelay:
            _durationUntil(21, 0),
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
