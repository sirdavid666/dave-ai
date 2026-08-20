import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // ADDED THIS
import 'package:flutter_animate/flutter_animate.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart'; // ADDED THIS
import 'dart:io';

import 'dave_service.dart';

const String morningTask = "morningBriefingTask";
const String nightTask = "nightBriefingTask";
const String MASTER_NAME = "DAVID EWAOLUWA";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Hive.initFlutter();
    final DaveService dave = DaveService.instance;
    await dave.init();
    final notifications = FlutterLocalNotificationsPlugin();
    
    if (task == morningTask) {
      String briefing = await dave.buildMorningBriefing();
      await notifications.show(1, "DAVE AI Morning", briefing, const NotificationDetails(android: AndroidNotificationDetails('morning_channel', 'Morning Briefing', importance: Importance.max)));
    }
    if (task == nightTask) {
      String briefing = await dave.buildNightBriefing();
      await notifications.show(2, "DAVE AI Night", briefing, const NotificationDetails(android: AndroidNotificationDetails('night_channel', 'Night Briefing', importance: Importance.max)));
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await DaveService.instance.init();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await _scheduleDailyBriefings();
  await [Permission.microphone, Permission.notification, Permission.storage].request();
  runApp(const DaveAIApp());
}

Future<void> _scheduleDailyBriefings() async {
  await Workmanager().registerPeriodicTask("1", morningTask, frequency: const Duration(hours: 24), initialDelay: _getInitialDelay(7, 0), constraints: Constraints(networkType: NetworkType.not_required));
  await Workmanager().registerPeriodicTask("2", nightTask, frequency: const Duration(hours: 24), initialDelay: _getInitialDelay(22, 0), constraints: Constraints(networkType: NetworkType.not_required));
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
    return MaterialApp(
      title: 'DAVE AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const DaveHomePage(),
    );
  }
}

class DaveHomePage extends StatefulWidget {
  const DaveHomePage({super.key});
  @override
  State<DaveHomePage> createState() => _DaveHomePageState();
}

class _DaveHomePageState extends State<DaveHomePage> {
  int _currentIndex = 0;
  late WebViewController _controller;
  bool _brainReady = false;

  final List<String> _titles = ['Chat', 'Voice', 'Memory', 'Settings'];

  @override
  void initState() {
    super.initState();
    _prepareBrain();
  }

  Future<void> _prepareBrain() async {
    final dir = await getApplicationDocumentsDirectory(); // NOW WORKS
    final file = File('${dir.path}/index.html');
    if (!await file.exists()) {
      final data = await rootBundle.loadString('assets/index.html'); // NOW WORKS
      await file.writeAsString(data.replaceAll("Master", "Master $MASTER_NAME"));
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadFile(file.path);
    setState(() => _brainReady = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("DAVE AI - ${_titles[_currentIndex]}", style: const TextStyle(color: Color(0xFF00FF88))),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
      ),
      body: Stack(
        children: [
          const StarField(),
          _buildBody(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.black.withOpacity(0.7),
        selectedItemColor: const Color(0xFF00FF88),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Voice'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology_alt), label: 'Memory'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return const Center(child: Text("Chat with DAVE", style: TextStyle(color: Colors.white, fontSize: 20)));
      case 1: return VoiceTab(controller: _controller, brainReady: _brainReady);
      case 2: return const Center(child: Text("Memory of DAVID EWAOLUWA", style: TextStyle(color: Colors.white, fontSize: 20)));
      case 3: return const Center(child: Text("Settings", style: TextStyle(color: Colors.white, fontSize: 20)));
      default: return Container();
    }
  }
}

class VoiceTab extends StatefulWidget {
  final WebViewController controller;
  final bool brainReady;
  const VoiceTab({super.key, required this.controller, required this.brainReady});

  @override
  State<VoiceTab> createState() => _VoiceTabState();
}

class _VoiceTabState extends State<VoiceTab> {
  bool _isListening = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.brainReady) WebViewWidget(controller: widget.controller),
        Positioned(
          bottom: 100,
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  widget.controller.runJavaScript('if(typeof rec !== "undefined") rec.start();');
                  setState(() => _isListening = true);
                  Future.delayed(const Duration(seconds: 5), () => setState(() => _isListening = false));
                },
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, 
                    color: _isListening ? Colors.red : const Color(0xFF00ff88),
                    boxShadow: [BoxShadow(color: const Color(0xFF00ff88), blurRadius: 40, spreadRadius: _isListening ? 20 : 5)]
                  ),
                  child: const Icon(Icons.mic, size: 50, color: Colors.black),
                ).animate(target: _isListening ? 1 : 0).scale(duration: 600.ms).then().scale(duration: 600.ms),
              ),
              const SizedBox(height: 20),
              Text(
                widget.brainReady ? "TAP TO TALK, MASTER $MASTER_NAME" : "BOOTING BRAIN...",
                style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.2),
              )
            ],
          ),
        )
      ],
    );
  }
}

class StarField extends StatefulWidget {
  const StarField({super.key});
  @override
  State<StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<StarField> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 50))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(painter: StarPainter(_controller.value), size: MediaQuery.of(context).size),
    );
  }
}

class StarPainter extends CustomPainter {
  final double progress;
  StarPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.8);
    for (int i = 0; i < 150; i++) {
      double x = (i * 37.0 + progress * 500) % size.width;
      double y = (i * 53.0) % size.height;
      canvas.drawCircle(Offset(x, y), 1.2, paint);
    }
  }
  @override
  bool shouldRepaint(covariant StarPainter old) => true;
}
