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
  await Hive.openBox('conversations');
  await Hive.openBox('user_data');
  await Hive.openBox('tasks');
  await Hive.openBox('settings');
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
    Future.delayed(const Duration(seconds: 3), () {
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
          ).animate().scale(duration: const Duration(milliseconds: 1000)).fade(), // FIXED
          const SizedBox(height: 20),
          RichText(text: const TextSpan(children: [
            TextSpan(text: "DAVE ", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
            TextSpan(text: "AI", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF00BFFF))),
          ])).animate().fade(duration: const Duration(milliseconds: 500)),
          const SizedBox(height: 10),
          const Text("Your smart productivity assistant", style: TextStyle(color: Colors.white70, fontSize: 16)).animate().fade(delay: const Duration(milliseconds: 500)),
        ])),
      ]),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  late WebViewController _brainController;
  bool _brainReady = false;

  final List<Map<String, dynamic>> _suggestions = [
    {"text": "Plan my today's tasks", "icon": Icons.calendar_today, "color": Colors.blue},
    {"text": "Give me productivity tips", "icon": Icons.lightbulb, "color": Colors.amber},
    {"text": "Help me stay focused", "icon": Icons.gps_fixed, "color": Colors.red},
    {"text": "Motivate me", "icon": Icons.star, "color": Colors.yellow},
  ];

  @override
  void initState() {
    super.initState();
    _prepareBrain();
  }

  Future<void> _prepareBrain() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/index.html');
    if (!await file.exists()) {
      final data = await rootBundle.loadString('assets/index.html');
      await file.writeAsString(data.replaceAll("Master", "Master $MASTER_NAME"));
    }
    _brainController = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadFile(file.path);
    setState(() => _brainReady = true);
  }

  void _sendMessage(String msg) async {
    if (msg.isEmpty) return;
    setState(() => _chatMessages.add({'role': 'user', 'msg': msg}));
    _chatController.clear();
    String aiReply = await DaveService.instance.chat(msg); // NOW WORKS
    setState(() => _chatMessages.add({'role': 'dave', 'msg': aiReply}));
    DaveService.instance.speak(aiReply);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const GalaxyBackground(),
        SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [
            const CircleAvatar(backgroundColor: Color(0xFF4A00E0), child: Icon(Icons.smart_toy, color: Colors.white)),
            const SizedBox(width: 10),
            const Text("Dave AI", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ])),
          Expanded(child: _chatMessages.isEmpty? _buildWelcome() : _buildChatList()),
          _buildInputBar(),
        ])),
      ]),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Hey Master $MASTER_NAME! 👋", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
      const Text("How can I help you today?", style: TextStyle(fontSize: 16, color: Colors.white70)),
      const SizedBox(height: 30),
    ..._suggestions.map((s) => _suggestionChip(s['text'], s['icon'], s['color'])).toList(),
    ]));
  }

  Widget _suggestionChip(String text, IconData icon, Color color) {
    return GestureDetector(onTap: () => _sendMessage(text), child: Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(color: Colors.white)))])
    ));
  }

  Widget _buildChatList() {
    return ListView.builder(padding: const EdgeInsets.all(10), itemCount: _chatMessages.length, itemBuilder: (context, i) {
      bool isUser = _chatMessages[i]['role'] == 'user';
      return Align(alignment: isUser? Alignment.centerRight : Alignment.centerLeft, child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: isUser? const Color(0xFF4A00E0) : Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
        child: Text(_chatMessages[i]['msg']!, style: const TextStyle(color: Colors.white)),
      ));
    });
  }

  Widget _buildInputBar() {
    return Container(padding: const EdgeInsets.all(12), color: Colors.black.withOpacity(0.3), child: Row(children: [
      Expanded(child: TextField(controller: _chatController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(
        hintText: "Ask Dave AI anything...", hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
      ))),
      const SizedBox(width: 8),
      CircleAvatar(backgroundColor: const Color(0xFF4A00E0), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () {
        _sendMessage(_chatController.text);
      })),
    ]));
  }
}

class GalaxyBackground extends StatefulWidget {
  const GalaxyBackground({super.key});
  @override
  State<GalaxyBackground> createState() => _GalaxyBackgroundState();
}

class _GalaxyBackgroundState extends State<GalaxyBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _controller, builder: (_, __) => Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B1026), Color(0xFF1a0b3d), Color(0xFF0B1026)])),
      child: CustomPaint(painter: GalaxyPainter(_controller.value), size: MediaQuery.of(context).size),
    ));
  }
}

class GalaxyPainter extends CustomPainter {
  final double progress;
  GalaxyPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 200; i++) {
      double x = (i * 37.0 + progress * 300) % size.width;
      double y = (i * 53.0) % size.height;
      double opacity = 0.5 + 0.5 * sin(progress * 2 * pi + i);
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), Random(i).nextDouble() * 2, paint);
    }
  }
  @override
  bool shouldRepaint(covariant GalaxyPainter old) => true;
}
