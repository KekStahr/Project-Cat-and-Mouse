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
    'Meetup',
    'Shared meeting point',
    Icons.place_rounded,
    Color(0xFF82C8FF),
  ),
  help(
    'Help needed',
    'Someone needs support',
    Icons.health_and_safety,
    Color(0xFFFF7979),
  ),
  caution(
    'Caution',
    'Stay alert',
    Icons.warning_amber_rounded,
    Color(0xFFFFC46B),
  ),
  checkIn(
    'Safe arrival',
    'Send a quick check-in',
    Icons.check_circle,
    Color(0xFF9BE3C0),
  ),
  regroup(
    'Regroup',
    'Move to the group meeting point',
    Icons.groups_rounded,
    Color(0xFFC3A1FF),
  );

  const SafetyPing(this.label, this.description, this.icon, this.color);
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class ActivePing {
  const ActivePing({
    required this.id,
    required this.type,
    required this.senderName,
    required this.createdAt,
    required this.acknowledgedCount,
    required this.memberCount,
    this.latitude,
    this.longitude,
    this.senderId,
    this.senderRole,
    this.targetMemberId,
    this.targetScope,
  });

  final String id;
  final SafetyPing type;
  final String senderName;
  final DateTime createdAt;
  final int acknowledgedCount;
  final int memberCount;
  final double? latitude;
  final double? longitude;
  final String? senderId;
  final String? senderRole;
  final String? targetMemberId;
  final String? targetScope;

  ActivePing copyWith({double? latitude, double? longitude}) => ActivePing(
    id: id,
    type: type,
    senderName: senderName,
    createdAt: createdAt,
    acknowledgedCount: acknowledgedCount,
    memberCount: memberCount,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    senderId: senderId,
    senderRole: senderRole,
    targetMemberId: targetMemberId,
    targetScope: targetScope,
  );

  bool get isNew =>
      DateTime.now().difference(createdAt.toLocal()) <
      const Duration(seconds: 60);

  String get ageLabel {
    final minutes = DateTime.now().difference(createdAt.toLocal()).inMinutes;
    return minutes < 1 ? 'just now' : '${minutes}m ago';
  }
}

class PingSelection {
  const PingSelection({
    required this.type,
    required this.latitude,
    required this.longitude,
    this.targetMemberId,
    this.targetScope = 'all',
  });

  final SafetyPing type;
  final double latitude;
  final double longitude;
  final String? targetMemberId;
  final String targetScope;
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
    required this.id,
    required this.senderName,
    required this.text,
    required this.mine,
    required this.chatId,
  });

  final String id;
  final String senderName;
  final String text;
  final bool mine;
  final String chatId;
}

class ChatUnreadIcon extends StatelessWidget {
  const ChatUnreadIcon({
    super.key,
    required this.icon,
    required this.globalUnread,
    required this.restrictedUnread,
  });

  final IconData icon;
  final int globalUnread;
  final int restrictedUnread;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    height: 34,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (globalUnread > 0)
          Positioned(
            left: 3,
            top: 0,
            child: _countBadge(
              globalUnread,
              const Color(0xFFE7B84A),
              'Unread Global messages',
            ),
          ),
        if (restrictedUnread > 0)
          Positioned(
            right: 3,
            top: 0,
            child: _countBadge(
              restrictedUnread,
              const Color(0xFFE65252),
              'Unread restricted messages',
            ),
          ),
      ],
    ),
  );
}

Widget _countBadge(int count, Color color, String tooltip) => Tooltip(
  message: tooltip,
  child: Container(
    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
    alignment: Alignment.center,
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
  ),
);

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

  String _groupName = 'No group';
  String? _inviteCode;
  DateTime? _inviteExpiresAt;
  ActivePing? _activePing;
  String? _localPingId;
  double? _localPingLatitude;
  double? _localPingLongitude;
  String? _groupId;
  String? _memberId;
  String? _connectionError;
  Timer? _refreshTimer;
  Timer? _locationHeartbeat;
  StreamSubscription<Position>? _locationSubscription;
  Position? _lastPosition;
  bool _refreshing = false;
  bool _sharingLocation = false;
  bool _editingName = false;
  int _selectedTab = 0;
  String _expiryChoice = '1 hour';
  String _selectedChatId = 'global';
  bool _isLocked = false;
  final _knownMessageIds = <String>{};
  int _unreadGlobalCount = 0;
  int _unreadRestrictedCount = 0;

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
    _nameController.text =
        preferences.getString('reso.displayName') ?? _nameController.text;
    final memberId = _memberId;
    if (memberId != null) {
      _knownMessageIds.addAll(
        preferences.getStringList('reso.seenMessages.$memberId') ?? const [],
      );
      _unreadGlobalCount =
          preferences.getInt('reso.unreadGlobal.$memberId') ?? 0;
      _unreadRestrictedCount =
          preferences.getInt('reso.unreadRestricted.$memberId') ?? 0;
    }
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
      if (_groupId != groupId || _memberId != memberId) return;
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
      final activePing = ping == null
          ? null
          : ActivePing(
              id: ping['id'] as String,
              type: SafetyPing.values.firstWhere(
                (value) => value.name == ping['type'],
                orElse: () => SafetyPing.caution,
              ),
              senderName: ping['sender_name'] as String? ?? 'Group member',
              senderId: ping['sender_id'] as String?,
              senderRole: ping['sender_role'] as String?,
              createdAt: DateTime.parse(ping['created_at'] as String),
              acknowledgedCount:
                  (ping['acknowledged_count'] as num?)?.toInt() ??
                  rawMembers.where((member) {
                    return (member as Map<String, dynamic>)['acknowledged'] ==
                        true;
                  }).length,
              memberCount:
                  (ping['member_count'] as num?)?.toInt() ?? rawMembers.length,
              latitude:
                  (ping['latitude'] as num?)?.toDouble() ??
                  (ping['id'] == _localPingId ? _localPingLatitude : null),
              longitude:
                  (ping['longitude'] as num?)?.toDouble() ??
                  (ping['id'] == _localPingId ? _localPingLongitude : null),
              targetMemberId: ping['target_member_id'] as String?,
              targetScope: ping['target_scope'] as String?,
            );
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
            id: message['id'] as String,
            senderName: message['sender_name'] as String,
            text: text,
            mine: message['sender_id'] == memberId,
            chatId: message['channel'] == 'direct'
                ? 'direct:${message['sender_id'] == memberId ? message['recipient_id'] : message['sender_id']}'
                : message['channel'] as String,
          ),
        );
      }
      final knownMessageCount = _knownMessageIds.length;
      final previousGlobalUnread = _unreadGlobalCount;
      final previousRestrictedUnread = _unreadRestrictedCount;
      if (mounted) {
        setState(() {
          final unread = messages
              .where(
                (message) =>
                    !message.mine && !_knownMessageIds.contains(message.id),
              )
              .toList();
          _knownMessageIds.addAll(messages.map((message) => message.id));
          for (final message in unread) {
            if (_selectedTab == 1 && _selectedChatId == message.chatId) {
              continue;
            }
            if (message.chatId == 'global') {
              _unreadGlobalCount++;
            } else if (message.chatId == 'command' ||
                message.chatId == 'briefing') {
              _unreadRestrictedCount++;
            }
          }
          if (_selectedTab == 1) _markChatRead(_selectedChatId);
          _groupName = group['name'] as String;
          _inviteCode = group['invite_code'] as String?;
          _inviteExpiresAt = group['invite_expires_at'] == null
              ? null
              : DateTime.parse(group['invite_expires_at'] as String);
          if (!_editingName) {
            _nameController.text = currentMember['name'] as String;
          }
          _participants
            ..clear()
            ..addAll(participants);
          _messages
            ..clear()
            ..addAll(messages);
          _activePing = activePing;
          _connectionError = null;
        });
      }
      if (mounted &&
          (_knownMessageIds.length != knownMessageCount ||
              _unreadGlobalCount != previousGlobalUnread ||
              _unreadRestrictedCount != previousRestrictedUnread)) {
        await _persistUnreadState(memberId);
      }
    } catch (error) {
      if (mounted && _groupId == groupId && _memberId == memberId) {
        setState(() => _connectionError = error.toString());
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final group = response['group'] as Map<String, dynamic>;
    final member = response['member'] as Map<String, dynamic>;
    _groupId = group['id'] as String;
    _memberId = member['id'] as String;
    _knownMessageIds.clear();
    _unreadGlobalCount = 0;
    _unreadRestrictedCount = 0;
    _localPingId = null;
    _localPingLatitude = null;
    _localPingLongitude = null;
    _inviteCode = null;
    _inviteExpiresAt = null;
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
      _showNotice('Join a group first.');
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
            'Location sharing stopped, but the server could not clear your location: $error',
          );
        }
      }
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      _showNotice('Please enable location services on your device.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showNotice(
        kIsWeb
            ? 'Safari denied location access. Allow location for this website in Safari settings, then reload the app.'
            : 'Location sharing was not allowed. Check the app permissions in your device settings.',
      );
      return;
    }
    final mobilePlatform =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (mobilePlatform && permission != LocationPermission.always) {
      _showNotice(
        'Allow "Always" location access in app settings to share your location in the background.',
      );
      await Geolocator.openAppSettings();
      return;
    }

    if (mounted) setState(() => _sharingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
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
                    _showNotice('Could not update location: $error');
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
        _showNotice(_locationErrorMessage(error));
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
      if (mounted) _showNotice('Could not share location: $error');
    }
  }

  LocationSettings get _locationSettings {
    const accuracy = LocationAccuracy.high;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: 15,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Reşo is sharing your location',
          notificationText: 'Your group can see your location.',
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
    return const LocationSettings(
      accuracy: accuracy,
      distanceFilter: 15,
      timeLimit: Duration(seconds: 20),
    );
  }

  Future<void> _requestLocation() async {
    if (_sharingLocation) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: _locationSettings,
        );
        _lastPosition = position;
        await _publishLocation(position);
      } catch (error) {
        if (mounted) _showNotice(_locationErrorMessage(error));
      }
      return;
    }
    await _setLocationSharing(true);
  }

  String _locationErrorMessage(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('permission') ||
        message.toLowerCase().contains('denied')) {
      return kIsWeb
          ? 'Safari does not have location access. Allow location for this website in Safari settings and reload the app.'
          : 'Location access is unavailable. Allow the app to access your location in device settings.';
    }
    if (message.toLowerCase().contains('timeout')) {
      return 'Location request timed out. Check GPS/location services and try again.';
    }
    return 'Could not get location: $message';
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
      _showNotice('${member.name} is now an officer.');
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  Future<void> _kickMember(Participant member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${member.name} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null) return;
    try {
      await _api.kickMember(
        groupId: groupId,
        memberId: memberId,
        targetMemberId: member.id,
      );
      await _refreshGroup();
      if (mounted) _showNotice('${member.name} was removed from the group.');
    } catch (error) {
      if (mounted) _showNotice(error.toString());
    }
  }

  void _messageMember(Participant member) {
    setState(() {
      _selectedChatId = 'direct:${member.id}';
      _selectedTab = 1;
    });
  }

  Future<void> _rotateInvite() async {
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null) return;
    try {
      final invite = await _api.rotateInvite(
        groupId: groupId,
        memberId: memberId,
      );
      if (!mounted) return;
      setState(() {
        _inviteCode = invite['invite_code'] as String;
        _inviteExpiresAt = DateTime.parse(
          invite['invite_expires_at'] as String,
        );
      });
      _showNotice('A new invite code is ready.');
    } catch (error) {
      if (mounted) _showNotice(error.toString());
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
      _showNotice('You joined ${officer.name}\'s group.');
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  Future<void> _showInviteCode() async {
    final code = _inviteCode;
    if (code == null) {
      await _rotateInvite();
      if (!mounted || _inviteCode == null) return;
      await _showInviteCode();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite members'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this 8-digit code. It works until the group expires:',
            ),
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
            const SizedBox(height: 12),
            Text(
              _inviteExpiresAt == null
                  ? 'Code expires with the group.'
                  : 'Expires: ${_inviteExpiresAt!.toLocal()}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _rotateInvite();
              if (mounted) await _showInviteCode();
            },
            child: const Text('Generate new code'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) Navigator.pop(context);
              _showNotice('Invite code copied.');
            },
            child: const Text('Copy code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _editName() async {
    if (_groupId != null) {
      _showNotice('Leave the group before changing your name.');
      return;
    }
    _editingName = true;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change name'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name for your next group',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    _editingName = false;
    if (!mounted || name == null) return;
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 24) {
      _showNotice('Your name must be between 1 and 24 characters.');
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('reso.displayName', trimmedName);
    _nameController.text = trimmedName;
    if (mounted) _showNotice('Name saved for your next group.');
  }

  Future<void> _createGroup() async {
    final groupController = TextEditingController(text: _groupName);
    final customHoursController = TextEditingController(text: '24');
    final expiryOptions = [
      '5 minutes',
      '10 minutes',
      '1 hour',
      '2 hours',
      'Custom',
    ];
    var expiry = _expiryChoice;
    final result = await showDialog<(String, String, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: groupController,
                decoration: const InputDecoration(labelText: 'Group name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: expiry,
                decoration: const InputDecoration(labelText: 'Group duration'),
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
              if (expiry == 'Custom')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: customHoursController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration in hours (1–168)',
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    groupController.dispose();
    customHoursController.dispose();
    if (!mounted || result == null) return;

    final durations = <String, Duration>{
      '5 minutes': const Duration(minutes: 5),
      '10 minutes': const Duration(minutes: 10),
      '1 hour': const Duration(hours: 1),
      '2 hours': const Duration(hours: 2),
      'Custom': Duration(hours: result.$3),
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
        _inviteExpiresAt = DateTime.parse(group['invite_expires_at'] as String);
      });
    } catch (error) {
      _showNotice(error.toString());
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.pin_rounded, color: _mint, size: 34),
        title: const Text('Invite ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this 8-digit code with your group:'),
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
          TextButton(
            onPressed: () async {
              final code = _inviteCode;
              if (code == null) return;
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) Navigator.pop(context);
              _showNotice('Invite code copied.');
            },
            child: const Text('Copy code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinGroup() async {
    if (_groupId != null) {
      _showNotice('Leave your current group before joining another.');
      return;
    }
    _joinController.clear();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join group'),
        content: TextField(
          controller: _joinController,
          autofocus: true,
          maxLength: 8,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '8-digit invitation code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _joinController.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (!mounted || code == null || code.isEmpty) return;
    try {
      final response = await _api.joinGroup(
        inviteCode: code.trim(),
        memberName: _nameController.text.trim(),
      );
      await _saveSession(response);
      _showNotice('You joined the group.');
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  Future<void> _leaveGroup() async {
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
          'You can join another group with an invitation code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.leaveGroup(groupId: groupId, memberId: memberId);
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      _locationHeartbeat?.cancel();
      _locationHeartbeat = null;
      _refreshTimer?.cancel();
      _refreshTimer = null;
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('reso.groupId');
      await preferences.remove('reso.memberId');
      if (!mounted) return;
      setState(() {
        _groupId = null;
        _memberId = null;
        _groupName = 'No group';
        _inviteCode = null;
        _inviteExpiresAt = null;
        _sharingLocation = false;
        _lastPosition = null;
        _participants.clear();
        _messages.clear();
        _activePing = null;
        _localPingId = null;
        _localPingLatitude = null;
        _localPingLongitude = null;
        _knownMessageIds.clear();
        _unreadGlobalCount = 0;
        _unreadRestrictedCount = 0;
        _connectionError = null;
        _selectedChatId = 'global';
      });
      _showNotice('You left the group.');
    } catch (error) {
      if (mounted) _showNotice(error.toString());
    }
  }

  Future<void> _setPing(PingSelection selection) async {
    final groupId = _groupId;
    final memberId = _memberId;
    if (groupId == null || memberId == null) {
      _showNotice('Join a group first.');
      return;
    }
    try {
      final createdPing = await _api.createPing(
        groupId: groupId,
        memberId: memberId,
        type: selection.type.name,
        latitude: selection.latitude,
        longitude: selection.longitude,
        targetMemberId: selection.targetMemberId,
        targetScope: selection.targetScope,
      );
      _localPingId = createdPing['id'] as String?;
      _localPingLatitude = selection.latitude;
      _localPingLongitude = selection.longitude;
      if (!mounted) return;
      setState(() => _selectedTab = 0);
      await _refreshGroup();
      _showNotice('Safety alert "${selection.type.label}" sent.');
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  bool get _canMoveActivePing {
    final ping = _activePing;
    final memberId = _memberId;
    if (ping == null || memberId == null) return false;
    final current = _currentParticipant;
    if (current?.isSoldier == true && current?.officerId == null) return false;
    final age = DateTime.now().difference(ping.createdAt.toLocal());
    return age >= Duration.zero &&
        age < const Duration(seconds: 30) &&
        (ping.senderId == memberId || ping.id == _localPingId);
  }

  Future<void> _moveActivePing(double latitude, double longitude) async {
    final groupId = _groupId;
    final memberId = _memberId;
    final ping = _activePing;
    if (!_canMoveActivePing ||
        groupId == null ||
        memberId == null ||
        ping == null) {
      return;
    }
    try {
      await _api.movePing(
        groupId: groupId,
        memberId: memberId,
        pingId: ping.id,
        latitude: latitude,
        longitude: longitude,
      );
      _localPingId = ping.id;
      _localPingLatitude = latitude;
      _localPingLongitude = longitude;
      if (!mounted) return;
      setState(
        () => _activePing = ping.copyWith(
          latitude: latitude,
          longitude: longitude,
        ),
      );
      await _refreshGroup();
    } catch (error) {
      if (mounted) _showNotice(error.toString());
    }
  }

  Future<void> _acknowledgePing() async {
    final groupId = _groupId;
    final memberId = _memberId;
    final ping = _activePing;
    if (groupId == null || memberId == null || ping == null) return;
    try {
      await _api.acknowledgePing(
        groupId: groupId,
        memberId: memberId,
        pingId: ping.id,
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
      _showNotice('Join a group first.');
      return;
    }
    try {
      final isDirect = _selectedChatId.startsWith('direct:');
      final recipientId = isDirect
          ? _selectedChatId.substring('direct:'.length)
          : null;
      final currentMember = _participants
          .where((member) => member.id == memberId)
          .firstOrNull;
      final recipients = isDirect
          ? _participants.where(
              (member) => member.id == memberId || member.id == recipientId,
            )
          : _participants.where((member) {
              if (_selectedChatId == 'global') return true;
              if (_selectedChatId == 'command') {
                return member.isGeneral || member.isOfficer;
              }
              return member.isOfficer || member.isSoldier;
            });
      if (!isDirect &&
          currentMember != null &&
          ((_selectedChatId == 'command' &&
                  !currentMember.isGeneral &&
                  !currentMember.isOfficer) ||
              (_selectedChatId == 'briefing' &&
                  !currentMember.isOfficer &&
                  !currentMember.isSoldier))) {
        throw const GroupApiException('You do not have access to this chat.');
      }
      final recipientList = recipients.toList();
      final publicKeys = <String, String>{
        for (final member in recipientList)
          if (member.publicKey != null) member.id: member.publicKey!,
      };
      if (publicKeys.length != recipientList.length) {
        throw const GroupApiException(
          'Chat keys are not ready for all recipients. Wait a moment and try again.',
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
        channel: isDirect ? 'direct' : _selectedChatId,
        recipientId: recipientId,
        encryptedPayload: encryptedPayload,
      );
      await _refreshGroup();
    } catch (error) {
      _showNotice(error.toString());
    }
  }

  Participant? get _currentParticipant =>
      _participants.where((member) => member.id == _memberId).firstOrNull;

  Map<String, String> get _chatRooms {
    final member = _currentParticipant;
    return {
      'global': 'Global',
      if (member?.isGeneral == true || member?.isOfficer == true)
        'command': "General's Meeting",
      if (member?.isOfficer == true || member?.isSoldier == true)
        'briefing': 'Briefing',
    };
  }

  void _markChatRead(String chatId) {
    if (chatId == 'global') {
      _unreadGlobalCount = 0;
    } else if (chatId == 'command' || chatId == 'briefing') {
      _unreadRestrictedCount = 0;
    }
  }

  Future<void> _persistUnreadState(String memberId) async {
    final preferences = await SharedPreferences.getInstance();
    if (_memberId != memberId) return;
    final seenIds = _knownMessageIds.toList();
    await preferences.setStringList(
      'reso.seenMessages.$memberId',
      seenIds.length > 200 ? seenIds.sublist(seenIds.length - 200) : seenIds,
    );
    await preferences.setInt('reso.unreadGlobal.$memberId', _unreadGlobalCount);
    await preferences.setInt(
      'reso.unreadRestricted.$memberId',
      _unreadRestrictedCount,
    );
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
                  'App is locked',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock the app to view the map and chats.',
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
                  child: const Text('Unlock'),
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
                    onRequestLocation: _requestLocation,
                    activePing: _activePing,
                    canMoveActivePing: _canMoveActivePing,
                    onPingSelected: _setPing,
                    onPingMoved: _moveActivePing,
                    onAcknowledge: _acknowledgePing,
                    currentIsGeneral: _currentParticipant?.isGeneral ?? false,
                    onPromoteMember: _promoteToOfficer,
                    onKickMember: _kickMember,
                    onMessageMember: _messageMember,
                  ),
                  ChatScreen(
                    messages: _messages,
                    onSendMessage: _sendMessage,
                    chatController: _chatController,
                    rooms: _chatRooms,
                    activeChatId: _selectedChatId,
                    directChatLabel: _participants
                        .where(
                          (member) => 'direct:${member.id}' == _selectedChatId,
                        )
                        .map((member) => member.name)
                        .firstOrNull,
                    onRoomSelected: (chatId) {
                      setState(() {
                        _selectedChatId = chatId;
                        _markChatRead(chatId);
                      });
                      final memberId = _memberId;
                      if (memberId != null) {
                        unawaited(_persistUnreadState(memberId));
                      }
                    },
                    participants: _participants,
                    currentMemberName: _currentParticipant?.name,
                  ),
                  PeopleScreen(
                    participants: _participants,
                    hasActivePing:
                        _activePing != null &&
                        !(_currentParticipant?.isSoldier == true &&
                            _currentParticipant?.officerId == null),
                    memberId: _memberId,
                    searchController: _searchController,
                    onPromoteToOfficer: _promoteToOfficer,
                    onJoinOfficerGroup: _joinOfficerGroup,
                    onKickMember: _kickMember,
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
        if (_groupId != null && _currentParticipant?.isGeneral == true)
          IconButton(
            icon: const Icon(Icons.pin_rounded, size: 18, color: _mint),
            tooltip: 'Invite members',
            onPressed: _showInviteCode,
          ),
        if (_groupId == null)
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            tooltip: 'Change name',
            onPressed: _editName,
          ),
        PopupMenuButton<String>(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu_rounded),
          color: _surfaceRaised,
          onSelected: (value) async {
            switch (value) {
              case 'name':
                _editName();
              case 'create':
                _createGroup();
              case 'join':
                _joinGroup();
              case 'leave':
                _leaveGroup();
              case 'lock':
                setState(() => _isLocked = true);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('reso.locked', true);
            }
          },
          itemBuilder: (context) => [
            if (_groupId == null)
              const PopupMenuItem(value: 'name', child: Text('Change name')),
            if (_memberId == null ||
                _participants.any(
                  (member) => member.id == _memberId && member.isGeneral,
                ))
              const PopupMenuItem(value: 'create', child: Text('Create group')),
            if (_memberId != null)
              const PopupMenuItem(value: 'leave', child: Text('Leave group')),
            const PopupMenuItem(value: 'join', child: Text('Join group')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'lock', child: Text('Lock app')),
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
      onDestinationSelected: (index) {
        setState(() {
          _selectedTab = index;
          if (index == 1) _markChatRead(_selectedChatId);
        });
        final memberId = _memberId;
        if (index == 1 && memberId != null) {
          unawaited(_persistUnreadState(memberId));
        }
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map_rounded),
          label: 'Map',
        ),
        NavigationDestination(
          icon: ChatUnreadIcon(
            icon: Icons.chat_bubble_outline_rounded,
            globalUnread: _unreadGlobalCount,
            restrictedUnread: _unreadRestrictedCount,
          ),
          selectedIcon: ChatUnreadIcon(
            icon: Icons.chat_rounded,
            globalUnread: _unreadGlobalCount,
            restrictedUnread: _unreadRestrictedCount,
          ),
          label: 'Chat',
        ),
        const NavigationDestination(
          icon: Icon(Icons.people_outline_rounded),
          selectedIcon: Icon(Icons.people_rounded),
          label: 'People',
        ),
      ],
    ),
  );
}
