import 'package:bahi/features/buyers/repositories/bill_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/scripted_adapter.dart';

void main() {
  late ScriptedAdapter api;

  setUp(() => api = installScriptedApi());

  // 14:30 device-local, so the offset is non-zero off UTC.
  final chosen = DateTime(2026, 10, 9, 14, 30);

  test('bill payment sends paidAt as UTC with an explicit Z', () async {
    api.ok({});

    await BillRepository.addPayment(
      businessId: 'biz-1',
      billId: 'bill-1',
      amount: 50,
      paidAt: chosen,
    );

    final req = api.requests.single;
    expect(req.path, '/businesses/biz-1/bills/bill-1/payments');
    expect(req.data['amount'], 50);
    final sent = req.data['paidAt'] as String;
    expect(sent, endsWith('Z'));
    expect(DateTime.parse(sent).isAtSameMomentAs(chosen), isTrue);
  });

  test('buyer-level payment sends paidAt as UTC with an explicit Z', () async {
    api.ok({});

    await BillRepository.recordBuyerPayment(
      businessId: 'biz-1',
      buyerId: 'buyer-1',
      amount: 120,
      paidAt: chosen,
    );

    final req = api.requests.single;
    expect(req.path, '/businesses/biz-1/buyers/buyer-1/payments');
    final sent = req.data['paidAt'] as String;
    expect(sent, endsWith('Z'));
    expect(DateTime.parse(sent).isAtSameMomentAs(chosen), isTrue);
  });
}
