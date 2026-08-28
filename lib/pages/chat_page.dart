import 'package:flutter/material.dart';

import '../services/dave_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
  });

  @override
  State<ChatPage> createState() =>
      _ChatPageState();
}

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;
}

class _ChatPageState
    extends State<ChatPage> {
  final DaveService dave =
      DaveService.instance;

  final TextEditingController
      controller =
      TextEditingController();

  final ScrollController
      scrollController =
      ScrollController();

  final List<_ChatMessage> messages =
      [];

  bool sending = false;

  @override
  void initState() {
    super.initState();

    final history =
        dave.getConversationHistory();

    for (final entry in history) {
      final user =
          (entry['user'] ?? '')
              .toString();

      final daveReply =
          (entry['dave'] ?? '')
              .toString();

      if (user.isNotEmpty) {
        messages.add(
          _ChatMessage(
            text: user,
            isUser: true,
          ),
        );
      }

      if (daveReply.isNotEmpty) {
        messages.add(
          _ChatMessage(
            text: daveReply,
            isUser: false,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController
              .position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 250,
          ),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text =
        controller.text.trim();

    if (text.isEmpty || sending) {
      return;
    }

    controller.clear();

    setState(() {
      messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
        ),
      );
      sending = true;
    });

    _scrollToBottom();

    try {
      final reply =
          await dave.chat(text);

      if (!mounted) {
        return;
      }

      setState(() {
        messages.add(
          _ChatMessage(
            text: reply,
            isUser: false,
          ),
        );
        sending = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        messages.add(
          _ChatMessage(
            text:
                'Something went wrong, Boss: $e',
            isUser: false,
          ),
        );
        sending = false;
      });
    }

    _scrollToBottom();
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              12,
            ),
            child: Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                'Chat with DAVE',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),

          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.all(
                        24,
                      ),
                      child: Text(
                        'Type a message below to chat with DAVE, Boss.',
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
                    controller:
                        scrollController,
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      16,
                      0,
                      16,
                      12,
                    ),
                    itemCount:
                        messages.length,
                    itemBuilder:
                        (context, index) {
                      final message =
                          messages[
                              index];

                      return Align(
                        alignment: message
                                .isUser
                            ? Alignment
                                .centerRight
                            : Alignment
                                .centerLeft,
                        child: Container(
                          constraints:
                              BoxConstraints(
                            maxWidth:
                                MediaQuery.of(
                                          context,
                                        )
                                        .size
                                        .width *
                                    0.78,
                          ),
                          margin:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 6,
                          ),
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration:
                              BoxDecoration(
                            color: message
                                    .isUser
                                ? const Color(
                                    0xFF4A90E2,
                                  )
                                : Colors
                                    .white
                                    .withOpacity(
                                    0.08,
                                  ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                          ),
                          child: Text(
                            message.text,
                            style:
                                const TextStyle(
                              color: Colors
                                  .white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          if (sending)
            const Padding(
              padding: EdgeInsets.only(
                bottom: 8,
              ),
              child: Text(
                'DAVE is typing...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        controller,
                    onSubmitted:
                        (_) => _send(),
                    textInputAction:
                        TextInputAction
                            .send,
                    decoration:
                        const InputDecoration(
                      hintText:
                          'Message DAVE...',
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .all(
                          Radius.circular(
                            24,
                          ),
                        ),
                      ),
                      contentPadding:
                          EdgeInsets
                              .symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                IconButton.filled(
                  onPressed: sending
                      ? null
                      : _send,
                  icon: const Icon(
                    Icons.send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
