import 'package:flutter/material.dart';

import 'main.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.messages,
    required this.onSendMessage,
    required this.chatController,
    required this.rooms,
    required this.activeChatId,
    required this.directChatLabel,
    required this.onRoomSelected,
    required this.participants,
    required this.currentMemberName,
  });

  final List<ChatMessage> messages;
  final ValueChanged<String> onSendMessage;
  final TextEditingController chatController;
  final Map<String, String> rooms;
  final String activeChatId;
  final String? directChatLabel;
  final ValueChanged<String> onRoomSelected;
  final List<Participant> participants;
  final String? currentMemberName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _mentionQuery;
  int? _mentionStart;

  void _handleMessageChanged(String value) {
    final cursor = widget.chatController.selection.extentOffset;
    if (cursor < 0 || cursor > value.length) {
      setState(() {
        _mentionQuery = null;
        _mentionStart = null;
      });
      return;
    }
    final match = RegExp(r'@([^\s@]*)$').firstMatch(value.substring(0, cursor));
    setState(() {
      _mentionQuery = match?.group(1);
      _mentionStart = match?.start;
    });
  }

  void _insertMention(String name) {
    final value = widget.chatController.value;
    final start = _mentionStart;
    final cursor = value.selection.extentOffset;
    if (start == null || cursor < start) return;
    final insertion = '@$name ';
    final text = value.text.replaceRange(start, cursor, insertion);
    widget.chatController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
    setState(() {
      _mentionQuery = null;
      _mentionStart = null;
    });
  }

  List<InlineSpan> _messageSpans(String text, TextStyle baseStyle) {
    final name = widget.currentMemberName;
    if (name == null || name.isEmpty) return [TextSpan(text: text)];
    final expression = RegExp(RegExp.escape('@$name'), caseSensitive: false);
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in expression.allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: baseStyle.copyWith(
            color: const Color(0xFF9BE3C0),
            backgroundColor: const Color(0x553CB879),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final visibleMessages = widget.messages
        .where((message) => message.chatId == widget.activeChatId)
        .toList();
    final query = _mentionQuery;
    final suggestions = query == null
        ? const <Participant>[]
        : widget.participants
              .where(
                (member) =>
                    member.name != widget.currentMemberName &&
                    member.name.toLowerCase().startsWith(query.toLowerCase()),
              )
              .take(5)
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
              for (final entry in widget.rooms.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: widget.activeChatId == entry.key,
                    onSelected: (_) => widget.onRoomSelected(entry.key),
                  ),
                ),
              if (widget.activeChatId.startsWith('direct:') &&
                  widget.directChatLabel != null)
                ChoiceChip(
                  label: Text(widget.directChatLabel!),
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
                      Builder(
                        builder: (context) {
                          final style = DefaultTextStyle.of(context).style;
                          return RichText(
                            text: TextSpan(
                              style: style,
                              children: _messageSpans(message.text, style),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final member = suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.alternate_email_rounded, size: 18),
                  title: Text(member.name),
                  onTap: () => _insertMention(member.name),
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
                  controller: widget.chatController,
                  onChanged: _handleMessageChanged,
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      widget.onSendMessage(val.trim());
                      widget.chatController.clear();
                      setState(() {
                        _mentionQuery = null;
                        _mentionStart = null;
                      });
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
                  final val = widget.chatController.text.trim();
                  if (val.isNotEmpty) {
                    widget.onSendMessage(val);
                    widget.chatController.clear();
                    setState(() {
                      _mentionQuery = null;
                      _mentionStart = null;
                    });
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
