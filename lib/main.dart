import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    // ProviderScope is required at the root â€” it holds all Riverpod providers.
    const ProviderScope(child: TakaIdApp()),
  );
}

class TakaIdApp extends StatelessWidget {
  const TakaIdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TakaID',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006A4E), // Bangladesh green
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(surfaceTintColor: Colors.transparent),
      ),
      home: const HomeScreen(),
    );
  }
}
