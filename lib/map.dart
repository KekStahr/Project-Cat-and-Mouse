import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'main.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.groupName,
    required this.connectionError,
    required this.groupId,
    required this.members,
    required this.currentMemberId,
    required this.isSharingLocation,
    required this.onLocationSharingChanged,
    required this.onRequestLocation,
    required this.activePing,
    required this.onPingSelected,
    required this.onAcknowledge,
    required this.currentIsGeneral,
    required this.onPromoteMember,
    required this.onKickMember,
    required this.onMessageMember,
  });

  final String groupName;
  final String? connectionError;
  final String? groupId;
  final List<Participant> members;
  final String? currentMemberId;
  final bool isSharingLocation;
  final ValueChanged<bool> onLocationSharingChanged;
  final Future<void> Function() onRequestLocation;
  final ActivePing? activePing;
  final ValueChanged<PingSelection> onPingSelected;
  final VoidCallback onAcknowledge;
  final bool currentIsGeneral;
  final ValueChanged<Participant> onPromoteMember;
  final ValueChanged<Participant> onKickMember;
  final ValueChanged<Participant> onMessageMember;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _pingPulse;
  bool _centerWhenLocated = false;

  @override
  void initState() {
    super.initState();
    _pingPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );
    if (widget.activePing != null) _pingPulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activePing == null) {
      _pingPulse
        ..stop()
        ..value = 0;
    } else if (oldWidget.activePing == null) {
      _pingPulse.repeat(reverse: true);
    }
    final ping = widget.activePing;
    if (ping != null && ping.id != oldWidget.activePing?.id) {
      _focusPing(ping);
    }
    if (!_centerWhenLocated) return;
    final member = _currentMember;
    if (member?.latitude == null || member?.longitude == null) return;
    _centerWhenLocated = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(LatLng(member!.latitude!, member.longitude!), 16);
    });
  }

  void _focusPing(ActivePing ping) {
    final latitude = ping.latitude;
    final longitude = ping.longitude;
    if (latitude == null || longitude == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(LatLng(latitude, longitude), 15);
    });
  }

  @override
  void dispose() {
    _pingPulse.dispose();
    super.dispose();
  }

  Participant? get _currentMember {
    for (final member in widget.members) {
      if (member.id == widget.currentMemberId) return member;
    }
    return null;
  }

  Future<void> _centerOnMe() async {
    final member = _currentMember;
    if (member?.latitude == null || member?.longitude == null) {
      _centerWhenLocated = true;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Getting your location...')),
        );
      try {
        await widget.onRequestLocation();
      } catch (error) {
        if (mounted) {
          _centerWhenLocated = false;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('Could not get location: $error')),
            );
        }
      }
      return;
    }
    _mapController.move(LatLng(member!.latitude!, member.longitude!), 16);
  }

  Color _memberColor(Participant member, Map<String, Participant> officers) {
    if (member.isGeneral) return const Color(0xFFFF3B30);
    final hex = member.isOfficer
        ? member.color
        : officers[member.officerId]?.color;
    if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return const Color(0xFF8B9AAA);
    }
    return Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
  }

  String _pingInstruction(ActivePing ping) {
    final current = _currentMember;
    if (ping.targetMemberId != null) {
      if (ping.targetMemberId == widget.currentMemberId) {
        final sender = ping.senderRole == 'general'
            ? 'General'
            : ping.senderName;
        return ping.type == SafetyPing.meetup
            ? '$sender tells you to move here'
            : '$sender directs you: ${ping.type.label}';
      }
      final target = widget.members
          .where((member) => member.id == ping.targetMemberId)
          .firstOrNull;
      return 'Ping intended for ${target?.name ?? 'another officer'}';
    }
    if (ping.targetScope == 'officers') {
      return current?.isOfficer == true
          ? '${ping.senderName} · For fellow officers: ${ping.type.label}'
          : 'Ping intended for fellow officers';
    }
    if (ping.targetScope == 'soldiers') {
      final isMySquad =
          current?.isSoldier == true && current?.officerId == ping.senderId;
      return isMySquad
          ? '${ping.senderName} · Your squad: ${ping.type.label}'
          : 'Ping intended for another squad';
    }
    return '${ping.senderName} · ${ping.type.label}';
  }

  bool _isPingForCurrentMember(ActivePing ping) {
    final current = _currentMember;
    if (ping.targetMemberId != null) {
      return ping.targetMemberId == widget.currentMemberId;
    }
    if (ping.targetScope == 'officers') return current?.isOfficer == true;
    if (ping.targetScope == 'soldiers') {
      return current?.isSoldier == true && current?.officerId == ping.senderId;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentMember;
    Participant? locatedMember;
    for (final member in widget.members) {
      if (member.latitude != null && member.longitude != null) {
        locatedMember = member;
        break;
      }
    }
    final hasCurrentLocation =
        current?.latitude != null && current?.longitude != null;
    final ping = widget.activePing;
    final initialCenter = ping?.latitude != null && ping?.longitude != null
        ? LatLng(ping!.latitude!, ping.longitude!)
        : hasCurrentLocation
        ? LatLng(current!.latitude!, current.longitude!)
        : locatedMember == null
        ? const LatLng(20, 0)
        : LatLng(locatedMember.latitude!, locatedMember.longitude!);
    final officers = {
      for (final member in widget.members)
        if (member.isOfficer) member.id: member,
    };
    final markers = widget.members
        .where(
          (member) =>
              !member.isGeneral &&
              member.latitude != null &&
              member.longitude != null,
        )
        .map(
          (member) => Marker(
            point: LatLng(member.latitude!, member.longitude!),
            width: 116,
            height: 58,
            alignment: Alignment.topCenter,
            child: InkWell(
              onTap: () => _showMemberActions(member),
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _memberColor(member, officers),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                    child: Icon(
                      member.isOfficer
                          ? Icons.shield_rounded
                          : Icons.person_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 110),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xEE121B26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
    if (ping?.latitude != null && ping?.longitude != null) {
      markers.add(
        Marker(
          point: LatLng(ping!.latitude!, ping.longitude!),
          width: 120,
          height: 72,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ping.type.color.withValues(alpha: .22),
                  shape: BoxShape.circle,
                  border: Border.all(color: ping.type.color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: ping.type.color.withValues(alpha: .55),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(ping.type.icon, color: ping.type.color, size: 22),
              ),
              const SizedBox(height: 3),
              Container(
                constraints: const BoxConstraints(maxWidth: 116),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xF2121B26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ping.type.color.withValues(alpha: .8),
                  ),
                ),
                child: Text(
                  'Ping: ${ping.type.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ping.type.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: ping?.latitude != null && ping?.longitude != null
                    ? 15
                    : hasCurrentLocation
                    ? 15
                    : locatedMember == null
                    ? 2
                    : 12,
                minZoom: 2,
                maxZoom: 18,
                onLongPress: (_, point) => _showPingMenu(context, point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'project_genz',
                ),
                MarkerLayer(markers: markers),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xF2121B26),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_rounded,
                        size: 19,
                        color: Color(0xFF9BE3C0),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.groupName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.connectionError ??
                                  (widget.groupId == null
                                      ? 'No group connected'
                                      : '${widget.members.length} members · ${widget.members.where((member) => member.online).length} online'),
                              style: const TextStyle(
                                color: Color(0xFF8B9AAA),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: Color(0xFF9BE3C0),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Share location with group',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Switch.adaptive(
                        value: widget.isSharingLocation,
                        onChanged: widget.groupId == null
                            ? null
                            : widget.onLocationSharingChanged,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF2121B26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        widget.activePing?.type.color ??
                        const Color(0xFF9BE3C0),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  widget.activePing == null
                      ? 'Kein aktiver Ping'
                      : 'Roger: ${widget.activePing!.acknowledgedCount} / ${widget.activePing!.memberCount} Personen',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: widget.activePing == null ? 42 : 148,
            child: FloatingActionButton.small(
              heroTag: 'center-map-on-me',
              tooltip: 'Get location and center map',
              onPressed: () => _centerOnMe(),
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          if (widget.activePing != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pingPulse,
                  builder: (context, _) => CustomPaint(
                    painter: _PingEdgePainter(
                      color: widget.activePing!.type.color,
                      strength: _pingPulse.value,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          if (widget.activePing != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF2121B26),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: widget.activePing!.type.color.withValues(
                      alpha: widget.activePing!.isNew ? .72 : .4,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.activePing!.type.color.withValues(
                        alpha: .12,
                      ),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.activePing!.type.icon,
                      color: widget.activePing!.type.color,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _pingInstruction(widget.activePing!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.activePing!.isNew ? 'NEW' : 'ACTIVE',
                                style: TextStyle(
                                  color: widget.activePing!.type.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.activePing!.ageLabel} · Bestätigt ${widget.activePing!.acknowledgedCount}/${widget.activePing!.memberCount}',
                            style: const TextStyle(
                              color: Color(0xFFB1BDCA),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: widget.activePing!.memberCount == 0
                                ? 0
                                : (widget.activePing!.acknowledgedCount /
                                          widget.activePing!.memberCount)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                            minHeight: 3,
                            color: widget.activePing!.type.color,
                            backgroundColor: Colors.white.withValues(
                              alpha: .12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 9),
                    FilledButton.tonal(
                      onPressed: _isPingForCurrentMember(widget.activePing!)
                          ? widget.onAcknowledge
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(62, 40),
                      ),
                      child: Text(
                        _isPingForCurrentMember(widget.activePing!)
                            ? 'Roger'
                            : 'Not for me',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPingMenu(BuildContext context, LatLng point) {
    final current = _currentMember;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PingPicker(
        point: point,
        isGeneral: current?.isGeneral ?? false,
        isOfficer: current?.isOfficer ?? false,
        officers: widget.members.where((member) => member.isOfficer).toList(),
        onSelected: widget.onPingSelected,
      ),
    );
  }

  void _showMemberActions(Participant member) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                member.isOfficer ? Icons.shield_rounded : Icons.person_rounded,
              ),
              title: Text(member.name),
              subtitle: Text(member.isOfficer ? 'Officer' : 'Soldier'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_rounded),
              title: const Text('Send a direct message'),
              onTap: () {
                Navigator.pop(context);
                widget.onMessageMember(member);
              },
            ),
            if (widget.currentIsGeneral && member.isSoldier)
              ListTile(
                leading: const Icon(Icons.military_tech_rounded),
                title: const Text('Promote to officer'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onPromoteMember(member);
                },
              ),
            if (widget.currentIsGeneral)
              ListTile(
                leading: const Icon(Icons.person_remove_rounded),
                title: const Text('Remove from group'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onKickMember(member);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PingPicker extends StatefulWidget {
  const _PingPicker({
    required this.point,
    required this.isGeneral,
    required this.isOfficer,
    required this.officers,
    required this.onSelected,
  });

  final LatLng point;
  final bool isGeneral;
  final bool isOfficer;
  final List<Participant> officers;
  final ValueChanged<PingSelection> onSelected;

  @override
  State<_PingPicker> createState() => _PingPickerState();
}

class _PingPickerState extends State<_PingPicker> {
  String _targetScope = 'officers';
  String _selectedOfficerId = '';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        decoration: BoxDecoration(
          color: const Color(0xFF121B26),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send a safety alert',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (widget.isGeneral) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedOfficerId,
                decoration: const InputDecoration(
                  labelText: 'Target officer (optional)',
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All members')),
                  for (final officer in widget.officers)
                    DropdownMenuItem(
                      value: officer.id,
                      child: Text(officer.name),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedOfficerId = value ?? ''),
              ),
            ] else if (widget.isOfficer) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Fellow officers'),
                    selected: _targetScope == 'officers',
                    onSelected: (_) =>
                        setState(() => _targetScope = 'officers'),
                  ),
                  ChoiceChip(
                    label: const Text('My soldiers'),
                    selected: _targetScope == 'soldiers',
                    onSelected: (_) =>
                        setState(() => _targetScope = 'soldiers'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final ping in SafetyPing.values)
                  SizedBox(
                    width: 102,
                    child: Material(
                      color: const Color(0xFF1A2634),
                      borderRadius: BorderRadius.circular(17),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(17),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onSelected(
                            PingSelection(
                              type: ping,
                              latitude: widget.point.latitude,
                              longitude: widget.point.longitude,
                              targetMemberId:
                                  widget.isGeneral &&
                                      _selectedOfficerId.isNotEmpty
                                  ? _selectedOfficerId
                                  : null,
                              targetScope: widget.isOfficer
                                  ? _targetScope
                                  : 'all',
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 5,
                          ),
                          child: Column(
                            children: [
                              Icon(ping.icon, color: ping.color, size: 25),
                              const SizedBox(height: 7),
                              Text(
                                ping.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PingEdgePainter extends CustomPainter {
  const _PingEdgePainter({required this.color, required this.strength});

  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(5),
      const Radius.circular(22),
    );
    final pulse = .35 + strength * .65;
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 + strength * 2
        ..color = color.withValues(alpha: .35 + pulse * .3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 + strength * 7),
    );
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: .55 + pulse * .35),
    );
  }

  @override
  bool shouldRepaint(covariant _PingEdgePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strength != strength;
}
