// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:early_warning_flood_system/app.dart';

void main() {
  testWidgets('shows an actionable Firebase setup state before configuration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FloodWatchApp(firebaseReady: false));

    expect(find.text('Firebase is not connected'), findsOneWidget);
    expect(find.text('flutterfire configure'), findsOneWidget);
  });
}
