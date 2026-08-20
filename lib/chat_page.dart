import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dave_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _box = Hive.box('conversations');
  List<Map> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages = _box.get('chat_history', defaultValue: []).cast<Map>();
  }

  void _sendMessage() {
    if (_controller.text.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': _controller.text});
    });
    
    String reply = DaveService.getRuleBasedReply(_controller.text); // Will connect to TinyLlama later
    setState(() {
      _messages.add({'role': 'dave', 'text': reply});
    });
    
    _box.put('chat_history', _messages);
    _controller.clear();
    DaveService.speak(reply); // Auto speak reply
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat with DAVE", style: TextStyle(color: Color(0xFFFFD700)))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                bool isUser = _messages[i]['role'] == 'user';
                return Align(
                  alignment: isUser? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.all(8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser? Color(0xFF4A90E2) : Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(_messages[i]['text'], style: TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(child: TextField(controller: _controller, decoration: InputDecoration(hintText: "Talk to Boss DAVE..."))),
              IconButton(icon: Icon(Icons.send, color: Color(0xFFFFD700)), onPressed: _sendMessage)
            ],
          )
        ],
      ),
    );
  }
}
