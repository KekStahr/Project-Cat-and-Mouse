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
  final ValueChanged<SafetyPing> onPingSelected;
  final VoidCallback onAcknowledge;
  final bool currentIsGeneral;
  final ValueChanged<Participant> onPromoteMember;
  final ValueChanged<Participant> onKickMember;
  final ValueChanged<Participant> onMessageMember;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  bool _centerWhenLocated = false;

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_centerWhenLocated) return;
    final member = _currentMember;
    if (member?.latitude == null || member?.longitude == null) return;
    _centerWhenLocated = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(LatLng(member!.latitude!, member.longitude!), 16);
    });
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
    final initialCenter = hasCurrentLocation
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: hasCurrentLocation
                    ? 15
                    : locatedMember == null
                    ? 2
                    : 12,
                minZoom: 2,
                maxZoom: 18,
                onLongPress: (_, _) => _showPingMenu(context),
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: widget.activePing!.type.color.withValues(
                        alpha: widget.activePing!.isNew ? .58 : .3,
                      ),
                      width: widget.activePing!.isNew ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.activePing!.type.color.withValues(
                          alpha: .12,
                        ),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ],
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
                                  '${widget.activePing!.senderName} · ${widget.activePing!.type.label}',
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
                      onPressed: widget.onAcknowledge,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(62, 40),
                      ),
                      child: const Text('Roger'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPingMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PingPicker(onSelected: widget.onPingSelected),
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

class _PingPicker extends StatelessWidget {
  const _PingPicker({required this.onSelected});
  final ValueChanged<SafetyPing> onSelected;

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
                          onSelected(ping);
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
