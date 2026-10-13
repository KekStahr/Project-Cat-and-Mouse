import 'package:flutter/material.dart';
import 'main.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({
    super.key,
    required this.participants,
    required this.activePing,
    required this.memberId,
    required this.searchController,
    required this.onAcknowledge,
  });

  final List<Participant> participants;
  final SafetyPing? activePing;
  final String? memberId;
  final TextEditingController searchController;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.toLowerCase();
    final visible = participants.where((m) => m.name.toLowerCase().contains(query)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Row(
            children: [
              Text('Personen (${participants.length})', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Person suchen',
              filled: true,
              fillColor: const Color(0xFF121B26),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 7),
            itemBuilder: (context, index) {
              final member = visible[index];
              final awaiting = activePing != null && !member.acknowledged;
              final isMe = member.id == memberId;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: BoxDecoration(
                  color: awaiting ? const Color(0xFF351F24) : const Color(0xFF121B26),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: member.organizer ? const Color(0xFF9BE3C0).withValues(alpha: .16) : const Color(0xFF1A2634),
                      child: Text(member.name.characters.first.toUpperCase(), style: TextStyle(color: member.organizer ? const Color(0xFF9BE3C0) : Colors.white)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(
                            member.online ? '🟢 Online (Signal gut)' : '⚪ Offline / Kein Signal',
                            style: const TextStyle(color: Color(0xFF8B9AAA), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (awaiting && isMe)
                      FilledButton.tonal(
                        onPressed: onAcknowledge,
                        child: const Text('Bestätigen'),
                      )
                    else if (awaiting)
                      const Text('Ausstehend', style: TextStyle(color: Color(0xFFFF7979), fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}