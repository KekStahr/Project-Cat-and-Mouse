import 'package:flutter/material.dart';

import 'main.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.messages,
    required this.onSendMessage,
    required this.chatController,
    required this.rooms,
    required this.activeChatId,
    required this.directChatLabel,
    required this.onRoomSelected,
  });

  final List<ChatMessage> messages;
  final ValueChanged<String> onSendMessage;
  final TextEditingController chatController;
  final Map<String, String> rooms;
  final String activeChatId;
  final String? directChatLabel;
  final ValueChanged<String> onRoomSelected;

  @override
  Widget build(BuildContext context) {
    final visibleMessages = messages
        .where((message) => message.chatId == activeChatId)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Chats',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.lock_rounded, size: 13, color: Color(0xFF9BE3C0)),
                  SizedBox(width: 5),
                  Text(
                    'Messages are encrypted on your devices',
                    style: TextStyle(color: Color(0xFF8B9AAA), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final entry in rooms.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: activeChatId == entry.key,
                    onSelected: (_) => onRoomSelected(entry.key),
                  ),
                ),
              if (activeChatId.startsWith('direct:') && directChatLabel != null)
                ChoiceChip(
                  label: Text(directChatLabel!),
                  selected: true,
                  onSelected: (_) {},
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            itemCount: visibleMessages.length,
            itemBuilder: (context, index) {
              final message = visibleMessages[index];
              return Align(
                alignment: message.mine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.mine
                        ? const Color(0xFF203B33)
                        : const Color(0xFF121B26),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.senderName,
                        style: const TextStyle(
                          color: Color(0xFF9BE3C0),
                          fontSize: 11,
                        ),
                      ),
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
                    hintText: 'Write a message...',
                    filled: true,
                    fillColor: const Color(0xFF121B26),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
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
