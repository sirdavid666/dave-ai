import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'dave_service.dart';

const String morningTask = "morningBriefing";
const String nightTask = "nightBriefing";
const String MASTER_NAME = "DAVID";

final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Hive.initFlutter();
    await DaveService.instance.init();
    if (task == morningTask) {
      String briefing = await DaveService.instance.buildMorningBriefing();
      await DaveService.instance.speak(briefing);
      await notifications.show(1, "🌅 Good Morning Master $MASTER_NAME", briefing, const NotificationDetails(android: AndroidNotificationDetails('morning_channel', 'Morning Briefing', importance: Importance.max, playSound: true)));
    }
    if (task == nightTask) {
      String briefing = await DaveService.instance.buildNightBriefing();
      await DaveService.instance.speak(briefing);
      await notifications.show(2, "🌙 Good Night Master $MASTER_NAME", briefing, const NotificationDetails(android: AndroidNotificationDetails('night_channel', 'Night Briefing', importance: Importance.max, playSound: true)));
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // FIXED: Open boxes with timeout
  await Future.wait([
    Hive.openBox('conversations'),
    Hive.openBox('user_data'),
    Hive.openBox('tasks'),
    Hive.openBox('settings'),
  ]).timeout(const Duration(seconds: 5), onTimeout: () => []);
  
  await DaveService.instance.init();
  await _initNotifications();
  await DaveService.instance.scheduleBriefings();
  await [Permission.microphone, Permission.notification].request();
  runApp(const DaveAIApp());
}

Future<void> _initNotifications() async {
  const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(const InitializationSettings(android: android));
}

class DaveAIApp extends StatelessWidget {
  const DaveAIApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'DAVE AI', debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const SplashScreen());
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // FIXED: Only 2 seconds splash now
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const GalaxyBackground(),
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4A00E0).withOpacity(0.3)),
            child: const Icon(Icons.smart_toy, size: 100, color: Color(0xFF00BFFF)),
          ).animate().scale(duration: const Duration(milliseconds: 1000)).fade(),
          const SizedBox(height: 20),
          RichText(text: const TextSpan(children: [
            TextSpan(text: "DAVE ", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
            TextSpan(text: "AI", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF00BFFF))),
          ])).animate().fade(duration: const Duration(milliseconds: 500)),
          const SizedBox(height: 10),
          const Text("Loading Master $MASTER_NAME...", style: TextStyle(color: Colors.white70, fontSize: 16)).animate().fade(delay: const Duration(milliseconds: 500)),
        ])),
      ]),
    );
  }
}

// ... rest of your ChatScreen, GalaxyBackground code is same as last one
