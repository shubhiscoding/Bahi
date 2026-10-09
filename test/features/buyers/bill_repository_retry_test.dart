import 'package:bahi/core/models/bill.dart';
import 'package:bahi/core/services/write_retry.dart';
import 'package:bahi/features/buyers/repositories/bill_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/scripted_adapter.dart';

const _billJson = {
  'id': 'bill-1',
  'buyerId': 'buyer-1',
  'billDate': '2026-10-09T00:00:00.000Z',
  'total': 30,
  'paid': 0,
  'due': 30,
  'createdAt': '2026-10-09T00:00:00.000Z',
  'items': [],
  'payments': [],
};

final _keyPattern = RegExp(r'^[0-9a-f]{32}$');

Future<Bill> _save() => BillRepository.createBill(
      businessId: 'biz-1',
      buyerId: 'buyer-1',
      billDate: DateTime.utc(2026, 10, 9),
      items: [BillLineInput(itemId: 'item-1', quantity: 3, price: 10)],
      markPaidNow: false,
    );

void main() {
  late ScriptedAdapter api;

  setUp(() => api = installScriptedApi());

  test('a timed-out bill save is retried and succeeds: caller gets the bill', () async {
    api.timeout();
    api.ok(_billJson);

    final bill = await _save();

    expect(bill.id, 'bill-1');
    expect(api.requests, hasLength(2));
    expect(api.requests.every((r) => r.method == 'POST'), isTrue);
    expect(api.requests.every((r) => r.path == '/businesses/biz-1/bills'), isTrue);
  });

  test('every attempt of one save reuses the SAME Idempotency-Key (server dedupes)', () async {
    api.timeout();
    api.timeout();
    api.ok(_billJson);

    await _save();

    final keys = api.requests.map((r) => r.headers[idempotencyKeyHeader]).toList();
    expect(keys, hasLength(3));
    expect(keys.first, matches(_keyPattern));
    expect(keys.toSet(), hasLength(1), reason: 'retries must not change the key');
  });

  test('the request body is identical on every retry', () async {
    api.timeout();
    api.ok(_billJson);

    await _save();

    expect(api.requests[0].data, equals(api.requests[1].data));
    expect(api.requests[1].data['items'], [
      {'itemId': 'item-1', 'quantity': 3, 'price': 10.0},
    ]);
  });

  test('two separate saves get two different keys', () async {
    api.ok(_billJson);
    api.ok({..._billJson, 'id': 'bill-2'});

    await _save();
    await _save();

    final k1 = api.requests[0].headers[idempotencyKeyHeader];
    final k2 = api.requests[1].headers[idempotencyKeyHeader];
    expect(k1, isNot(equals(k2)));
  });

  test('three timeouts: throws SlowNetworkException after exactly 3 attempts', () async {
    api.timeout();
    api.timeout();
    api.timeout();

    await expectLater(_save(), throwsA(isA<SlowNetworkException>()));
    expect(api.requests, hasLength(writeMaxAttempts));
  });

  test('connection error on every attempt also ends in SlowNetworkException', () async {
    api.timeout(DioExceptionType.connectionError);
    api.timeout(DioExceptionType.connectionError);
    api.timeout(DioExceptionType.connectionError);

    await expectLater(_save(), throwsA(isA<SlowNetworkException>()));
    expect(api.requests, hasLength(3));
  });

  test('a 400 from the server is NOT retried and surfaces as the raw DioException', () async {
    api.httpError(400);

    await expectLater(_save(), throwsA(isA<DioException>()));
    expect(api.requests, hasLength(1));
  });

  test('a 500 from the server is NOT retried (it was answered, not timed out)', () async {
    api.httpError(500);

    await expectLater(_save(), throwsA(isA<DioException>()));
    expect(api.requests, hasLength(1));
  });
}
