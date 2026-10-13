import 'dart:math';

import 'package:flutter/material.dart';

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
  );

  const SafetyPing(this.label, this.description, this.icon, this.color);
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class Participant {
  Participant(this.name, {this.online = true, this.organizer = false});
  final String name;
  final bool online;
  final bool organizer;
  bool acknowledged = true;
}

class GroupHomePage extends StatefulWidget {
  const GroupHomePage({super.key});

  @override
  State<GroupHomePage> createState() => _GroupHomePageState();
}

class _GroupHomePageState extends State<GroupHomePage> {
  final _random = Random.secure();
  final _nameController = TextEditingController(text: 'Alex');
  final _joinController = TextEditingController();
  final _chatController = TextEditingController();
  final _searchController = TextEditingController();
  final _participants = <Participant>[
    Participant('Alex', organizer: true),
    Participant('Mira'),
    Participant('Jonas', online: false),
    Participant('Sam'),
  ];
  final _messages = <(String, String, bool)>[
    ('Mira', 'Bin in 5 Minuten am Treffpunkt.', false),
    ('Alex', 'Alles klar, wir warten dort.', true),
  ];

  String _groupName = 'Alpenrunde';
  String? _inviteCode;
  DateTime? _inviteExpires;
  SafetyPing? _activePing;
  int _selectedTab = 0;
  int _pingSerial = 0;
  String _expiryChoice = '1 Stunde';

  @override
  void dispose() {
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
                if (name.isEmpty ||
                    (expiry == 'Individuell' &&
                        (customHours == null ||
                            customHours < 1 ||
                            customHours > 168))) {
                  return;
                }
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
    final code = List.generate(6, (_) => _random.nextInt(10)).join();
    setState(() {
      _groupName = result.$1;
      _expiryChoice = result.$2;
      _inviteCode = code;
      _inviteExpires = DateTime.now().add(durations[result.$2]!);
    });
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.link_rounded, color: _mint, size: 34),
        title: const Text('Einladung ist bereit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Teile diesen Code für „${result.$1}“:'),
            const SizedBox(height: 14),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 7,
                color: _mint,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Gültig: ${result.$2 == 'Individuell' ? '${result.$3} Stunden' : result.$2}',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 6),
            const Text(
              'Demo-Code: Er funktioniert nur in dieser lokalen Vorschau.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12),
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
        title: const Text('Gruppe finden'),
        content: TextField(
          controller: _joinController,
          autofocus: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Einladungscode',
            hintText: '6-stelliger Code',
          ),
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
    if (_inviteCode != null &&
        DateTime.now().isBefore(_inviteExpires!) &&
        code == _inviteCode) {
      setState(() {
        if (!_participants.any(
          (member) => member.name == _nameController.text,
        )) {
          _participants.add(Participant(_nameController.text));
        }
      });
      _showNotice('Du bist „$_groupName“ beigetreten.');
    } else {
      _showNotice(
        'Code ungültig oder abgelaufen. Demo: Erstelle zuerst eine Gruppe.',
      );
    }
  }

  Future<void> _editProfile() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anzeigename'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: 'Dein Name in der Gruppe',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _nameController.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (!mounted || result == null || result.isEmpty) return;
    setState(() {
      final current = _participants.indexWhere((member) => member.organizer);
      if (current >= 0) {
        _participants[current] = Participant(result, organizer: true);
      }
    });
    _showNotice('Anzeigename gespeichert.');
  }

  void _setPing(SafetyPing ping) {
    setState(() {
      _activePing = ping;
      _pingSerial++;
      for (final participant in _participants) {
        participant.acknowledged = participant.organizer;
      }
      _selectedTab = 2;
    });
    _showNotice(
      'Meldung „${ping.label}“ gesendet. Teilnehmer bitte bestätigen.',
    );
  }

  Future<void> _showPingMenu() async {
    final ping = await showModalBottomSheet<SafetyPing>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _PingPicker(),
    );
    if (ping != null) _setPing(ping);
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add((_nameController.text, text, true));
      _chatController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [_mapScreen(), _chatScreen(), _peopleScreen()],
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
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.lock_outline_rounded, size: 17, color: _mint),
          ),
        PopupMenuButton<String>(
          tooltip: 'Menü',
          icon: const Icon(Icons.menu_rounded),
          color: _surfaceRaised,
          onSelected: (value) {
            switch (value) {
              case 'create':
                _createGroup();
              case 'join':
                _joinGroup();
              case 'profile':
                _editProfile();
              case 'invite':
                if (_inviteCode != null) {
                  _showNotice('Einladungscode: $_inviteCode');
                } else {
                  _showNotice('Erstelle zuerst eine Gruppe.');
                }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'create',
              child: _MenuLabel(Icons.add_circle_outline, 'Gruppe erstellen'),
            ),
            PopupMenuItem(
              value: 'join',
              child: _MenuLabel(Icons.group_add_outlined, 'Gruppe finden'),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'invite',
              child: _MenuLabel(Icons.link, 'Einladungscode'),
            ),
            PopupMenuItem(
              value: 'profile',
              child: _MenuLabel(Icons.person_outline, 'Einstellungen & Name'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _mapScreen() => LayoutBuilder(
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
                  child: _mapPins(),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: _showPingMenu,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(top: 15, left: 15, right: 15, child: _groupBadge()),
        Positioned(left: 16, bottom: 17, child: _mapLegend()),
        Positioned(right: 16, bottom: 17, child: _locationButton()),
        if (_activePing != null)
          Positioned(top: 78, left: 15, right: 15, child: _activePingBanner()),
        Positioned(
          bottom: 88,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _background.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    'Gedrückt halten für Sicherheitsmeldung',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _mapPins() => Stack(
    children: [
      const Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
        child: IgnorePointer(child: SizedBox.expand()),
      ),
      _pin(.25, .43, Icons.person_pin_circle_rounded, _mint, 'Alex'),
      _pin(
        .60,
        .31,
        Icons.person_pin_circle_rounded,
        const Color(0xFFFFC46B),
        'Mira',
      ),
      _pin(
        .72,
        .66,
        Icons.person_pin_circle_rounded,
        const Color(0xFF82C8FF),
        'Sam',
      ),
      if (_activePing != null)
        _pin(
          .43,
          .63,
          _activePing!.icon,
          _activePing!.color,
          _activePing!.label,
          large: true,
        ),
    ],
  );

  Widget _pin(
    double x,
    double y,
    IconData icon,
    Color color,
    String label, {
    bool large = false,
  }) => Positioned(
    left: MediaQuery.sizeOf(context).width * x - 20,
    top: MediaQuery.sizeOf(context).height * y * .55,
    child: Column(
      children: [
        Container(
          padding: EdgeInsets.all(large ? 11 : 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .2),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: .65)),
          ),
          child: Icon(icon, color: color, size: large ? 25 : 21),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _groupBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _surface.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: Colors.white.withValues(alpha: .06)),
    ),
    child: Row(
      children: [
        const Icon(Icons.groups_rounded, size: 19, color: _mint),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _groupName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${_participants.length} Personen · ${_participants.where((p) => p.online).length} online',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const Icon(Icons.my_location_rounded, size: 17, color: _muted),
      ],
    ),
  );

  Widget _mapLegend() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: _surface.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.circle, size: 8, color: _mint),
        SizedBox(width: 6),
        Text('Deine Gruppe', style: TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _locationButton() => Material(
    color: _surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showNotice('Standortfreigabe ist in der Demo deaktiviert.'),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.my_location_rounded, color: _mint),
      ),
    ),
  );

  Widget _activePingBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _activePing!.color.withValues(alpha: .5)),
    ),
    child: Row(
      children: [
        Icon(_activePing!.icon, color: _activePing!.color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${_activePing!.label} · Bitte in „Personen“ bestätigen',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '$_pingSerial',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _chatScreen() => Column(
    children: [
      _sectionHeader('Gruppenchat', 'Nachrichten für alle in der Gruppe'),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final message = _messages[index];
            return Align(
              alignment: message.$3
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: message.$3 ? const Color(0xFF203B33) : _surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.$1,
                      style: const TextStyle(color: _mint, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(message.$2),
                  ],
                ),
              ),
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
                controller: _chatController,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Nachricht schreiben …',
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _peopleScreen() {
    final query = _searchController.text.toLowerCase();
    final visible =
        _participants.where((member) {
          final matchesName = member.name.toLowerCase().contains(query);
          return matchesName &&
              (member.organizer || member.acknowledged || _activePing != null);
        }).toList()..sort((a, b) {
          final aPending = _activePing != null && !a.acknowledged;
          final bPending = _activePing != null && !b.acknowledged;
          if (aPending != bPending) return aPending ? -1 : 1;
          return a.name.compareTo(b.name);
        });
    final pendingCount = _participants
        .where((member) => !member.organizer && !member.acknowledged)
        .length;
    return Column(
      children: [
        _sectionHeader('Personen', '${_participants.length} in der Gruppe'),
        if (_activePing != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _activePing!.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(_activePing!.icon, color: _activePing!.color, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    pendingCount == 0
                        ? 'Alle haben „${_activePing!.label}“ bestätigt'
                        : '$pendingCount Bestätigung${pendingCount == 1 ? '' : 'en'} ausstehend',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Person suchen',
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
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
              final awaiting =
                  _activePing != null &&
                  !member.organizer &&
                  !member.acknowledged;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: awaiting ? const Color(0xFF351F24) : _surface,
                  borderRadius: BorderRadius.circular(15),
                  border: awaiting
                      ? Border.all(
                          color: const Color(0xFFFF7979).withValues(alpha: .45),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: member.organizer
                          ? _mint.withValues(alpha: .16)
                          : _surfaceRaised,
                      child: Text(
                        member.name.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: member.organizer ? _mint : Colors.white,
                        ),
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
                            member.organizer
                                ? 'Organisiert die Gruppe'
                                : member.online
                                ? 'Online'
                                : 'Zuletzt nicht online',
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (awaiting)
                      FilledButton.tonal(
                        onPressed: () =>
                            setState(() => member.acknowledged = true),
                        child: const Text('Bestätigen'),
                      )
                    else if (_activePing != null && !member.organizer)
                      const Icon(Icons.check_circle, color: _mint, size: 19)
                    else
                      Icon(
                        Icons.circle,
                        size: 9,
                        color: member.online ? _mint : _muted,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
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

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19),
      const SizedBox(width: 12),
      Flexible(child: Text(label)),
    ],
  );
}

class _PingPicker extends StatelessWidget {
  const _PingPicker();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 4,
            decoration: BoxDecoration(
              color: _muted.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sicherheitsmeldung',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Wähle eine Meldung für die Gruppe',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final ping in SafetyPing.values)
                SizedBox(
                  width: 102,
                  child: Material(
                    color: _surfaceRaised,
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => Navigator.pop(context, ping),
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
              SizedBox(
                width: 102,
                child: Material(
                  color: const Color(0xFF342328),
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(17),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Icon(Icons.close_rounded, size: 25),
                          SizedBox(height: 7),
                          Text('Schließen', style: TextStyle(fontSize: 11)),
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
    final water = Paint()..color = const Color(0xFF18323C);
    final road = Paint()
      ..color = const Color(0xFF35434A)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final roadEdge = Paint()
      ..color = const Color(0xFF526067)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final minorRoad = Paint()
      ..color = const Color(0xFF29373D)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .52,
        size.height * .36,
        size.width * .65,
        size.height * .74,
      ),
      park,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * .16,
        size.height * .68,
        size.width * .45,
        size.height * .24,
      ),
      water,
    );
    final paths = <Path>[
      Path()
        ..moveTo(-20, size.height * .26)
        ..cubicTo(
          size.width * .23,
          size.height * .32,
          size.width * .54,
          size.height * .12,
          size.width + 30,
          size.height * .24,
        ),
      Path()
        ..moveTo(size.width * .20, -10)
        ..cubicTo(
          size.width * .28,
          size.height * .32,
          size.width * .48,
          size.height * .67,
          size.width * .39,
          size.height + 20,
        ),
      Path()
        ..moveTo(-20, size.height * .77)
        ..cubicTo(
          size.width * .30,
          size.height * .55,
          size.width * .66,
          size.height * .78,
          size.width + 20,
          size.height * .55,
        ),
      Path()
        ..moveTo(size.width * .71, -10)
        ..cubicTo(
          size.width * .53,
          size.height * .26,
          size.width * .80,
          size.height * .58,
          size.width * .63,
          size.height + 20,
        ),
    ];
    for (final path in paths) {
      canvas.drawPath(path, road);
      canvas.drawPath(path, roadEdge);
    }
    final minorPaths = <Path>[
      Path()
        ..moveTo(size.width * .06, size.height * .48)
        ..quadraticBezierTo(
          size.width * .48,
          size.height * .34,
          size.width * .92,
          size.height * .43,
        ),
      Path()
        ..moveTo(size.width * .12, size.height * .60)
        ..quadraticBezierTo(
          size.width * .55,
          size.height * .80,
          size.width * .90,
          size.height * .70,
        ),
      Path()
        ..moveTo(size.width * .48, size.height * .04)
        ..quadraticBezierTo(
          size.width * .36,
          size.height * .50,
          size.width * .52,
          size.height * .93,
        ),
    ];
    for (final path in minorPaths) {
      canvas.drawPath(path, minorRoad);
    }
    final dash = Paint()
      ..color = const Color(0xFF83949A).withValues(alpha: .32)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * .08, size.height * .88),
      Offset(size.width * .87, size.height * .10),
      dash,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
