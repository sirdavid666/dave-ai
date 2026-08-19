import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart'; // NEW
import 'dart:io'; // NEW

import 'dave_service.dart';
import 'splash_screen.dart';

const String morningTask = "morningBriefingTask";
const String nightTask = "nightBriefingTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Hive.initFlutter();
    final DaveService dave = DaveService.instance;
    await dave.init();
    if (task == morningTask) {
      String briefing = await dave.buildMorningBriefing();
      await dave.speak(briefing);
      await dave.notifications.show(1, "DAVE AI Morning", briefing, const NotificationDetails(android: AndroidNotificationDetails('morning_channel', 'Morning Briefing', importance: Importance.max)));
    }
    if (task == nightTask) {
      String briefing = await dave.buildNightBriefing();
      await dave.speak(briefing);
      await dave.notifications.show(2, "DAVE AI Night", briefing, const NotificationDetails(android: AndroidNotificationDetails('night_channel', 'Night Briefing', importance: Importance.max)));
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DaveService.instance.init();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await _scheduleDailyBriefings();
  try { await [Permission.microphone, Permission.notification].request(); } catch (_) {}
  runApp(const DaveAIApp());
}

Future<void> _scheduleDailyBriefings() async {
  await Workmanager().registerPeriodicTask("1", morningTask, frequency: const Duration(hours: 24), initialDelay: _getInitialDelay(7, 0), constraints: Constraints(networkType: NetworkType.not_required, requiresBatteryNotLow: false, requiresCharging: false));
  await Workmanager().registerPeriodicTask("2", nightTask, frequency: const Duration(hours: 24), initialDelay: _getInitialDelay(22, 0), constraints: Constraints(networkType: NetworkType.not_required, requiresBatteryNotLow: false, requiresCharging: false));
}

Duration _getInitialDelay(int hour, int minute) {
  final now = DateTime.now();
  var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
  if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
  return scheduled.difference(now);
}

class DaveAIApp extends StatelessWidget {
  const DaveAIApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'DAVE AI', debugShowCheckedModeBanner: false, theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFF0A0A0F)), home: const DaveHomePage());
  }
}

class DaveHomePage extends StatefulWidget {
  const DaveHomePage({super.key});
  @override
  State<DaveHomePage> createState() => _DaveHomePageState();
}

class _DaveHomePageState extends State<DaveHomePage> {
  late final WebViewController _controller; // NEW
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFlutterAsset('assets/index.html'); // LOADS YOUR BRAIN
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _controller), // YOUR INDEX.HTML RUNS HERE
          // UPGRADE 3: PULSING MIC BUTTON ON TOP
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  _controller.runJavaScript('rec.start()'); // Tells index.html to listen
                  setState(() => _isListening = true);
                  Future.delayed(const Duration(seconds: 5), () => setState(() => _isListening = false));
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _isListening? Colors.red : const Color(0xFF00ff88)),
                  child: const Icon(Icons.mic, size: 40, color: Colors.black),
                ).animate(target: _isListening? 1 : 0).scale(duration: 600.ms).then().scale(duration: 600.ms), // PULSE
              ),
            ),
          )
        ],
      ),
    );
  }
}
