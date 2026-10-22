import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventoryapp/app/presentation/app_shell.dart';

void main() {
  testWidgets('App starts on the dashboard', (WidgetTester tester) async {
    // AppShell is designed for a desktop window, so give it a desktop-sized
    // viewport instead of the small default widget-test viewport.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Admin'), findsOneWidget);

    // Drift delays closing cancelled query streams briefly. Dispose the app
    // and advance fake time so that cleanup finishes before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
