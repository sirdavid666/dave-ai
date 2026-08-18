import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: const Center(child: Text('DAVE AI IS LIVE', style: TextStyle(color: Colors.white, fontSize: 24))),
    );
  }
}
