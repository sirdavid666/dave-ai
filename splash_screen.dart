import 'package:flutter/material.dart';
import 'dart:async';
import 'home_shell.dart';
import 'dave_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _initServices();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeShell()));
    });
  }

  Future<void> _initServices() async {
    await DaveService.instance.init();
    await DaveService.instance.scheduleBriefings();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SCI-FI GLOWING ICON
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A90E2).withOpacity(_glowAnimation.value),
                        blurRadius: 40 * _glowAnimation.value,
                        spreadRadius: 10 * _glowAnimation.value,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, size: 100, color: Color(0xFF4A90E2)),
                );
              },
            ),
            const SizedBox(height: 30),
            // SCI-FI TEXT WITH SCAN LINE
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [const Color(0xFF4A90E2), const Color(0xFFFFD700), const Color(0xFF4A90E2)],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds),
              child: const Text(
                'DAVE AI',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4),
              ),
            ),
            const SizedBox(height: 10),
            const Text('INITIALIZING SYSTEMS...', style: TextStyle(color: Color(0xFF4A90E2), fontSize: 14, letterSpacing: 2)),
            const SizedBox(height: 20),
            // LOADING BAR
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: const Color(0xFF1A1A2E),
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFFD700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
