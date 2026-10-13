import 'package:flutter_test/flutter_test.dart';
import 'package:project_genz/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the group map and navigation', (tester) async {
    await tester.pumpWidget(const ResoApp());
    await tester.pumpAndSettle();

    expect(find.text('Reşo'), findsOneWidget);
    expect(find.text('Keine Gruppe'), findsOneWidget);
    expect(find.text('Keine Gruppe verbunden'), findsOneWidget);
    expect(find.text('Karte'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Personen'), findsOneWidget);
  });

  testWidgets('opens the safety menu on a long press', (tester) async {
    await tester.pumpWidget(const ResoApp());

    await tester.longPressAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    expect(find.text('Sicherheitsmeldung'), findsOneWidget);
    expect(find.text('Treffpunkt'), findsOneWidget);
    expect(find.text('Hilfe benötigt'), findsOneWidget);
    expect(find.text('Schließen'), findsOneWidget);
  });

  testWidgets('opens the remote group creation dialog', (tester) async {
    await tester.pumpWidget(const ResoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppe erstellen'));
    await tester.pumpAndSettle();

    expect(find.text('Gruppe erstellen'), findsOneWidget);
    expect(find.text('Gruppenname'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
  });

  testWidgets('opens the remote group join dialog', (tester) async {
    await tester.pumpWidget(const ResoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppe finden'));
    await tester.pumpAndSettle();

    expect(find.text('Gruppe finden'), findsOneWidget);
    expect(find.text('Einladungscode'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
  });
}
