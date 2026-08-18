/// Simple chat message model. We store these in Hive as Map<String,dynamic>
/// (no TypeAdapter/codegen needed) so the box works out of the box.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map map) => ChatMessage(
        text: map['text'] as String,
        isUser: map['isUser'] as bool,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}

/// A DaveFlow task/reminder. Stored the same way — plain maps in Hive.
class DaveTask {
  final String id;
  final String title;
  final DateTime? dueTime;
  bool done;

  DaveTask({
    required this.id,
    required this.title,
    this.dueTime,
    this.done = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'dueTime': dueTime?.toIso8601String(),
        'done': done,
      };

  factory DaveTask.fromMap(Map map) => DaveTask(
        id: map['id'] as String,
        title: map['title'] as String,
        dueTime: map['dueTime'] != null ? DateTime.parse(map['dueTime']) : null,
        done: map['done'] as bool? ?? false,
      );
}
