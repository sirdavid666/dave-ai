import 'package:flutter/material.dart';
import 'package:particles_flutter/particles_flutter.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

import 'home_shell.dart';

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
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Moving star particles across the whole screen.
          CircularParticle(
            key: UniqueKey(),
            width: size.width,
            height: size.height,
            numberOfParticles: 60,
            speedOfParticles: 0.6,
            height2: size.height,
            width2: size.width,
            particleColor: Colors.white.withOpacity(0.7),
            awayRadius: 80,
            maxParticleSize: 3,
            isRandSize: true,
            isRandomColor: false,
            connectDots: false,
            enableHover: false,
            defaultColor: const Color(0xFF4A90E2),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Color(0xFFFFD700), size: 50),
                ),
                const SizedBox(height: 28),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFFFFD700)],
                  ).createShader(bounds),
                  child: const Text(
                    "DAVE AI",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                  child: AnimatedTextKit(
                    isRepeatingAnimation: false,
                    animatedTexts: [
                      TyperAnimatedText("Yes Boss, I dey here...",
                          speed: const Duration(milliseconds: 45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
