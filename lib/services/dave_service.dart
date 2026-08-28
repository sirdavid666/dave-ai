import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:android_intent_plus/android_intent.dart';
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
        final enabled =
            dave._prefs.getBool(
                  'morning_briefing_enabled',
                ) ??
                true;

        if (!enabled) {
          return true;
        }

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
        final enabled =
            dave._prefs.getBool(
                  'night_briefing_enabled',
                ) ??
                true;

        if (!enabled) {
          return true;
        }

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

  final Map<String, String> appPackages = {
    'whatsapp': 'com.whatsapp',
    'facebook': 'com.facebook.katana',
    'instagram': 'com.instagram.android',
    'tiktok': 'com.zhiliaoapp.musically',
    'tiktok lite': 'com.zhiliaoapp.musically.go',
    'snapchat': 'com.snapchat.android',
    'twitter': 'com.twitter.android',
    'x': 'com.twitter.android',
    'telegram': 'org.telegram.messenger',
    'pinterest': 'com.pinterest',
    'spotify': 'com.spotify.music',
    'youtube': 'com.google.android.youtube',
    'yt music': 'com.google.android.apps.youtube.music',
    'gmail': 'com.google.android.gm',
    'chrome': 'com.android.chrome',
    'firefox': 'org.mozilla.firefox',
    'uc browser': 'com.UCMobile.intl',
    'google': 'com.google.android.googlequicksearchbox',
    'drive': 'com.google.android.apps.docs',
    'maps': 'com.google.android.apps.maps',
    'meet': 'com.google.android.apps.meetings',
    'settings': 'com.android.settings',
    'camera': 'com.android.camera',
    'gallery': 'com.android.gallery3d',
    'phone': 'com.android.dialer',
    'contacts': 'com.android.contacts',
    'jumia': 'com.jumia.android',
    'mx player': 'com.mxtech.videoplayer.ad',
    'blood strike': 'com.netease.hyperfront',
    'daveflow': 'com.dave.daveflow',
    'chatgpt': 'com.openai.chatgpt',
    'claude': 'com.anthropic.claude',
    'bing': 'com.microsoft.bing',
    'xender': 'cn.xender',
    'zarchiver': 'ru.zdevs.zarchiver',
    'audiomack': 'com.audiomack',
    'wps office': 'cn.wps.moffice_eng',
  };

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

  String _toWhatsAppFormat(
    String rawNumber,
  ) {
    var digits =
        rawNumber.replaceAll(
      RegExp(r'[^\d+]'),
      '',
    );

    if (digits.startsWith('+')) {
      digits = digits.substring(1);
    } else if (digits.startsWith('0')) {
      digits =
          '234${digits.substring(1)}';
    }

    return digits;
  }

  Future<String?> resolveContactNumber(
    String spokenName,
  ) async {
    final name =
        spokenName.trim().toLowerCase();

    if (name.isEmpty) {
      return null;
    }

    if (familyContacts.containsKey(name)) {
      return familyContacts[name];
    }

    try {
      final hasPermission =
          await FlutterContacts
              .requestPermission(
        readonly: true,
      );

      if (!hasPermission) {
        return null;
      }

      final contacts =
          await FlutterContacts.getContacts(
        withProperties: true,
      );

      for (final contact in contacts) {
        final displayName =
            contact.displayName
                .toLowerCase();

        if (displayName == name ||
            displayName.contains(name)) {
          if (contact.phones.isNotEmpty) {
            return contact
                .phones.first.number;
          }
        }
      }
    } catch (e, stack) {
      debugPrint('CONTACT LOOKUP ERROR: $e');
      debugPrint('$stack');
    }

    return null;
  }

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

  final ValueNotifier<String?> lastOnlineError =
      ValueNotifier<String?>(null);

  final ValueNotifier<String?> lastBriefingError =
      ValueNotifier<String?>(null);

  final ValueNotifier<String?> lastAlarmError =
      ValueNotifier<String?>(null);

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

  /*
   * Get your free API key from https://aistudio.google.com
   * (sign in with any Google account, no card needed).
   * Paste it below, between the quotes.
   */
  static const String _geminiApiKey =
      String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'PASTE_YOUR_GEMINI_API_KEY_HERE',
  );

  Future<String?> _tryOnlineChat(
    String cleanMessage,
  ) async {
    if (_geminiApiKey ==
        'PASTE_YOUR_GEMINI_API_KEY_HERE') {
      return null;
    }

    try {
      final fullHistory =
          getConversationHistory();

      final recentHistory =
          fullHistory.length > 6
              ? fullHistory.sublist(
                  fullHistory.length - 6,
                )
              : fullHistory;

      final contents = <Map<String, dynamic>>[];

      for (final entry in recentHistory) {
        final u =
            (entry['user'] ?? '')
                .toString();

        final d =
            (entry['dave'] ?? '')
                .toString();

        if (u.isNotEmpty) {
          contents.add({
            'role': 'user',
            'parts': [
              {'text': u},
            ],
          });
        }

        if (d.isNotEmpty) {
          contents.add({
            'role': 'model',
            'parts': [
              {'text': d},
            ],
          });
        }
      }

      contents.add({
        'role': 'user',
        'parts': [
          {'text': cleanMessage},
        ],
      });

      final response = await _dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent',
        data: {
          'system_instruction': {
            'parts': [
              {
                'text':
                    'You are DAVE AI, a private personal assistant belonging to David, a Nigerian student preparing to study Biomedical Engineering at FUNATO. Personality: friendly, intelligent, helpful, funny when appropriate, concise. Call David "Boss" naturally. Reply only as DAVE.',
              },
            ],
          },
          'contents': contents,
        },
        options: Options(
          headers: {
            'x-goog-api-key': _geminiApiKey,
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(
            seconds: 10,
          ),
          receiveTimeout: const Duration(
            seconds: 15,
          ),
        ),
      );

      final text = response
          .data['candidates'][0]['content']['parts'][0]
              ['text']
          .toString()
          .trim();

      if (text.isEmpty) {
        lastOnlineError.value =
            'Gemini returned an empty response.';

        return null;
      }

      lastOnlineError.value = null;

      return text;
    } catch (e, stack) {
      lastOnlineError.value =
          e.toString();
      debugPrint('ONLINE CHAT ERROR: $e');
      debugPrint('$stack');

      return null;
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

    final onlineReply =
        await _tryOnlineChat(cleanMessage);

    if (onlineReply != null) {
      response.value =
          onlineReply;

      _saveConversation(
        cleanMessage,
        onlineReply,
      );

      await speak(onlineReply);

      return onlineReply;
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
          fullHistory.length > 2
              ? fullHistory.sublist(
                  fullHistory.length - 2,
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

      final wordCount =
          result
              .split(
                RegExp(r'\s+'),
              )
              .length;

      final looksBroken =
          wordCount < 4 ||
              !result.contains(' ');

      if (!looksBroken) {
        _saveConversation(
          cleanMessage,
          result,
        );
      }

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

  Future<bool> _setRealAlarm(
    int hour,
    int minute,
    String label,
  ) async {
    try {
      final intent = AndroidIntent(
        action:
            'android.intent.action.SET_ALARM',
        arguments: {
          'android.intent.extra.alarm.HOUR':
              hour,
          'android.intent.extra.alarm.MINUTES':
              minute,
          'android.intent.extra.alarm.MESSAGE':
              label,
          'android.intent.extra.alarm.SKIP_UI':
              true,
        },
      );

      await intent.launch();

      lastAlarmError.value = null;

      return true;
    } catch (e, stack) {
      lastAlarmError.value = e.toString();

      debugPrint('ALARM ERROR: $e');
      debugPrint('$stack');

      return false;
    }
  }

  Future<String?> _handleActions(
    String text,
  ) async {
    final lower =
        text.toLowerCase();

    final openMatch = RegExp(
      r'open (.+)',
    ).firstMatch(lower);

    final isWhatsAppMessageIntent =
        lower.contains('whatsapp') &&
            (lower.contains('message') ||
                lower.contains('text'));

    if (openMatch != null &&
        !isWhatsAppMessageIntent) {
      final spokenApp =
          openMatch.group(1)!.trim();

      final packageName =
          appPackages[spokenApp];

      if (packageName != null) {
        try {
          final intent = AndroidIntent(
            action:
                'android.intent.action.MAIN',
            package: packageName,
          );

          await intent.launch();

          return 'Opening $spokenApp Boss.';
        } catch (e, stack) {
          debugPrint('OPEN APP ERROR: $e');
          debugPrint('$stack');

          return 'I could not open $spokenApp, Boss. It may not be installed.';
        }
      }

      return 'I do not know how to open $spokenApp yet, Boss.';
    }

    final alarmMatch = RegExp(
      r'set (?:an? )?alarm (?:for|at)?\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
    ).firstMatch(lower);

    if (alarmMatch != null) {
      var hour =
          int.tryParse(
            alarmMatch.group(1)!,
          ) ??
              0;

      final minute =
          int.tryParse(
            alarmMatch.group(2) ?? '0',
          ) ??
              0;

      final meridiem =
          alarmMatch.group(3);

      if (meridiem == 'pm' &&
          hour < 12) {
        hour += 12;
      }

      if (meridiem == 'am' &&
          hour == 12) {
        hour = 0;
      }

      if (hour <= 23 && minute <= 59) {
        final displayHour =
            hour.toString().padLeft(
              2,
              '0',
            );

        final displayMinute =
            minute.toString().padLeft(
              2,
              '0',
            );

        final success =
            await _setRealAlarm(
          hour,
          minute,
          'DAVE Alarm',
        );

        if (success) {
          return 'Alarm set for $displayHour:$displayMinute Boss.';
        }

        return 'I could not set the alarm, Boss.';
      }
    }

    final reminderMatch = RegExp(
      r'(?:remind me to|set (?:a |an )?reminder to) (.+?) in (\d+)\s*(minute|minutes|min|mins|hour|hours|hr|hrs)',
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

      final rawDuration = isHours
          ? Duration(hours: amount)
          : Duration(minutes: amount);

      final duration =
          rawDuration < const Duration(
                minutes: 2,
              )
              ? const Duration(
                  minutes: 2,
                )
              : rawDuration;

      final target =
          DateTime.now().add(duration);

      await _setRealAlarm(
        target.hour,
        target.minute,
        task,
      );

      return await addTask(
        task,
        remindIn: duration,
      );
    }

    final tasklessReminderMatch = RegExp(
      r'(?:remind me|set (?:a |an )?reminder)(?: in| after)?(?: the next)? (\d+)\s*(minute|minutes|min|mins|hour|hours|hr|hrs)',
    ).firstMatch(lower);

    if (tasklessReminderMatch != null) {
      final amount =
          int.tryParse(
            tasklessReminderMatch.group(1)!,
          ) ??
              0;

      final unit =
          tasklessReminderMatch.group(2)!;

      final isHours =
          unit.startsWith('hour') ||
              unit.startsWith('hr');

      final rawDuration = isHours
          ? Duration(hours: amount)
          : Duration(minutes: amount);

      final duration =
          rawDuration < const Duration(
                minutes: 2,
              )
              ? const Duration(
                  minutes: 2,
                )
              : rawDuration;

      const task = 'your reminder';

      final target =
          DateTime.now().add(duration);

      await _setRealAlarm(
        target.hour,
        target.minute,
        task,
      );

      return await addTask(
        task,
        remindIn: duration,
      );
    }

    final clockMatch = RegExp(
      r'remind me to (.+?) at (\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
    ).firstMatch(lower);

    if (clockMatch != null) {
      final task =
          clockMatch.group(1)!.trim();

      var hour =
          int.tryParse(
            clockMatch.group(2)!,
          ) ??
              0;

      final minute =
          int.tryParse(
            clockMatch.group(3) ?? '0',
          ) ??
              0;

      final meridiem =
          clockMatch.group(4);

      if (meridiem == 'pm' &&
          hour < 12) {
        hour += 12;
      }

      if (meridiem == 'am' &&
          hour == 12) {
        hour = 0;
      }

      if (hour <= 23 &&
          minute <= 59) {
        final target =
            _durationUntil(hour, minute);

        await _setRealAlarm(
          hour,
          minute,
          task,
        );

        return await addTask(
          task,
          remindIn: target,
        );
      }
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

    final callMatch = RegExp(
      r'call (?:my )?(.+)',
    ).firstMatch(lower);

    if (callMatch != null &&
        !lower.contains('called') &&
        !lower.contains('calling')) {
      final spokenName =
          callMatch.group(1)!.trim();

      final number =
          await resolveContactNumber(
        spokenName,
      );

      if (number == null) {
        return 'I could not find $spokenName in your contacts, Boss.';
      }

      final uri =
          Uri.parse('tel:$number');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);

        return 'Calling $spokenName Boss.';
      }

      return 'I could not open the phone dialer.';
    }

    if (isWhatsAppMessageIntent) {
      try {
        final afterTrigger = RegExp(
          r'(?:message|text)\s+(.+)',
        ).firstMatch(lower);

        if (afterTrigger == null) {
          return 'I could not understand who to message, Boss.';
        }

        var remainder =
            afterTrigger.group(1)!.trim();

        String name;
        String message;

        if (remainder.contains('on whatsapp')) {
          final parts =
              remainder.split('on whatsapp');

          name = parts.first.trim();

          final tellPattern = RegExp(
            r'(?:tell (?:him|her|them)|saying|say)\s+(.+)',
          ).firstMatch(text);

          message = tellPattern != null
              ? tellPattern.group(1)!.trim()
              : (parts.length > 1
                  ? parts
                      .sublist(1)
                      .join('on whatsapp')
                      .trim()
                  : 'Hi');
        } else {
          remainder =
              remainder
                  .replaceAll('whatsapp', '')
                  .trim();

          final words =
              remainder.split(' ');

          name = words.isNotEmpty
              ? words.first
              : '';

          message = words.length > 1
              ? words.sublist(1).join(' ')
              : 'Hi';
        }

        final number =
            await resolveContactNumber(
          name,
        ) ??
                '';

        if (number.isEmpty) {
          return 'I could not find $name in your contacts, Boss.';
        }

        final url =
            Uri.parse(
          'https://wa.me/${_toWhatsAppFormat(number)}?text=${Uri.encodeComponent(message)}',
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
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation
                  .absoluteTime,
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

  bool get morningBriefingEnabled =>
      _prefs.getBool(
        'morning_briefing_enabled',
      ) ??
      true;

  bool get nightBriefingEnabled =>
      _prefs.getBool(
        'night_briefing_enabled',
      ) ??
      true;

  Future<void> setMorningBriefingEnabled(
    bool value,
  ) async {
    await _prefs.setBool(
      'morning_briefing_enabled',
      value,
    );
  }

  Future<void> setNightBriefingEnabled(
    bool value,
  ) async {
    await _prefs.setBool(
      'night_briefing_enabled',
      value,
    );
  }

  Future<bool> testAlarmNow() async {
    final target =
        DateTime.now().add(
      const Duration(minutes: 2),
    );

    return _setRealAlarm(
      target.hour,
      target.minute,
      'DAVE Test Alarm',
    );
  }

  Future<bool> testBriefingNow({
    required bool morning,
  }) async {
    try {
      final text = morning
          ? await buildMorningBriefing()
          : await buildNightBriefing();

      await notifications.show(
        morning ? 1 : 2,
        morning
            ? 'DAVE AI Morning'
            : 'DAVE AI Night',
        text,
        NotificationDetails(
          android: AndroidNotificationDetails(
            morning
                ? 'morning_channel'
                : 'night_channel',
            morning
                ? 'Morning Briefing'
                : 'Night Briefing',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );

      await speak(text);

      lastBriefingError.value = null;

      return true;
    } catch (e, stack) {
      lastBriefingError.value = e.toString();

      debugPrint('TEST BRIEFING ERROR: $e');
      debugPrint('$stack');

      return false;
    }
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
      final alreadyScheduled =
          _prefs.getBool(
                'briefings_scheduled_v1',
              ) ??
              false;

      if (alreadyScheduled) {
        debugPrint(
          'WORKMANAGER: Briefings already scheduled, skipping re-registration.',
        );
        return;
      }

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

      await _prefs.setBool(
        'briefings_scheduled_v1',
        true,
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
