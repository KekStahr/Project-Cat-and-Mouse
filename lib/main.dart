import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'group_api.dart';
import 'map.dart';
import 'chat.dart';
import 'people.dart';

void main() => runApp(const ResoApp());

const _background = Color(0xFF0A1018);
const _surface = Color(0xFF121B26);
const _surfaceRaised = Color(0xFF1A2634);
const _mint = Color(0xFF9BE3C0);
const _muted = Color(0xFF8B9AAA);

class ResoApp extends StatelessWidget {
  const ResoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reşo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _mint,
          brightness: Brightness.dark,
          surface: _surface,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const GroupHomePage(),
    );
  }
}

enum SafetyPing {
  meetup('Treffpunkt', 'Gemeinsamer Treffpunkt', Icons.place_rounded, Color(0xFF82C8FF)),
  help('Hilfe benötigt', 'Jemand braucht Unterstützung', Icons.health_and_safety, Color(0xFFFF7979)),
  caution('Achtung', 'Bitte aufmerksam bleiben', Icons.warning_amber_rounded, Color(0xFFFFC46B)),
  checkIn('Sicher angekommen', 'Kurze Rückmeldung geben', Icons.check_circle, Color(0xFF9BE3C0)),
  regroup('Gruppe sammeln', 'Bitte zum Gruppenpunkt kommen', Icons.groups_rounded, Color(0xFFC3A1FF)),
  sos('SOS NOTRUF', 'Kritische Gefahrenlage!', Icons.warning_rounded, Color(0xFFFF3B30));

  const SafetyPing(this.label, this.description, this.icon, this.color);
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class Participant {
  Participant({
    required this.id,
    required this.name,
    required this.online,
    required this.organizer,
    required this.acknowledged,
  });
  final String id;
  final String name;
  bool online;
  final bool organizer;
  bool acknowledged;
}

class ChatMessage {
  const ChatMessage({
    required this.senderName,
    required this.text,
    required this.mine,
  });

  final String senderName;
  final String text;
  final bool mine;
}

class GroupHomePage extends StatefulWidget {
  const GroupHomePage({super.key});

  @override
  State<GroupHomePage> createState() => _GroupHomePageState();
}

class _GroupHomePageState extends State<GroupHomePage> {
  final _api = GroupApi();
  final _nameController = TextEditingController(text: 'Alex');
  final _joinController = TextEditingController();
  final _chatController = TextEditingController();
  final _searchController = TextEditingController();
  final _participants = <Participant>[];
  final _messages = <ChatMessage>[];

  String _groupName = 'Keine Gruppe';
  String? _inviteCode;
  SafetyPing? _activePing;
  String? _activePingId;
  String? _groupId;
  String? _memberId;
  String? _connectionError;
  Timer? _refreshTimer;
  bool _refreshing = false;
  int _selectedTab = 0;
  String _expiryChoice = '1 Stunde';
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    _groupId = preferences.getString('reso.groupId');
    _memberId = preferences.getString('reso.memberId');
    _isLocked = preferences.getBool('reso.locked') ?? false;
    if (!mounted) return;
    if (_groupId == null || _memberId == null) {
      setState(() {});
      return;
    }
    await _refreshGroup();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshGroup(),
    );
  }

  Future<void> _refreshGroup() async {
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null || _refreshing) return;
    _refreshing = true;
    try {
      final data = await _api.fetchGroup(groupId: groupId, memberId: memberId);
      final group = data['group'] as Map<String, dynamic>;
      final ping = data['activePing'] as Map<String, dynamic>?;
      final pingId = ping?['id'] as String?;
      if (mounted) {
        setState(() {
          _groupName = group['name'] as String;
          _inviteCode = group['invite_code'] as String?;
          _participants
            ..clear()
            ..addAll(
              (data['members'] as List<dynamic>).map((item) {
                final member = item as Map<String, dynamic>;
                return Participant(
                  id: member['id'] as String,
                  name: member['name'] as String,
                  online: member['online'] as bool,
                  organizer: member['role'] == 'organizer',
                  acknowledged: member['acknowledged'] as bool,
                );
              }),
            );
          _messages
            ..clear()
            ..addAll(
              (data['messages'] as List<dynamic>).map((item) {
                final message = item as Map<String, dynamic>;
                return ChatMessage(
                  senderName: message['sender_name'] as String,
                  text: message['text'] as String,
                  mine: message['sender_id'] == memberId,
                );
              }),
            );
          _activePingId = pingId;
          _activePing = ping == null
              ? null
              : SafetyPing.values.firstWhere(
                  (value) => value.name == ping['type'],
                  orElse: () => SafetyPing.caution,
                );
          _connectionError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _connectionError = error.toString());
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final group = response['group'] as Map<String, dynamic>;
    final member = response['member'] as Map<String, dynamic>;
    _groupId = group['id'] as String;
    _memberId = member['id'] as String;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('reso.groupId', _groupId!);
    await preferences.setString('reso.memberId', _memberId!);
    if (!mounted) return;
    await _refreshGroup();
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshGroup(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _api.close();
    _nameController.dispose();
    _joinController.dispose();
    _chatController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showNotice(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _createGroup() async {
    final groupController = TextEditingController(text: _groupName);
    final customHoursController = TextEditingController(text: '24');
    final expiryOptions = ['5 Minuten', '10 Minuten', '1 Stunde', '2 Stunden', 'Individuell'];
    var expiry = _expiryChoice;
    final result = await showDialog<(String, String, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Gruppe erstellen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: groupController,
                decoration: const InputDecoration(labelText: 'Gruppenname'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: expiry,
                decoration: const InputDecoration(labelText: 'Code gültig für'),
                items: expiryOptions
                    .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => expiry = value);
                },
              ),
              if (expiry == 'Individuell')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: customHoursController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Gültigkeit in Stunden (1–168)'),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                final name = groupController.text.trim();
                final customHours = int.tryParse(customHoursController.text.trim());
                if (name.isEmpty) return;
                Navigator.pop(context, (name, expiry, customHours ?? 24));
              },
              child: const Text('Erstellen'),
            ),
          ],
        ),
      ),
    );
    groupController.dispose();
    customHoursController.dispose();
    if (!mounted || result == null) return;

    final durations = <String, Duration>{
      '5 Minuten': const Duration(minutes: 5),
      '10 Minuten': const Duration(minutes: 10),
      '1 Stunde': const Duration(hours: 1),
      '2 Stunden': const Duration(hours: 2),
      'Individuell': Duration(hours: result.$3),
    };

    try {
      final response = await _api.createGroup(
        groupName: result.$1,
        memberName: _nameController.text.trim(),
        expiresInMinutes: durations[result.$2]!.inMinutes,
      );
      await _saveSession(response);
      final group = response['group'] as Map<String, dynamic>;
      setState(() {
        _groupName = group['name'] as String;
        _expiryChoice = result.$2;
        _inviteCode = group['invite_code'] as String;
      });
    } catch (error) {
      _showNotice(error.toString());
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.link_rounded, color: _mint, size: 34),
        title: const Text('Einladung bereit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Teile diesen Code mit deiner Gruppe:'),
            const SizedBox(height: 14),
            SelectableText(
              _inviteCode ?? '',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 7, color: _mint),
            ),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fertig')),
        ],
      ),
    );
  }

  Future<void> _joinGroup() async {
    _joinController.clear();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruppe beitreten'),
        content: TextField(
          controller: _joinController,
          autofocus: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '6-stelliger Code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(context, _joinController.text.trim()),
            child: const Text('Beitreten'),
          ),
        ],
      ),
    );
    if (!mounted || code == null || code.isEmpty) return;
    try {
      final response = await _api.joinGroup(inviteCode: code, memberName: _nameController.text.trim());
      await _saveSession(response);
      _showNotice('Erfolgreich beigetreten!');
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  Future<void> _setPing(SafetyPing ping) async {
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null) {
      _showNotice('Tritt zuerst einer Gruppe bei.');
      return;
    }
    try {
      await _api.createPing(groupId: groupId, memberId: memberId, type: ping.name);
      if (!mounted) return;
      setState(() => _selectedTab = 2);
      await _refreshGroup();
      _showNotice('Sicherheitsmeldung „${ping.label}“ gesendet!');
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  Future<void> _acknowledgePing() async {
    final groupId = _groupId;
    final memberId = _memberId;
    final pingId = _activePingId;
    if (groupId == null || memberId == null || pingId == null) return;
    try {
      await _api.acknowledgePing(groupId: groupId, memberId: memberId, pingId: pingId);
      await _refreshGroup();
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  Future<void> _sendMessage(String text) async {
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null) {
      _showNotice('Tritt zuerst einer Gruppe bei.');
      return;
    }
    try {
      await _api.sendMessage(groupId: groupId, memberId: memberId, text: text);
      await _refreshGroup();
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, size: 64, color: _mint),
                const SizedBox(height: 16),
                const Text('App ist gesperrt', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Bitte entsperren, um Standort und Chat zu sehen.', textAlign: TextAlign.center, style: TextStyle(color: _muted)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    setState(() => _isLocked = false);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('reso.locked', false);
                  },
                  child: const Text('Entsperren'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  MapScreen(
                    groupName: _groupName,
                    connectionError: _connectionError,
                    groupId: _groupId,
                    participantCount: _participants.length,
                    onlineCount: _participants.where((p) => p.online).length,
                    activePing: _activePing,
                    onPingSelected: _setPing,
                  ),
                  ChatScreen(
                    messages: _messages,
                    onSendMessage: _sendMessage,
                    chatController: _chatController,
                  ),
                  PeopleScreen(
                    participants: _participants,
                    activePing: _activePing,
                    memberId: _memberId,
                    searchController: _searchController,
                    onAcknowledge: _acknowledgePing,
                  ),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _mint.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.explore_rounded, color: _mint),
        ),
        const SizedBox(width: 10),
        const Text('Reşo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (_inviteCode != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: _mint),
            tooltip: 'Einladungscode kopieren',
            onPressed: () => _showNotice('Code: $_inviteCode'),
          ),
        PopupMenuButton<String>(
          tooltip: 'Menü',
          icon: const Icon(Icons.menu_rounded),
          color: _surfaceRaised,
          onSelected: (value) async {
            switch (value) {
              case 'create':
                _createGroup();
              case 'join':
                _joinGroup();
              case 'lock':
                setState(() => _isLocked = true);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('reso.locked', true);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'create', child: Text('Gruppe erstellen')),
            PopupMenuItem(value: 'join', child: Text('Gruppe beitreten')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'lock', child: Text('App sperren (Sicherheit)')),
          ],
        ),
      ],
    ),
  );

  Widget _bottomBar() => Container(
    decoration: BoxDecoration(
      color: _surface,
      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .05))),
    ),
    child: NavigationBar(
      height: 68,
      backgroundColor: _surface,
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) => setState(() => _selectedTab = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Karte'),
        NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_rounded), label: 'Chat'),
        NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Personen'),
      ],
    ),
  );
}