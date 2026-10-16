import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_genz/chat.dart';
import 'package:project_genz/map.dart';
import 'package:project_genz/main.dart';
import 'package:project_genz/people.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Participant testMember(
    String id,
    String name,
    String role, {
    String? officerId,
    String? color,
  }) => Participant(
    id: id,
    name: name,
    online: true,
    role: role,
    acknowledged: false,
    officerId: officerId,
    color: color,
    publicKey: null,
    latitude: null,
    longitude: null,
  );

  Widget pingMap({
    required List<Participant> members,
    required String currentMemberId,
    required ValueChanged<PingSelection> onPingSelected,
    ActivePing? activePing,
    bool canMoveActivePing = false,
    Future<void> Function(double latitude, double longitude)? onPingMoved,
  }) => MaterialApp(
    home: Scaffold(
      body: MapScreen(
        groupName: 'Test group',
        connectionError: null,
        groupId: 'group-1',
        members: members,
        currentMemberId: currentMemberId,
        isSharingLocation: false,
        onLocationSharingChanged: (_) {},
        onRequestLocation: () async {},
        activePing: activePing,
        canMoveActivePing: canMoveActivePing,
        onPingSelected: onPingSelected,
        onPingMoved: onPingMoved ?? (_, _) async {},
        onAcknowledge: () {},
        currentIsGeneral: false,
        onPromoteMember: (_) {},
        onKickMember: (_) {},
        onMessageMember: (_) {},
      ),
    ),
  );

  testWidgets('shows the group map and navigation', (tester) async {
    await tester.pumpWidget(const ResoApp());
    await tester.pumpAndSettle();

    expect(find.text('Reşo'), findsOneWidget);
    expect(find.text('No group'), findsOneWidget);
    expect(find.text('No group connected'), findsOneWidget);
    expect(find.text('Kein aktiver Ping'), findsOneWidget);
    expect(find.byTooltip('Emergency SOS'), findsNothing);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Share location with group'), findsOneWidget);
  });

  testWidgets('opens the safety menu on a long press', (tester) async {
    await tester.pumpWidget(const ResoApp());

    await tester.longPressAt(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Send a safety alert'), findsOneWidget);
    expect(find.text('Meetup'), findsOneWidget);
    expect(find.text('Help needed'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('General can target one officer with a ping', (tester) async {
    PingSelection? selection;
    await tester.pumpWidget(
      pingMap(
        members: [
          testMember('general-1', 'General', 'general'),
          testMember('officer-1', 'Officer Lee', 'officer'),
        ],
        currentMemberId: 'general-1',
        onPingSelected: (value) => selection = value,
      ),
    );
    await tester.longPressAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    expect(find.text('Target officer (optional)'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Officer Lee').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meetup'));
    await tester.pumpAndSettle();

    expect(selection?.targetMemberId, 'officer-1');
    expect(selection?.targetScope, 'all');
  });

  testWidgets('Officer can select only one recipient scope', (tester) async {
    PingSelection? selection;
    await tester.pumpWidget(
      pingMap(
        members: [
          testMember('officer-1', 'Officer Lee', 'officer'),
          testMember(
            'soldier-1',
            'Soldier Kim',
            'soldier',
            officerId: 'officer-1',
          ),
        ],
        currentMemberId: 'officer-1',
        onPingSelected: (value) => selection = value,
      ),
    );
    await tester.longPressAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    final fellowOfficers = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Fellow officers'),
    );
    expect(fellowOfficers.selected, isTrue);
    await tester.tap(find.text('My soldiers'));
    await tester.pumpAndSettle();
    final mySoldiers = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'My soldiers'),
    );
    expect(mySoldiers.selected, isTrue);
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Fellow officers'),
          )
          .selected,
      isFalse,
    );
    await tester.tap(find.text('Meetup'));
    await tester.pumpAndSettle();
    expect(selection?.targetScope, 'soldiers');
    expect(selection?.targetMemberId, isNull);
  });

  testWidgets('groups assigned soldiers under their officer', (tester) async {
    final searchController = TextEditingController();
    Participant? removedMember;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PeopleScreen(
            participants: [
              testMember(
                'officer-1',
                'Officer Lee',
                'officer',
                color: '#00AA88',
              ),
              testMember(
                'soldier-1',
                'Soldier Kim',
                'soldier',
                officerId: 'officer-1',
              ),
            ],
            hasActivePing: false,
            memberId: 'officer-1',
            searchController: searchController,
            onPromoteToOfficer: (_) {},
            onJoinOfficerGroup: (_) {},
            onKickMember: (member) => removedMember = member,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Officers (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Officer Lee Gruppe 1 (1)'), findsOneWidget);
    await tester.tap(find.text('Officer Lee Gruppe 1 (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Soldier Kim'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove member'));
    expect(removedMember?.id, 'soldier-1');
    searchController.dispose();
  });

  testWidgets('long press moves an owned ping inside its time window', (
    tester,
  ) async {
    double? movedLatitude;
    double? movedLongitude;
    await tester.pumpWidget(
      pingMap(
        members: [testMember('general-1', 'General', 'general')],
        currentMemberId: 'general-1',
        activePing: ActivePing(
          id: 'ping-1',
          type: SafetyPing.meetup,
          senderName: 'General',
          senderId: 'general-1',
          createdAt: DateTime.now().subtract(const Duration(seconds: 10)),
          acknowledgedCount: 0,
          memberCount: 2,
          latitude: 40.0,
          longitude: -74.0,
        ),
        canMoveActivePing: true,
        onPingSelected: (_) {},
        onPingMoved: (latitude, longitude) async {
          movedLatitude = latitude;
          movedLongitude = longitude;
        },
      ),
    );

    await tester.longPressAt(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(movedLatitude, isNotNull);
    expect(movedLongitude, isNotNull);
    expect(find.text('Send a safety alert'), findsNothing);
  });

  testWidgets('opens the remote group creation dialog', (tester) async {
    await tester.pumpWidget(const ResoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(find.text('Create group'), findsOneWidget);
    expect(find.text('Group name'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('opens the remote group join dialog', (tester) async {
    await tester.pumpWidget(const ResoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();

    expect(find.text('Join group'), findsOneWidget);
    expect(find.text('8-digit invitation code'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('suggests members and highlights received mentions', (
    tester,
  ) async {
    final controller = TextEditingController();
    final participant = Participant(
      id: 'mira-id',
      name: 'Mira',
      online: true,
      role: 'soldier',
      acknowledged: false,
      officerId: null,
      color: null,
      publicKey: null,
      latitude: null,
      longitude: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatScreen(
            messages: const [
              ChatMessage(
                id: 'message-1',
                senderName: 'Sam',
                text: '@Sam meet us there',
                mine: false,
                chatId: 'global',
              ),
            ],
            onSendMessage: (_) {},
            chatController: controller,
            rooms: const {'global': 'Global'},
            activeChatId: 'global',
            directChatLabel: null,
            onRoomSelected: (_) {},
            participants: [participant],
            currentMemberName: 'Sam',
          ),
        ),
      ),
    );

    final messageFinder = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText() == '@Sam meet us there',
    );
    final message = tester.widget<RichText>(messageFinder);
    final mention = (message.text as TextSpan).children!.first as TextSpan;
    expect(mention.text, '@Sam');
    expect(mention.style?.backgroundColor, isNotNull);

    await tester.enterText(find.byType(TextField), '@Mi');
    await tester.pumpAndSettle();
    expect(find.text('Mira'), findsOneWidget);
    await tester.tap(find.text('Mira'));
    await tester.pumpAndSettle();
    expect(controller.text, '@Mira ');
    controller.dispose();
  });

  testWidgets('shows a new map ping with confirmation progress and Roger', (
    tester,
  ) async {
    var acknowledgements = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapScreen(
            groupName: 'Weekend',
            connectionError: null,
            groupId: 'group-1',
            members: const [],
            currentMemberId: null,
            isSharingLocation: false,
            onLocationSharingChanged: (_) {},
            onRequestLocation: () async {},
            canMoveActivePing: false,
            activePing: ActivePing(
              id: 'ping-1',
              type: SafetyPing.meetup,
              senderName: 'Alex',
              createdAt: DateTime.now(),
              acknowledgedCount: 1,
              memberCount: 4,
              latitude: 40.7128,
              longitude: -74.006,
            ),
            onPingSelected: (_) {},
            onPingMoved: (_, _) async {},
            onAcknowledge: () => acknowledgements++,
            currentIsGeneral: false,
            onPromoteMember: (_) {},
            onKickMember: (_) {},
            onMessageMember: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Alex · Meetup'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('Roger: 1 / 4 Personen'), findsOneWidget);
    expect(find.text('Ping: Meetup'), findsOneWidget);
    expect(find.textContaining('Bestätigt 1/4'), findsOneWidget);
    await tester.tap(find.text('Roger'));
    expect(acknowledgements, 1);
  });

  testWidgets('shows separate Global and restricted unread badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChatUnreadIcon(
              icon: Icons.chat_rounded,
              globalUnread: 1,
              restrictedUnread: 5,
            ),
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byTooltip('Unread Global messages'), findsOneWidget);
    expect(find.byTooltip('Unread restricted messages'), findsOneWidget);
  });

  testWidgets('shows three expandable role lists with name search', (
    tester,
  ) async {
    await tester.pumpWidget(const ResoApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();

    expect(find.text('Search by name'), findsOneWidget);
    expect(find.text('General (0)'), findsOneWidget);
    expect(find.text('Officers (0)'), findsOneWidget);
    expect(find.text('Soldiers (0)'), findsOneWidget);

    await tester.tap(find.text('Soldiers (0)'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(3));
  });
}
