import 'package:bahi/core/constants/strings.dart';
import 'package:bahi/core/services/write_retry.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio(DioExceptionType type, {int? status}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status),
  );
}

void main() {
  group('isNetworkTimeout', () {
    test('timeouts and connection errors are retriable', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(isNetworkTimeout(_dio(type)), isTrue, reason: '$type should retry');
      }
    });

    test('HTTP errors, cancels and unknown Dio errors are not retriable', () {
      expect(isNetworkTimeout(_dio(DioExceptionType.badResponse, status: 500)), isFalse);
      expect(isNetworkTimeout(_dio(DioExceptionType.badResponse, status: 400)), isFalse);
      expect(isNetworkTimeout(_dio(DioExceptionType.cancel)), isFalse);
      expect(isNetworkTimeout(_dio(DioExceptionType.badCertificate)), isFalse);
      expect(isNetworkTimeout(_dio(DioExceptionType.unknown)), isFalse);
    });

    test('non-Dio errors are not retriable', () {
      expect(isNetworkTimeout(StateError('bug')), isFalse);
      expect(isNetworkTimeout(Exception('x')), isFalse);
    });
  });

  group('retryOnNetworkTimeout', () {
    late List<Duration> waits;
    Future<void> recordWait(Duration d) async => waits.add(d);

    setUp(() => waits = []);

    test('success on first attempt: one call, no waiting', () async {
      var calls = 0;
      final result = await retryOnNetworkTimeout(() async {
        calls++;
        return 'ok';
      }, wait: recordWait);

      expect(result, 'ok');
      expect(calls, 1);
      expect(waits, isEmpty);
    });

    test('one timeout then success: returns the success, waits 1s once', () async {
      var calls = 0;
      final result = await retryOnNetworkTimeout(() async {
        calls++;
        if (calls == 1) throw _dio(DioExceptionType.receiveTimeout);
        return 'saved';
      }, wait: recordWait);

      expect(result, 'saved');
      expect(calls, 2);
      expect(waits, [const Duration(seconds: 1)]);
    });

    test('two timeouts then success on the third attempt: waits 1s then 2s', () async {
      var calls = 0;
      final result = await retryOnNetworkTimeout(() async {
        calls++;
        if (calls < 3) throw _dio(DioExceptionType.connectionTimeout);
        return 'saved';
      }, wait: recordWait);

      expect(result, 'saved');
      expect(calls, 3);
      expect(waits, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    });

    test('all three attempts time out: throws SlowNetworkException after exactly 3 calls', () async {
      var calls = 0;
      final timeout = _dio(DioExceptionType.sendTimeout);

      await expectLater(
        retryOnNetworkTimeout<String>(() async {
          calls++;
          throw timeout;
        }, wait: recordWait),
        throwsA(
          isA<SlowNetworkException>().having((e) => e.lastError, 'lastError', same(timeout)),
        ),
      );

      expect(calls, writeMaxAttempts);
      expect(calls, 3);
      expect(waits, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    });

    test('connection errors are retried the same way as timeouts', () async {
      var calls = 0;
      await expectLater(
        retryOnNetworkTimeout<String>(() async {
          calls++;
          throw _dio(DioExceptionType.connectionError);
        }, wait: recordWait),
        throwsA(isA<SlowNetworkException>()),
      );
      expect(calls, 3);
    });

    test('a mix of timeout kinds is still counted against the same 3 attempts', () async {
      var calls = 0;
      final kinds = [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ];
      await expectLater(
        retryOnNetworkTimeout<String>(() async {
          throw _dio(kinds[calls++]);
        }, wait: recordWait),
        throwsA(isA<SlowNetworkException>()),
      );
      expect(calls, 3);
    });

    test('HTTP 500 is rethrown immediately, not retried, not wrapped', () async {
      var calls = 0;
      final serverError = _dio(DioExceptionType.badResponse, status: 500);

      await expectLater(
        retryOnNetworkTimeout<String>(() async {
          calls++;
          throw serverError;
        }, wait: recordWait),
        throwsA(same(serverError)),
      );
      expect(calls, 1);
      expect(waits, isEmpty);
    });

    test('HTTP 400 validation error is rethrown immediately', () async {
      var calls = 0;
      await expectLater(
        retryOnNetworkTimeout<String>(() async {
          calls++;
          throw _dio(DioExceptionType.badResponse, status: 400);
        }, wait: recordWait),
        throwsA(isA<DioException>()),
      );
      expect(calls, 1);
    });

    test('a timeout followed by a 400 stops at the 400 (no more retries)', () async {
      var calls = 0;
      await expectLater(
        retryOnNetworkTimeout<String>(() async {
          calls++;
          if (calls == 1) throw _dio(DioExceptionType.receiveTimeout);
          throw _dio(DioExceptionType.badResponse, status: 400);
        }, wait: recordWait),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 400)),
      );
      expect(calls, 2);
    });

    test('non-Dio errors are rethrown immediately', () async {
      var calls = 0;
      await expectLater(
        retryOnNetworkTimeout<String>(() async {
          calls++;
          throw StateError('no business selected');
        }, wait: recordWait),
        throwsA(isA<StateError>()),
      );
      expect(calls, 1);
    });
  });

  group('newIdempotencyKey', () {
    test('is 32 lowercase hex chars, which the backend accepts', () {
      final key = newIdempotencyKey();
      expect(key, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(key), isTrue);
    });

    test('a fresh key on every call (no collisions in 1000 calls)', () {
      final keys = List.generate(1000, (_) => newIdempotencyKey()).toSet();
      expect(keys.length, 1000);
    });
  });

  group('saveErrorMessage', () {
    test('slow-network failure shows the dedicated message', () {
      expect(
        saveErrorMessage(SlowNetworkException(_dio(DioExceptionType.receiveTimeout))),
        Strings.slowNetwork,
      );
      expect(Strings.slowNetwork, 'Internet is slow, please try again later');
    });

    test('any other failure keeps the generic error prefix, unchanged from before', () {
      expect(saveErrorMessage(StateError('boom')), 'त्रुटि: Bad state: boom');
      expect(
        saveErrorMessage(_dio(DioExceptionType.badResponse, status: 400)),
        startsWith('त्रुटि: '),
      );
    });
  });
}
