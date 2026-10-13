import 'package:flutter/material.dart';
import 'main.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required this.groupName,
    required this.connectionError,
    required this.groupId,
    required this.participantCount,
    required this.onlineCount,
    required this.activePing,
    required this.onPingSelected,
  });

  final String groupName;
  final String? connectionError;
  final String? groupId;
  final int participantCount;
  final int onlineCount;
  final SafetyPing? activePing;
  final ValueChanged<SafetyPing> onPingSelected;

  void _showPingMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PingPicker(onSelected: onPingSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: InteractiveViewer(
                minScale: .75,
                maxScale: 3,
                child: CustomPaint(
                  painter: _MapPainter(),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                ),
              ),
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
            top: 15,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121B26).withValues(alpha: .95),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  const Icon(Icons.groups_rounded, size: 19, color: Color(0xFF9BE3C0)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(groupName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          connectionError ?? (groupId == null ? 'Keine Gruppe verbunden' : '$participantCount Personen · $onlineCount online'),
                          style: const TextStyle(color: Color(0xFF8B9AAA), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sos_rounded, color: Color(0xFFFF3B30)),
                    tooltip: 'SOS Notruf',
                    onPressed: () => onPingSelected(SafetyPing.sos),
                  ),
                ],
              ),
            ),
          ),
          if (activePing != null)
            Positioned(
              top: 78,
              left: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121B26),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: activePing!.color.withValues(alpha: .5)),
                ),
                child: Row(
                  children: [
                    Icon(activePing!.icon, color: activePing!.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${activePing!.label} · Bitte in „Personen“ bestätigen',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
}

class _PingPicker extends StatelessWidget {
  const _PingPicker({required this.onSelected});
  final ValueChanged<SafetyPing> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
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
          const Text('Sicherheitsmeldung senden', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
                        child: Column(
                          children: [
                            Icon(ping.icon, color: ping.color, size: 25),
                            const SizedBox(height: 7),
                            Text(ping.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF17232A), BlendMode.src);
    final park = Paint()..color = const Color(0xFF1D332F);
    canvas.drawOval(Rect.fromLTWH(size.width * .52, size.height * .36, size.width * .65, size.height * .74), park);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}