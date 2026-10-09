import 'dart:async';

import 'package:bahi/core/constants/strings.dart';
import 'package:bahi/core/models/inventory_item.dart';
import 'package:bahi/core/services/write_retry.dart';
import 'package:bahi/features/inventory/providers/inventory_providers.dart';
import 'package:bahi/features/inventory/screens/item_detail_screen.dart';
import 'package:bahi/features/team/providers/team_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _item = InventoryItem(
  id: 'item-1',
  businessId: 'biz-1',
  name: 'Rice',
  price: 40,
  quantity: 15,
  unit: 'kg',
  updatedAt: DateTime.utc(2026, 10, 9),
  updatedBy: 'user-1',
  createdAt: DateTime.utc(2026, 10, 9),
);

/// Pumps the detail screen with providers stubbed out, and lets each test
/// control when the add-stock request completes.
Future<Completer<InventoryItem>> _pump(WidgetTester tester) async {
  final pending = Completer<InventoryItem>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inventoryItemsProvider.overrideWith((ref) => Stream.value([_item])),
        teamMembersProvider.overrideWith((ref) => Stream.value([])),
        priceHistoryProvider(_item.id).overrideWith((ref) async => []),
        addStockProvider.overrideWith((ref, input) => pending.future),
      ],
      child: MaterialApp(home: ItemDetailScreen(item: _item)),
    ),
  );
  await tester.pump();
  return pending;
}

/// Opens the bottom sheet, types a quantity, and taps its submit button.
Future<void> _submitStock(WidgetTester tester, String quantity) async {
  await tester.tap(find.widgetWithText(OutlinedButton, Strings.addStock));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, quantity);
  await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.byType(ElevatedButton)));
  await tester.pump(); // start the save; the sheet closes
}

Finder get _ctaSpinner =>
    find.descendant(of: find.byType(OutlinedButton), matching: find.byType(CircularProgressIndicator));

void main() {
  testWidgets('while the add-stock save is running, the CTA shows a spinner and is disabled', (tester) async {
    final pending = await _pump(tester);
    await _submitStock(tester, '5');

    expect(_ctaSpinner, findsOneWidget);
    final cta = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(cta.onPressed, isNull, reason: 'a second tap must not start a second add');

    pending.complete(_item.copyWith(quantity: 20));
    await tester.pumpAndSettle();
  });

  testWidgets('spinner stays up across a slow save, then clears on success with the success snackbar', (tester) async {
    final pending = await _pump(tester);
    await _submitStock(tester, '5');

    await tester.pump(const Duration(seconds: 5));
    expect(_ctaSpinner, findsOneWidget, reason: 'still saving, so loader must remain');

    pending.complete(_item.copyWith(quantity: 20));
    await tester.pumpAndSettle();

    expect(_ctaSpinner, findsNothing);
    expect(find.text(Strings.stockAdded), findsOneWidget);
    final cta = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(cta.onPressed, isNotNull, reason: 'button usable again after success');
  });

  testWidgets('after every retry timed out, the user sees the slow-internet message and the button is usable again', (tester) async {
    final pending = await _pump(tester);
    await _submitStock(tester, '5');

    pending.completeError(
      SlowNetworkException(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.receiveTimeout,
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.slowNetwork), findsOneWidget);
    expect(find.text('Internet is slow, please try again later'), findsOneWidget);
    expect(_ctaSpinner, findsNothing);
    final cta = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(cta.onPressed, isNotNull);
  });

  testWidgets('a non-network failure keeps the generic error text, not the slow-internet text', (tester) async {
    final pending = await _pump(tester);
    await _submitStock(tester, '5');

    pending.completeError(StateError('No business selected'));
    await tester.pumpAndSettle();

    expect(find.text(Strings.slowNetwork), findsNothing);
    expect(find.textContaining('त्रुटि:'), findsOneWidget);
  });
}
