import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_genz/chat.dart';
import 'package:project_genz/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the group map and navigation', (tester) async {
    await tester.pumpWidget(const ResoApp());
    await tester.pumpAndSettle();

    expect(find.text('Reşo'), findsOneWidget);
    expect(find.text('No group'), findsOneWidget);
    expect(find.text('No group connected'), findsOneWidget);
    expect(find.byTooltip('Emergency SOS'), findsNothing);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Share location with group'), findsOneWidget);
  });

  testWidgets('opens the safety menu on a long press', (tester) async {
    await tester.pumpWidget(const ResoApp());

    await tester.longPressAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    expect(find.text('Send a safety alert'), findsOneWidget);
    expect(find.text('Meetup'), findsOneWidget);
    expect(find.text('Help needed'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
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
