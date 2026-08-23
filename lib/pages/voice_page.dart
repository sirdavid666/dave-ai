import 'package:flutter/material.dart';

import '../services/dave_service.dart';

class VoicePage
    extends StatefulWidget {
  const VoicePage({
    super.key,
  });

  @override
  State<VoicePage>
      createState() =>
          _VoicePageState();
}

class _VoicePageState
    extends State<VoicePage> {
  final DaveService dave =
      DaveService.instance;

  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                MediaQuery.of(context)
                        .size
                        .height -
                    MediaQuery.of(context)
                        .padding
                        .top -
                    MediaQuery.of(context)
                        .padding
                        .bottom,
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
          const SizedBox(
            height: 30,
          ),

          const Text(
            'DAVE AI',
            style: TextStyle(
              fontSize: 30,
              fontWeight:
                  FontWeight.bold,
              letterSpacing: 3,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          ValueListenableBuilder<
              String>(
            valueListenable:
                dave.status,
            builder:
                (context, status, _) {
              return Text(
                status,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                ),
              );
            },
          ),

          const SizedBox(
            height: 40,
          ),

          ValueListenableBuilder<
              String>(
            valueListenable:
                dave.transcript,
            builder:
                (context, text, _) {
              return Padding(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 24,
                ),
                child: Text(
                  text.isEmpty
                      ? 'Tap the reactor and talk to DAVE.'
                      : 'You: $text',
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 17,
                    color:
                        Colors.white70,
                  ),
                ),
              );
            },
          ),

          const SizedBox(
            height: 20,
          ),

          ValueListenableBuilder<
              String>(
            valueListenable:
                dave.response,
            builder:
                (context, text, _) {
              return Padding(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 24,
                ),
                child: Text(
                  text,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              );
            },
          ),

          const SizedBox(
            height: 40,
          ),

          ValueListenableBuilder<
              String>(
            valueListenable:
                dave.status,
            builder:
                (context, status, _) {
              final listening =
                  status.contains(
                'listening',
              );

              final ready =
                  dave.isReady &&
                      dave.isWhisperReady;

              return GestureDetector(
                onTap: ready
                    ? dave.startListening
                    : dave.retryModelSetup,
                child: AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds: 250,
                  ),
                  width: 190,
                  height: 190,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    border: Border.all(
                      color: listening
                          ? Colors
                              .redAccent
                          : const Color(
                              0xFF4A90E2,
                            ),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: listening
                            ? Colors
                                .redAccent
                                .withOpacity(
                                0.4,
                              )
                            : const Color(
                                0xFF4A90E2,
                              ).withOpacity(
                                0.4,
                              ),
                        blurRadius: 35,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      listening
                          ? Icons.mic
                          : Icons
                              .smart_toy,
                      size: 80,
                      color: listening
                          ? Colors
                              .redAccent
                          : const Color(
                              0xFF4A90E2,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(
            height: 25,
          ),

          const Text(
            'TAP TO TALK',
            style: TextStyle(
              letterSpacing: 2,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.white54,
            ),
          ),

          const SizedBox(
            height: 35,
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
