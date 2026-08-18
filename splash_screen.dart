import 'package:flutter/material.dart';
import 'package:particles_flutter/particles_flutter.dart';
import 'dart:async';
import 'home_screen.dart';
import 'dave_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    DaveService.instance.scheduleBriefings();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        alignment: Alignment.center,
        children: [
          CircularParticle(
            key: UniqueKey(),
            awayRadius: 80,
            numberOfParticles: 100,
            speedOfParticles: 1,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            onTapAnimation: true,
            particleColor: const Color(0xFF4A90E2).withOpacity(0.8),
            connectDots: true,
          ),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 90, color: Color(0xFFFFD700)),
              SizedBox(height: 20),
              Text('DAVE AI', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2), letterSpacing: 2)),
              Text('Your Personal Jarvis', style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
