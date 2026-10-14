import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'group_api.dart';
import 'map.dart';
import 'chat.dart';
import 'chat_crypto.dart';
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
  meetup(
    'Treffpunkt',
    'Gemeinsamer Treffpunkt',
    Icons.place_rounded,
    Color(0xFF82C8FF),
  ),
  help(
    'Hilfe benötigt',
    'Jemand braucht Unterstützung',
    Icons.health_and_safety,
    Color(0xFFFF7979),
  ),
  caution(
    'Achtung',
    'Bitte aufmerksam bleiben',
    Icons.warning_amber_rounded,
    Color(0xFFFFC46B),
  ),
  checkIn(
    'Sicher angekommen',
    'Kurze Rückmeldung geben',
    Icons.check_circle,
    Color(0xFF9BE3C0),
  ),
  regroup(
    'Gruppe sammeln',
    'Bitte zum Gruppenpunkt kommen',
    Icons.groups_rounded,
    Color(0xFFC3A1FF),
  ),
  sos(
    'SOS NOTRUF',
    'Kritische Gefahrenlage!',
    Icons.warning_rounded,
    Color(0xFFFF3B30),
  );

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
    required this.role,
    required this.acknowledged,
    required this.officerId,
    required this.color,
    required this.publicKey,
    required this.latitude,
    required this.longitude,
  });
  final String id;
  final String name;
  bool online;
  final String role;
  bool acknowledged;
  final String? officerId;
  final String? color;
  final String? publicKey;
  final double? latitude;
  final double? longitude;

  bool get isGeneral => role == 'general';
  bool get isOfficer => role == 'officer';
  bool get isSoldier => role == 'soldier';
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
  final _chatCrypto = ChatCrypto();
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
  Timer? _locationHeartbeat;
  StreamSubscription<Position>? _locationSubscription;
  Position? _lastPosition;
  bool _refreshing = false;
  bool _sharingLocation = false;
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
    try {
      await _api.updateLocation(groupId: _groupId!, memberId: _memberId!);
    } catch (error) {
      if (mounted) setState(() => _connectionError = error.toString());
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
      final rawMembers = data['members'] as List<dynamic>;
      final currentMember = rawMembers.cast<Map<String, dynamic>>().firstWhere(
        (member) => member['id'] == memberId,
      );
      final publicKey = await _chatCrypto.initialize(
        memberId,
        registeredPublicKey: currentMember['public_key'] as String?,
      );
      if (currentMember['public_key'] == null) {
        await _api.registerChatKey(
          groupId: groupId,
          memberId: memberId,
          publicKey: publicKey,
        );
      }
      final ping = data['activePing'] as Map<String, dynamic>?;
      final pingId = ping?['id'] as String?;
      final participants = rawMembers.map((item) {
        final member = item as Map<String, dynamic>;
        return Participant(
          id: member['id'] as String,
          name: member['name'] as String,
          online: member['online'] as bool,
          role: member['role'] as String,
          acknowledged: member['acknowledged'] as bool,
          officerId: member['officer_id'] as String?,
          color: member['color'] as String?,
          publicKey: member['id'] == memberId
              ? publicKey
              : member['public_key'] as String?,
          latitude: member['latitude'] as double?,
          longitude: member['longitude'] as double?,
        );
      }).toList();
      final messages = <ChatMessage>[];
      for (final item in data['messages'] as List<dynamic>) {
        final message = item as Map<String, dynamic>;
        final text = await _chatCrypto.decryptForMember(
          payload: Map<String, dynamic>.from(
            message['encrypted_payload'] as Map,
          ),
          groupId: groupId,
          senderId: message['sender_id'] as String,
          recipientId: memberId,
        );
        if (text == null) continue;
        messages.add(
          ChatMessage(
            senderName: message['sender_name'] as String,
            text: text,
            mine: message['sender_id'] == memberId,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _groupName = group['name'] as String;
          _inviteCode = group['invite_code'] as String?;
          _participants
            ..clear()
            ..addAll(participants);
          _messages
            ..clear()
            ..addAll(messages);
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
    _locationHeartbeat?.cancel();
    _locationSubscription?.cancel();
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

  Future<void> _setLocationSharing(bool enabled) async {
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null) {
      _showNotice('Tritt zuerst einer Gruppe bei.');
      return;
    }
    if (!enabled) {
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      _locationHeartbeat?.cancel();
      _locationHeartbeat = null;
      _lastPosition = null;
      if (mounted) setState(() => _sharingLocation = false);
      try {
        await _api.updateLocation(groupId: groupId, memberId: memberId);
      } catch (error) {
        if (mounted) {
          _showNotice(
            'Standortfreigabe beendet, Server konnte Standort nicht löschen: $error',
          );
        }
      }
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      _showNotice('Bitte aktiviere die Standortdienste auf deinem Gerät.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showNotice('Standortfreigabe wurde nicht erlaubt.');
      return;
    }
    final mobilePlatform =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (mobilePlatform && permission != LocationPermission.always) {
      _showNotice(
        'Für Hintergrund-Standortfreigabe erlaube „Immer“ in den App-Einstellungen.',
      );
      await Geolocator.openAppSettings();
      return;
    }

    if (mounted) setState(() => _sharingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      _lastPosition = position;
      await _publishLocation(position);
      await _locationSubscription?.cancel();
      _locationSubscription =
          Geolocator.getPositionStream(locationSettings: _locationSettings)
              .listen(
                (position) {
                  _lastPosition = position;
                  unawaited(_publishLocation(position));
                },
                onError: (Object error) {
                  if (mounted) {
                    _showNotice(
                      'Standort konnte nicht aktualisiert werden: $error',
                    );
                  }
                },
              );
      _locationHeartbeat?.cancel();
      _locationHeartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
        final lastPosition = _lastPosition;
        if (lastPosition != null) unawaited(_publishLocation(lastPosition));
      });
    } catch (error) {
      if (mounted) {
        setState(() => _sharingLocation = false);
        _showNotice('Standort konnte nicht geteilt werden: $error');
      }
    }
  }

  Future<void> _publishLocation(Position position) async {
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null || !_sharingLocation) return;
    try {
      await _api.updateLocation(
        groupId: groupId,
        memberId: memberId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await _refreshGroup();
    } catch (error) {
      if (mounted) _showNotice('Standort konnte nicht geteilt werden: $error');
    }
  }

  LocationSettings get _locationSettings {
    const accuracy = LocationAccuracy.high;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: 15,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Reşo teilt deinen Standort',
          notificationText: 'Deine Gruppe kann deinen Standort sehen.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: 15,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: accuracy, distanceFilter: 15);
  }

  Future<void> _promoteToOfficer(Participant member) async {
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null) return;
    try {
      await _api.promoteToOfficer(
        groupId: groupId,
        memberId: memberId,
        targetMemberId: member.id,
      );
      await _refreshGroup();
      _showNotice('${member.name} ist jetzt Offizier.');
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  Future<void> _joinOfficerGroup(Participant officer) async {
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null) return;
    try {
      await _api.joinOfficerGroup(
        groupId: groupId,
        memberId: memberId,
        officerId: officer.id,
      );
      await _refreshGroup();
      _showNotice('Du bist der Gruppe von ${officer.name} beigetreten.');
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  Future<void> _showInviteCode() async {
    final code = _inviteCode;
    if (code == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weitere Personen einladen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Teile diesen Einladungscode mit deiner Gruppe:'),
            const SizedBox(height: 12),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 7,
                color: _mint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) Navigator.pop(context);
              _showNotice('Einladungscode kopiert.');
            },
            child: const Text('Kopieren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    final groupController = TextEditingController(text: _groupName);
    final customHoursController = TextEditingController(text: '24');
    final expiryOptions = [
      '5 Minuten',
      '10 Minuten',
      '1 Stunde',
      '2 Stunden',
      'Individuell',
    ];
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
                    .map(
                      (option) =>
                          DropdownMenuItem(value: option, child: Text(option)),
                    )
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
                    decoration: const InputDecoration(
                      labelText: 'Gültigkeit in Stunden (1–168)',
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final name = groupController.text.trim();
                final customHours = int.tryParse(
                  customHoursController.text.trim(),
                );
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
        memberId: _memberId,
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
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 7,
                color: _mint,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fertig'),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _joinController.text.trim()),
            child: const Text('Beitreten'),
          ),
        ],
      ),
    );
    if (!mounted || code == null || code.isEmpty) return;
    try {
      final response = await _api.joinGroup(
        inviteCode: code,
        memberName: _nameController.text.trim(),
      );
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
      await _api.createPing(
        groupId: groupId,
        memberId: memberId,
        type: ping.name,
      );
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
      await _api.acknowledgePing(
        groupId: groupId,
        memberId: memberId,
        pingId: pingId,
      );
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
      final publicKeys = <String, String>{
        for (final member in _participants)
          if (member.publicKey != null) member.id: member.publicKey!,
      };
      if (publicKeys.length != _participants.length) {
        throw const GroupApiException(
          'Chat-Schlüssel fehlen für Gruppenmitglieder. Bitte kurz warten und erneut versuchen.',
        );
      }
      final encryptedPayload = await _chatCrypto.encryptForMembers(
        text: text,
        groupId: groupId,
        senderId: memberId,
        publicKeys: publicKeys,
      );
      await _api.sendMessage(
        groupId: groupId,
        memberId: memberId,
        encryptedPayload: encryptedPayload,
      );
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
                const Text(
                  'App ist gesperrt',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bitte entsperren, um Standort und Chat zu sehen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
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
                    members: _participants,
                    currentMemberId: _memberId,
                    isSharingLocation: _sharingLocation,
                    onLocationSharingChanged: _setLocationSharing,
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
                    onPromoteToOfficer: _promoteToOfficer,
                    onJoinOfficerGroup: _joinOfficerGroup,
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
        const Text(
          'Reşo',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        if (_inviteCode != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: _mint),
            tooltip: 'Weitere Personen einladen',
            onPressed: _showInviteCode,
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
          itemBuilder: (context) => [
            if (_memberId == null ||
                _participants.any(
                  (member) => member.id == _memberId && member.isGeneral,
                ))
              const PopupMenuItem(
                value: 'create',
                child: Text('Gruppe erstellen'),
              ),
            const PopupMenuItem(value: 'join', child: Text('Gruppe beitreten')),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'lock',
              child: Text('App sperren (Sicherheit)'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _bottomBar() => Container(
    decoration: BoxDecoration(
      color: _surface,
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: .05)),
      ),
    ),
    child: NavigationBar(
      height: 68,
      backgroundColor: _surface,
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) => setState(() => _selectedTab = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map_rounded),
          label: 'Karte',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: Icon(Icons.chat_rounded),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline_rounded),
          selectedIcon: Icon(Icons.people_rounded),
          label: 'Personen',
        ),
      ],
    ),
  );
}
