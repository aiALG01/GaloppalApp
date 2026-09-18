import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads `.env` (see `.env.example`) and initializes the Supabase client.
/// Call once from `main()` before `runApp`.
Future<void> initSupabase() async {
  await dotenv.load(fileName: '.env');

  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL / SUPABASE_ANON_KEY missing. Copy .env.example to .env '
      'and fill in your Supabase project credentials.',
    );
  }

  await Supabase.initialize(url: url, publishableKey: anonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
