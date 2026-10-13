import 'package:flutter_test/flutter_test.dart';
import 'package:project_genz/main.dart';

void main() {
  testWidgets('shows the group map and navigation', (tester) async {
    await tester.pumpWidget(const ResoApp());

    expect(find.text('Reşo'), findsOneWidget);
    expect(find.text('Alpenrunde'), findsOneWidget);
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

  testWidgets('creates a group invitation with an expiry', (tester) async {
    await tester.pumpWidget(const ResoApp());

    await tester.tap(find.byTooltip('Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppe erstellen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();

    expect(find.text('Einladung ist bereit'), findsOneWidget);
    expect(find.text('Gültig: 1 Stunde'), findsOneWidget);
    expect(
      find.text('Demo-Code: Er funktioniert nur in dieser lokalen Vorschau.'),
      findsOneWidget,
    );
  });

  testWidgets('sends a safety ping and allows its acknowledgement', (
    tester,
  ) async {
    await tester.pumpWidget(const ResoApp());

    await tester.longPressAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hilfe benötigt'));
    await tester.pumpAndSettle();

    expect(find.text('3 Bestätigungen ausstehend'), findsOneWidget);
    expect(find.text('Bestätigen'), findsNWidgets(3));
    await tester.tap(find.text('Bestätigen').first);
    await tester.pumpAndSettle();
    expect(find.text('2 Bestätigungen ausstehend'), findsOneWidget);
  });
}
