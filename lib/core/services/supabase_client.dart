import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Singleton Supabase client
class SupabaseClientService {
  static late Supabase _instance;

  /// Initialize Supabase (call once at app startup)
  static Future<void> initialize() async {
    _instance = await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  /// Get the Supabase client instance
  static SupabaseClient get client => _instance.client;

  /// Get auth client
  static dynamic get auth => client.auth;

  /// Get realtime client
  static dynamic get realtime => client.realtime;
}
