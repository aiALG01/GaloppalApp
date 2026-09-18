// Basic smoke test: the auth screen renders without needing a live Supabase
// connection (AppState is constructed directly, init() is never called).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:galoppal/screens/auth_screen.dart';
import 'package:galoppal/state/app_state.dart';

void main() {
  testWidgets('Auth screen shows the welcome headline', (WidgetTester tester) async {
    final appState = AppState()..isLoading = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.textContaining('Willkommen'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
  });
}
