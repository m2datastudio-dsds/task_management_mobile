import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:task_mobile/main.dart';

void main() {
  testWidgets('shows login screen when signed out', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TaskMobileApp());
    await tester.pumpAndSettle();

    expect(find.text('Task Management'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
