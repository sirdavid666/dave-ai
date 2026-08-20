import 'package:flutter/material.dart';
import 'package:particles_flutter/particles_flutter.dart';
import 'dart:async';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Moving stars
          ParticlesFlutter(
            color: const Color(0xFF4A90E2),
            particleSize: 2,
            speedOfParticle: 0.5,
            numberOfParticles: 100,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("DAVE", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
                Text("AI", style: TextStyle(fontSize: 32, color: Color(0xFF4A90E2))),
                const SizedBox(height: 20),
                Text("Your Jarvis. 100% Offline.", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
