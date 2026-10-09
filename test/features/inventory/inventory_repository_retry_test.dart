import 'package:bahi/core/models/inventory_item.dart';
import 'package:bahi/core/services/write_retry.dart';
import 'package:bahi/features/inventory/repositories/inventory_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/scripted_adapter.dart';

const _itemJson = {
  'id': 'item-1',
  'businessId': 'biz-1',
  'name': 'Rice',
  'price': 40,
  'quantity': 15,
  'unit': 'kg',
  'updatedAt': '2026-10-09T00:00:00.000Z',
  'updatedBy': 'user-1',
  'createdAt': '2026-10-09T00:00:00.000Z',
};

final _keyPattern = RegExp(r'^[0-9a-f]{32}$');

Future<void> _createItem() => InventoryRepository.createItem(
      businessId: 'biz-1',
      name: 'Rice',
      price: 40,
      quantity: 10,
      unit: 'kg',
    );

Future<InventoryItem> _addStock() => InventoryRepository.addStock(
      businessId: 'biz-1',
      itemId: 'item-1',
      quantity: 5,
    );

void main() {
  late ScriptedAdapter api;

  setUp(() => api = installScriptedApi());

  group('createItem (adding a new item)', () {
    test('timed-out create is retried and succeeds', () async {
      api.timeout();
      api.ok(_itemJson);

      final item = await InventoryRepository.createItem(
        businessId: 'biz-1',
        name: 'Rice',
        price: 40,
        quantity: 10,
        unit: 'kg',
      );

      expect(item.id, 'item-1');
      expect(api.requests, hasLength(2));
      expect(api.requests.every((r) => r.path == '/businesses/biz-1/items'), isTrue);
    });

    test('all attempts share one valid Idempotency-Key, so the server creates the item once', () async {
      api.timeout();
      api.timeout();
      api.ok(_itemJson);

      await _createItem();

      final keys = api.requests.map((r) => r.headers[idempotencyKeyHeader]).toList();
      expect(keys, hasLength(3));
      expect(keys.first, matches(_keyPattern));
      expect(keys.toSet(), hasLength(1));
    });

    test('three timeouts: SlowNetworkException after 3 attempts', () async {
      api.timeout();
      api.timeout();
      api.timeout();

      await expectLater(_createItem(), throwsA(isA<SlowNetworkException>()));
      expect(api.requests, hasLength(writeMaxAttempts));
    });

    test('a 400 validation error is not retried', () async {
      api.httpError(400);

      await expectLater(_createItem(), throwsA(isA<DioException>()));
      expect(api.requests, hasLength(1));
    });
  });

  group('addStock (restock an existing item)', () {
    test('timed-out add-stock is retried; all attempts send the same key', () async {
      api.timeout();
      api.ok(_itemJson, status: 200);

      final item = await _addStock();

      expect(item.quantity, 15);
      expect(api.requests, hasLength(2));
      final keys = api.requests.map((r) => r.headers[idempotencyKeyHeader]).toList();
      expect(keys.toSet(), hasLength(1));
      expect(keys.first, matches(_keyPattern));
      expect(api.requests.every((r) => r.path == '/businesses/biz-1/items/item-1/add-stock'), isTrue);
    });

    test('request body (quantity) is identical on each retry', () async {
      api.timeout();
      api.ok(_itemJson, status: 200);

      await _addStock();

      expect(api.requests[0].data, {'quantity': 5});
      expect(api.requests[1].data, {'quantity': 5});
    });

    test('three timeouts: SlowNetworkException after 3 attempts', () async {
      api.timeout();
      api.timeout();
      api.timeout();

      await expectLater(_addStock(), throwsA(isA<SlowNetworkException>()));
      expect(api.requests, hasLength(writeMaxAttempts));
    });

    test('a 400 (e.g. invalid quantity) is not retried', () async {
      api.httpError(400);

      await expectLater(_addStock(), throwsA(isA<DioException>()));
      expect(api.requests, hasLength(1));
    });
  });

  group('regression guard: writes that are NOT in scope stay unretried', () {
    test('updateItem still fails on the first timeout (no retry, no key)', () async {
      api.timeout();

      await expectLater(
        InventoryRepository.updateItem(
          businessId: 'biz-1',
          itemId: 'item-1',
          name: 'Rice',
          price: 40,
          quantity: 10,
          unit: 'kg',
        ),
        throwsA(isA<DioException>()),
      );
      expect(api.requests, hasLength(1));
      expect(api.requests.single.headers.containsKey(idempotencyKeyHeader), isFalse);
    });
  });
}
