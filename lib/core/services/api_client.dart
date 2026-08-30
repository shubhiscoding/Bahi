import 'package:dio/dio.dart';
import '../config/backend_config.dart';
import 'supabase_client.dart';

/// HTTP client for the Node/Express backend. Every request is
/// automatically stamped with the current Supabase session's access
/// token as a Bearer token — the backend verifies this via JWKS
/// (see backend/src/jwtVerify.ts).
class ApiClient {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: backendBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = SupabaseClientService.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

  static Dio get instance => _dio;
}
