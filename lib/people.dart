import 'package:flutter/material.dart';

import 'main.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({
    super.key,
    required this.participants,
    required this.activePing,
    required this.memberId,
    required this.searchController,
    required this.onAcknowledge,
    required this.onPromoteToOfficer,
    required this.onJoinOfficerGroup,
  });

  final List<Participant> participants;
  final SafetyPing? activePing;
  final String? memberId;
  final TextEditingController searchController;
  final VoidCallback onAcknowledge;
  final ValueChanged<Participant> onPromoteToOfficer;
  final ValueChanged<Participant> onJoinOfficerGroup;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  Color _memberColor(Participant member, Map<String, Participant> officers) {
    if (member.isGeneral) return const Color(0xFFFF3B30);
    final hex = member.isOfficer
        ? member.color
        : officers[member.officerId]?.color;
    if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return const Color(0xFF1A2634);
    }
    return Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.searchController.text.toLowerCase();
    final visible = widget.participants
        .where((member) => member.name.toLowerCase().contains(query))
        .toList();
    Participant? me;
    for (final member in widget.participants) {
      if (member.id == widget.memberId) me = member;
    }
    final officers = {
      for (final member in widget.participants)
        if (member.isOfficer) member.id: member,
    };
    final currentOfficer = officers[me?.officerId];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Row(
            children: [
              Text(
                'People (${widget.participants.length})',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (me?.isSoldier ?? false)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: officers.isEmpty
                    ? null
                    : () => _chooseOfficer(context, officers.values.toList()),
                icon: const Icon(Icons.shield_outlined),
                label: Text(
                  currentOfficer == null
                      ? 'Choose an officer group'
                      : 'Group: ${currentOfficer.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: widget.searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by name',
              filled: true,
              fillColor: const Color(0xFF121B26),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (role, label) in [
                ('general', 'General'),
                ('officer', 'Officers'),
                ('soldier', 'Soldiers'),
              ])
                ExpansionTile(
                  key: PageStorageKey<String>('people-$role'),
                  title: Text(
                    '$label (${visible.where((m) => m.role == role).length})',
                  ),
                  children: [
                    for (final member in visible.where((m) => m.role == role))
                      _memberCard(member, me, officers),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _memberCard(
    Participant member,
    Participant? me,
    Map<String, Participant> officers,
  ) {
    final awaiting = widget.activePing != null && !member.acknowledged;
    final isMe = member.id == widget.memberId;
    final color = _memberColor(member, officers);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: awaiting ? const Color(0xFF351F24) : const Color(0xFF121B26),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .22),
            child: Text(
              member.name.characters.first.toUpperCase(),
              style: TextStyle(color: color),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_roleName(member.role)} · ${member.online ? 'Online' : 'Offline'}',
                  style: const TextStyle(
                    color: Color(0xFF8B9AAA),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (me?.isGeneral == true && member.isSoldier && !isMe)
            IconButton(
              tooltip: 'Promote to officer',
              onPressed: () => widget.onPromoteToOfficer(member),
              icon: const Icon(
                Icons.military_tech_rounded,
                color: Color(0xFFFFC46B),
              ),
            )
          else if (awaiting && isMe)
            FilledButton.tonal(
              onPressed: widget.onAcknowledge,
              child: const Text('Acknowledge'),
            )
          else if (awaiting)
            const Text(
              'Pending',
              style: TextStyle(color: Color(0xFFFF7979), fontSize: 11),
            ),
        ],
      ),
    );
  }

  Future<void> _chooseOfficer(
    BuildContext context,
    List<Participant> officers,
  ) async {
    final officer = await showModalBottomSheet<Participant>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Join an officer group',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final officer in officers)
              ListTile(
                leading: const Icon(Icons.shield_rounded),
                title: Text(officer.name),
                subtitle: Text(
                  '${widget.participants.where((member) => member.officerId == officer.id).length} soldiers',
                ),
                onTap: () => Navigator.pop(context, officer),
              ),
          ],
        ),
      ),
    );
    if (officer != null) widget.onJoinOfficerGroup(officer);
  }

  String _roleName(String role) => switch (role) {
    'general' => 'General',
    'officer' => 'Officer',
    _ => 'Soldier',
  };
}
