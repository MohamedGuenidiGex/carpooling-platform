// Flutter widget test for GExpertise Carpool
// Tests the main app widget renders correctly

import 'package:flutter_test/flutter_test.dart';

import 'package:gexpertise_carpool/app.dart';

void main() {
  testWidgets('App renders HomeScreen with title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GExpertiseCarpoolApp());

    // Verify that the HomeScreen renders with the expected title text.
    expect(find.text('GExpertise Carpool MVP'), findsOneWidget);
    expect(find.text('GExpertise Carpool'), findsOneWidget);
  });
}
