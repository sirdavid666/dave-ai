import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dave_service.dart';
import 'models/dave_models.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final _svc = DaveService.instance;
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();

  void _addFact() {
    final k = _keyController.text.trim();
    final v = _valueController.text.trim();
    if (k.isEmpty || v.isEmpty) return;
    setState(() {
      _svc.addMemoryFact(k, v);
      _keyController.clear();
      _valueController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final facts = _svc.memoryFacts;
    final tasks = _svc.allTasks
      ..sort((a, b) => (a.dueTime ?? DateTime(2100))
          .compareTo(b.dueTime ?? DateTime(2100)));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text("Memory",
            style: TextStyle(
                color: Color(0xFF4A90E2), fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle("Facts & Preferences"),
          ...facts.entries.map((e) => Card(
                color: const Color(0xFF1A1A24),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(e.key,
                      style: const TextStyle(
                          color: Color(0xFFFFD700), fontSize: 13)),
                  subtitle: Text("${e.value}",
                      style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: () => setState(() => _svc.deleteMemoryFact(e.key)),
                  ),
                ),
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Fact name (e.g. goal)"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _valueController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Value"),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF4A90E2)),
                onPressed: _addFact,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionTitle("DaveFlow — Tasks & Reminders"),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "No tasks yet. Try saying 'remind me to pray at 5am' in Chat or Voice.",
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ...tasks.map((t) => Card(
                color: const Color(0xFF1A1A24),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Checkbox(
                    value: t.done,
                    activeColor: const Color(0xFF8B5CF6),
                    onChanged: (_) => setState(() => _svc.toggleTaskDone(t)),
                  ),
                  title: Text(
                    t.title,
                    style: TextStyle(
                      color: Colors.white,
                      decoration:
                          t.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: t.dueTime != null
                      ? Text(DateFormat('MMM d, h:mm a').format(t.dueTime!),
                          style: const TextStyle(color: Colors.white38))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: () => setState(() => _svc.deleteTask(t)),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1A1A24),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
