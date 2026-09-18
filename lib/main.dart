import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/root_screen.dart';
import 'services/supabase_client.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();

  final appState = AppState()..init();
  _wireIncomingTrainerLinks(appState);

  runApp(GaloppalApp(appState: appState));
}

/// Trainer invite links open as `https://galoppal.de/t/<code>` (Universal
/// Link on iOS / App Link on Android — see ios/Runner/Runner.entitlements
/// and the intent-filter in AndroidManifest.xml). Both a cold start from a
/// link and one tapped while the app is already running land here.
void _wireIncomingTrainerLinks(AppState appState) {
  final appLinks = AppLinks();

  void handle(Uri? uri) {
    if (uri == null) return;
    final segments = uri.pathSegments;
    final tIndex = segments.indexOf('t');
    if (tIndex == -1 || tIndex + 1 >= segments.length) return;
    appState.handleIncomingInviteCode(segments[tIndex + 1]);
  }

  appLinks.getInitialLink().then(handle);
  appLinks.uriLinkStream.listen(handle);
}

class GaloppalApp extends StatelessWidget {
  const GaloppalApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'Galoppal',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // German locale so native pickers (date, time) start the week on
        // Monday and use German labels/month names.
        locale: const Locale('de', 'DE'),
        supportedLocales: const [Locale('de', 'DE')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const RootScreen(),
      ),
    );
  }
}
