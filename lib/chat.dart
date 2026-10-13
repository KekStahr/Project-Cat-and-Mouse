import 'package:flutter/material.dart';
import 'main.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.messages,
    required this.onSendMessage,
    required this.chatController,
  });

  final List<ChatMessage> messages;
  final ValueChanged<String> onSendMessage;
  final TextEditingController chatController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Row(
            children: const [
              Text('Gruppenchat', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return Align(
                alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.mine ? const Color(0xFF203B33) : const Color(0xFF121B26),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.senderName, style: const TextStyle(color: Color(0xFF9BE3C0), fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(message.text),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: chatController,
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      onSendMessage(val.trim());
                      chatController.clear();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Nachricht schreiben …',
                    filled: true,
                    fillColor: const Color(0xFF121B26),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  final val = chatController.text.trim();
                  if (val.isNotEmpty) {
                    onSendMessage(val);
                    chatController.clear();
                  }
                },
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}