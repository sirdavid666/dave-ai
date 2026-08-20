import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/dave_service.dart';

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
  await Future.wait([Hive.openBox('conversations'), Hive.openBox('user_data'), Hive.openBox('tasks'), Hive.openBox('settings')]).timeout(const Duration(seconds: 5), onTimeout: () => []);
  await DaveService.instance.init();
  await _initNotifications();
  await DaveService.instance.scheduleBriefings();
  await [Permission.microphone, Permission.notification, Permission.storage].request();
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
          const Text("Loading Master DAVID...", style: TextStyle(color: Colors.white70, fontSize: 16)).animate().fade(delay: const Duration(milliseconds: 500)),
        ])),
      ]),
    );
  }
}

class GalaxyBackground extends StatelessWidget {
  const GalaxyBackground({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243e)], begin: Alignment.topLeft, end: Alignment.bottomRight)));
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    setState(() { _messages.add({"role": "user", "text": _controller.text}); _isLoading = true; });
    String userMsg = _controller.text;
    _controller.clear();
    String response = await DaveService.instance.chat(userMsg);
    setState(() { _messages.add({"role": "assistant", "text": response}); _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const GalaxyBackground(),
        Column(children: [
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              bool isUser = msg["role"] == "user";
              return Align(alignment: isUser? Alignment.centerRight : Alignment.centerLeft,
                child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isUser? const Color(0xFF4A00E0) : const Color(0xFF00BFFF), borderRadius: BorderRadius.circular(12)),
                  child: Text(msg["text"]!, style: const TextStyle(color: Colors.white)),
                ),
              );
            },
          )),
          if(_isLoading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Color(0xFF00BFFF))),
          Padding(padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(child: TextField(controller: _controller, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Talk to DAVE...", hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),),
              IconButton(icon: const Icon(Icons.send, color: Color(0xFF00BFFF)), onPressed: _sendMessage)
            ]),
          )
        ]),
      ]),
    );
  }
}
