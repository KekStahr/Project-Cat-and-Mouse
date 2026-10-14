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
    required this.activePing,
    required this.onPingSelected,
  });

  final String groupName;
  final String? connectionError;
  final String? groupId;
  final List<Participant> members;
  final String? currentMemberId;
  final bool isSharingLocation;
  final ValueChanged<bool> onLocationSharingChanged;
  final SafetyPing? activePing;
  final ValueChanged<SafetyPing> onPingSelected;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();

  Participant? get _currentMember {
    for (final member in widget.members) {
      if (member.id == widget.currentMemberId) return member;
    }
    return null;
  }

  void _centerOnMe() {
    final member = _currentMember;
    if (member?.latitude == null || member?.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dein Standort ist noch nicht verfügbar.'),
        ),
      );
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
        .where((member) => member.latitude != null && member.longitude != null)
        .map(
          (member) => Marker(
            point: LatLng(member.latitude!, member.longitude!),
            width: 130,
            height: 64,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 126),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEE121B26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
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
                    member.isGeneral
                        ? Icons.star_rounded
                        : member.isOfficer
                        ? Icons.shield_rounded
                        : Icons.person_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ],
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
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: () => _showPingMenu(context),
              child: const SizedBox.expand(),
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
                                      ? 'Keine Gruppe verbunden'
                                      : '${widget.members.length} Personen · ${widget.members.where((member) => member.online).length} online'),
                              style: const TextStyle(
                                color: Color(0xFF8B9AAA),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.sos_rounded,
                          color: Color(0xFFFF3B30),
                        ),
                        tooltip: 'SOS Notruf',
                        onPressed: () => widget.onPingSelected(SafetyPing.sos),
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
                          'Standort mit Gruppe teilen',
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
            bottom: widget.activePing == null ? 42 : 100,
            child: FloatingActionButton.small(
              heroTag: 'center-map-on-me',
              tooltip: 'Auf meinen Standort zentrieren',
              onPressed: _centerOnMe,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          if (widget.activePing != null)
            Positioned(
              left: 12,
              right: 62,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xF2121B26),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: widget.activePing!.color.withValues(alpha: .5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.activePing!.icon,
                      color: widget.activePing!.color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.activePing!.label} · Bitte in „Personen“ bestätigen',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

  void _showPingMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PingPicker(onSelected: widget.onPingSelected),
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
              'Sicherheitsmeldung senden',
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
              child: const Text('Schließen'),
            ),
          ],
        ),
      ),
    ),
  );
}
