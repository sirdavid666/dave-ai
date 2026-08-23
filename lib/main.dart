import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'pages/chat_page.dart';
import 'pages/voice_page.dart';
import 'services/dave_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Do NOT initialize DAVE's models before runApp().
  //
  // The previous startup flow waited for:
  // - TinyLlama download/load
  // - Whisper download/load
  // - TTS
  // - notifications
  // - WorkManager
  //
  // before Flutter even displayed the real app.
  //
  // If anything failed there, Android could simply close the app.

  runApp(const DaveAIApp());
}

class DaveAIApp extends StatelessWidget {
  const DaveAIApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAVE AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070A12),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String startupStatus = 'Starting DAVE...';

  @override
  void initState() {
    super.initState();

    _startDAVE();
  }

  Future<void> _startDAVE() async {
    // Give Flutter time to completely create the Android activity/UI.
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      startupStatus = 'Requesting permissions...';
    });

    // Permissions are deliberately handled separately.
    //
    // If a permission request fails or is unavailable,
    // DAVE should still be able to open.
    try {
      await Permission.microphone.request();
    } catch (e) {
      debugPrint(
        'MICROPHONE PERMISSION ERROR: $e',
      );
    }

    try {
      await Permission.contacts.request();
    } catch (e) {
      debugPrint(
        'CONTACTS PERMISSION ERROR: $e',
      );
    }

    try {
      await Permission.notification.request();
    } catch (e) {
      debugPrint(
        'NOTIFICATION PERMISSION ERROR: $e',
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      startupStatus = 'Opening DAVE...';
    });

    // IMPORTANT:
    // We initialize DAVE AFTER the Flutter UI exists.
    //
    // Any initialization error is caught here so it cannot
    // crash the whole application.
    try {
      await DaveService.instance.init();
    } catch (e, stack) {
      debugPrint(
        'DAVE STARTUP ERROR: $e',
      );

      debugPrint(
        '$stack',
      );

      // Keep the app alive even if AI initialization fails.
      DaveService.instance.status.value =
          'DAVE opened, but AI setup needs attention.';
    }

    if (!mounted) {
      return;
    }

    // Give the user a short splash screen.
    await Future.delayed(
      const Duration(milliseconds: 800),
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF05070D),
              Color(0xFF101A32),
              Color(0xFF05070D),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.smart_toy,
                size: 100,
                color: Color(0xFF4A90E2),
              ),

              const SizedBox(
                height: 24,
              ),

              const Text(
                'DAVE AI',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                startupStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    VoicePage(),
    ChatPage(),
    MemoryPage(),
    TasksPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'DAVE',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory),
            selectedIcon: Icon(Icons.memory),
            label: 'Memory',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class MemoryPage extends StatefulWidget {
  const MemoryPage({
    super.key,
  });

  @override
  State<MemoryPage> createState() =>
      _MemoryPageState();
}

class _MemoryPageState
    extends State<MemoryPage> {
  final DaveService dave =
      DaveService.instance;

  @override
  Widget build(BuildContext context) {
    final history =
        dave.getConversationHistory();

    final reversed =
        history.reversed.toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              12,
            ),
            child: Text(
              'DAVE Memory',
              style: TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: reversed.isEmpty
                ? const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.all(
                        24,
                      ),
                      child: Text(
                        'No conversations yet, Boss. Talk to DAVE and it will show up here.',
                        textAlign:
                            TextAlign
                                .center,
                        style: TextStyle(
                          color: Colors
                              .white70,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      24,
                      0,
                      24,
                      24,
                    ),
                    itemCount:
                        reversed.length,
                    itemBuilder:
                        (context, index) {
                      final entry =
                          reversed[
                              index];

                      final user =
                          (entry['user'] ??
                                  '')
                              .toString();

                      final daveReply =
                          (entry['dave'] ??
                                  '')
                              .toString();

                      return Container(
                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 16,
                        ),
                        padding:
                            const EdgeInsets
                                .all(
                          14,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors
                              .white
                              .withOpacity(
                            0.05,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Boss: $user',
                              style:
                                  const TextStyle(
                                color: Color(
                                  0xFF4A90E2,
                                ),
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            Text(
                              'DAVE: $daveReply',
                              style:
                                  const TextStyle(
                                color: Colors
                                    .white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
  });

  @override
  State<TasksPage> createState() =>
      _TasksPageState();
}

class _TasksPageState
    extends State<TasksPage> {
  final DaveService dave =
      DaveService.instance;

  final TextEditingController
      controller =
      TextEditingController();

  Future<void> _submit() async {
    final text =
        controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    controller.clear();

    await dave.addTask(text);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              12,
            ),
            child: Text(
              'DAVE Tasks',
              style: TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        controller,
                    onSubmitted:
                        (_) => _submit(),
                    decoration:
                        const InputDecoration(
                      hintText:
                          'Add a task...',
                      border:
                          OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                IconButton.filled(
                  onPressed: _submit,
                  icon: const Icon(
                    Icons.add,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Expanded(
            child: ValueListenableBuilder<
                List<
                    Map<String,
                        dynamic>>>(
              valueListenable:
                  dave.tasks,
              builder:
                  (context, taskList, _) {
                if (taskList.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.all(
                        24,
                      ),
                      child: Text(
                        'No tasks yet, Boss. Add one above or just tell DAVE.',
                        textAlign:
                            TextAlign
                                .center,
                        style: TextStyle(
                          color: Colors
                              .white70,
                        ),
                      ),
                    ),
                  );
                }

                final sorted =
                    [...taskList]..sort(
                        (a, b) {
                          final aDone =
                              a['done'] ==
                                  true;
                          final bDone =
                              b['done'] ==
                                  true;

                          if (aDone ==
                              bDone) {
                            return 0;
                          }

                          return aDone
                              ? 1
                              : -1;
                        },
                      );

                return ListView.builder(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    12,
                    0,
                    12,
                    24,
                  ),
                  itemCount:
                      sorted.length,
                  itemBuilder:
                      (context, index) {
                    final task =
                        sorted[index];

                    final id =
                        task['id']
                            as int;

                    final text =
                        (task['text'] ??
                                '')
                            .toString();

                    final done =
                        task['done'] ==
                            true;

                    final remindAt =
                        task['remindAt'];

                    return CheckboxListTile(
                      value: done,
                      onChanged: (_) =>
                          dave.completeTask(
                        id,
                      ),
                      title: Text(
                        text,
                        style: TextStyle(
                          decoration: done
                              ? TextDecoration
                                  .lineThrough
                              : TextDecoration
                                  .none,
                          color: done
                              ? Colors
                                  .white38
                              : Colors
                                  .white,
                        ),
                      ),
                      subtitle:
                          remindAt != null
                              ? Text(
                                  'Reminder set',
                                  style:
                                      const TextStyle(
                                    color: Color(
                                      0xFF4A90E2,
                                    ),
                                    fontSize:
                                        12,
                                  ),
                                )
                              : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            ValueListenableBuilder<String>(
              valueListenable:
                  DaveService.instance.status,
              builder: (context, status, _) {
                return Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                );
              },
            ),

            const SizedBox(
              height: 20,
            ),

            FilledButton.icon(
              onPressed:
                  DaveService.instance.retryModelSetup,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Retry AI Model Setup',
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'DAVE AI is designed to run its AI brain locally after the initial model download.',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
