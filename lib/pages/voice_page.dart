import 'package:flutter/material.dart';
import '../services/dave_service.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  final DaveService dave = DaveService.instance;

  @override
  void initState() {
    super.initState();

    dave.status.addListener(_refresh);
    dave.transcript.addListener(_refresh);
    dave.response.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    dave.status.removeListener(_refresh);
    dave.transcript.removeListener(_refresh);
    dave.response.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = dave.isReady;

    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            const Text(
              'DAVE',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 5,
              ),
            ),

            const Text(
              'PERSONAL AI',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 4,
                color: Colors.white54,
              ),
            ),

            const Spacer(),

            AnimatedContainer(
              duration:
                  const Duration(milliseconds: 500),
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ready
                      ? const Color(0xFF4A90E2)
                      : Colors.orange,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ready
                        ? const Color(0xFF4A90E2)
                            .withOpacity(0.35)
                        : Colors.orange
                            .withOpacity(0.25),
                    blurRadius: 35,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                ready
                    ? Icons.smart_toy
                    : Icons.cloud_download,
                size: 85,
                color: ready
                    ? const Color(0xFF4A90E2)
                    : Colors.orange,
              ),
            ),

            const SizedBox(height: 35),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 28,
              ),
              child: Text(
                dave.status.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (dave.transcript.value.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 24,
                ),
                child: Text(
                  'You: ${dave.transcript.value}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            if (dave.response.value.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 24,
                ),
                child: Text(
                  dave.response.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),

            const Spacer(),

            if (!ready)
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 30,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        dave.retryModelSetup,
                    child: const Text(
                      'RETRY AI SETUP',
                    ),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: dave.startListening,
                child: Container(
                  width: 105,
                  height: 105,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        const Color(0xFF4A90E2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF4A90E2,
                        ).withOpacity(0.45),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            const Text(
              'TAP TO TALK',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 3,
                color: Colors.white38,
              ),
            ),

            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }
}
