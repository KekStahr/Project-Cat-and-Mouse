import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Invitation link or token'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
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
