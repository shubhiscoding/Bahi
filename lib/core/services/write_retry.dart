import 'dart:math';

import 'package:dio/dio.dart';

import '../constants/strings.dart';

/// Header the backend uses to make a retried write idempotent. Every attempt
/// of one save sends the same key, so the server applies the write once.
const idempotencyKeyHeader = 'Idempotency-Key';

/// Total attempts for a write (first try + retries). A save that still
/// times out after the last attempt surfaces as [SlowNetworkException].
const writeMaxAttempts = 3;

/// Thrown when every attempt of a write timed out or lost its connection.
class SlowNetworkException implements Exception {
  final Object lastError;
  const SlowNetworkException(this.lastError);

  @override
  String toString() => 'SlowNetworkException: $lastError';
}

/// True for failures caused by the network being slow or unreachable, the
/// only failures worth retrying. HTTP errors (400, 403, 500...) and bugs are
/// not retried: the server answered, or the request itself is wrong.
bool isNetworkTimeout(Object error) {
  if (error is! DioException) return false;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
      return true;
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return false;
  }
}

/// Retries [attempt] on network timeouts, with 1s then 2s between tries.
///
/// Callers keep their saving loader up for the whole duration. Non-network
/// errors are rethrown immediately. [wait] is injectable so tests don't sleep.
Future<T> retryOnNetworkTimeout<T>(
  Future<T> Function() attempt, {
  Future<void> Function(Duration)? wait,
}) async {
  final sleep = wait ?? (d) => Future<void>.delayed(d);
  for (var n = 1;; n++) {
    try {
      return await attempt();
    } catch (e) {
      if (!isNetworkTimeout(e)) rethrow;
      if (n >= writeMaxAttempts) throw SlowNetworkException(e);
      await sleep(Duration(seconds: n));
    }
  }
}

/// A fresh 128-bit random key as 32 hex chars. Matches the backend's
/// accepted Idempotency-Key format ([A-Za-z0-9_-], max 128).
String newIdempotencyKey() {
  final rnd = Random.secure();
  return List<int>.generate(16, (_) => rnd.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// User-facing text for a failed save. Slow-network failures get the
/// dedicated message; everything else keeps the generic error prefix.
String saveErrorMessage(Object error) {
  if (error is SlowNetworkException) return Strings.slowNetwork;
  return 'त्रुटि: $error';
}
