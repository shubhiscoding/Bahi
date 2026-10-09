import 'dart:convert';
import 'dart:typed_data';

import 'package:bahi/core/services/api_client.dart';
import 'package:dio/dio.dart';

/// One scripted outcome for the next request: a JSON success, or a Dio error.
typedef Step = Object Function(RequestOptions options);

/// Replaces ApiClient's network layer with a queue of scripted outcomes, so
/// repository tests run the real Dio pipeline (headers, body, error mapping)
/// without a server. Each request consumes the next step; running out of
/// steps is a test bug and fails loudly.
class ScriptedAdapter implements HttpClientAdapter {
  final List<Step> _steps = [];
  final List<RequestOptions> requests = [];

  void enqueue(Step step) => _steps.add(step);

  /// Next attempt times out (the slow-internet case).
  void timeout([DioExceptionType type = DioExceptionType.receiveTimeout]) =>
      enqueue((o) => DioException(requestOptions: o, type: type));

  /// Next attempt succeeds with [status] and a JSON [body].
  void ok(Map<String, dynamic> body, {int status = 201}) => enqueue((_) => _json(body, status));

  /// Next attempt is an HTTP error (not retriable).
  void httpError(int status) => enqueue(
        (o) => DioException.badResponse(
          requestOptions: o,
          statusCode: status,
          response: Response(requestOptions: o, statusCode: status, data: {'error': 'X'}),
        ),
      );

  static ResponseBody _json(Map<String, dynamic> body, int status) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_steps.isEmpty) {
      throw StateError('ScriptedAdapter: no scripted step for ${options.method} ${options.path}');
    }
    final outcome = _steps.removeAt(0)(options);
    if (outcome is DioException) throw outcome;
    return outcome as ResponseBody;
  }

  @override
  void close({bool force = false}) {}
}

/// Installs a fresh [ScriptedAdapter] on the shared API client and strips the
/// Supabase auth interceptor (it needs a real Supabase session, which tests
/// don't have). Call from setUp.
ScriptedAdapter installScriptedApi() {
  ApiClient.instance.interceptors.clear();
  final adapter = ScriptedAdapter();
  ApiClient.instance.httpClientAdapter = adapter;
  return adapter;
}
