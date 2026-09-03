import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inditrans/inditrans.dart' as inditrans;
import 'core/services/supabase_client.dart';
import 'core/services/update_service.dart';
import 'core/theme/theme.dart';
import 'core/navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseClientService.initialize();

  // Initialize the downloader used for in-app update APKs (plan §O/§8)
  await FlutterDownloader.initialize();
  // Registers the background-isolate status/progress callback so a
  // failed/canceled download can actually be detected and surfaced
  // in-app instead of silently going nowhere.
  UpdateService.initDownloadListener();

  // Initialize Devanagari<->Latin romanization for cross-script search
  // matching (plan §E). Fails open — search_match.dart falls back to
  // returning text unromanized if this didn't succeed, rather than
  // crashing the app over a missing search enhancement.
  try {
    await inditrans.init();
  } catch (e) {
    print('inditrans init failed (cross-script search will be degraded): $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'बही',
      theme: AppTheme.lightTheme(),
      debugShowCheckedModeBanner: false,
      home: const AppRouter(),
    );
  }
}
