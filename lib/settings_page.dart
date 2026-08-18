import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dave_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _svc = DaveService.instance;
  int? _batteryLevel;

  @override
  void initState() {
    super.initState();
    _loadBattery();
  }

  Future<void> _loadBattery() async {
    final level = await _svc.currentBatteryLevel();
    if (mounted) setState(() => _batteryLevel = level);
  }

  bool _get(String key, bool fallback) =>
      _svc.settingsBox.get(key, defaultValue: fallback) as bool;

  void _set(String key, bool value) {
    setState(() => _svc.settingsBox.put(key, value));
  }

  Future<void> _confirmClearMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text("Clear all memory?",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "This deletes all facts, chats, and tasks stored on this device. This can't be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _svc.userDataBox.clear();
      await _svc.conversationsBox.clear();
      await _svc.tasksBox.clear();
      _svc.userDataBox.put('name', 'David Ewaoluwa');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Memory cleared, Boss. Fresh start.")),
        );
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text("Settings",
            style: TextStyle(
                color: Color(0xFF4A90E2), fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF1A1A24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatBlock(
                      icon: Icons.battery_charging_full,
                      label: "Battery",
                      value: _batteryLevel != null
                          ? "$_batteryLevel%"
                          : "..."),
                  _StatBlock(
                      icon: Icons.access_time,
                      label: "Time",
                      value: DateFormat('h:mm a').format(now)),
                  _StatBlock(
                      icon: Icons.calendar_today,
                      label: "Date",
                      value: DateFormat('MMM d').format(now)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _switchTile(
            "Wake Word (\"Dave\" / \"Hey Dave\")",
            "Listens while the Voice tab is open",
            'wake_word_on',
          ),
          _switchTile(
            "Catchphrases",
            "Boss-style personality phrases in replies",
            'catchphrases_on',
          ),
          _switchTile(
            "Morning Briefing (7:00 AM)",
            "Daily notification + spoken briefing if app is open",
            'morning_briefing_on',
          ),
          _switchTile(
            "Night Briefing (10:00 PM)",
            "Daily notification + spoken wrap-up if app is open",
            'night_briefing_on',
          ),
          _switchTile(
            "Proactive Mode",
            "Master switch for briefings and idle check-ins",
            'proactive_mode_on',
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _confirmClearMemory,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.15),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text("Clear Memory"),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "DAVE AI — 100% offline\nDark #0A0A0F · Blue #4A90E2 · "
              "Purple #8B5CF6 · Gold #FFD700\nBuilt for Boss David Ewaoluwa.",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, String key) {
    return Card(
      color: const Color(0xFF1A1A24),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        activeColor: const Color(0xFF8B5CF6),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle:
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        value: _get(key, true),
        onChanged: (v) => _set(key, v),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatBlock({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFFD700), size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}
