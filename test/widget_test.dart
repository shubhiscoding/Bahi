import 'package:bahi/core/providers/text_scale_provider.dart';
import 'package:bahi/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app builds its root MaterialApp', (WidgetTester tester) async {
    // Mirror main(): MyApp needs the persisted text-size override, otherwise
    // textScaleProvider throws UnimplementedError.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          textScaleProvider.overrideWith((ref) => TextScaleNotifier(TextSizeLevel.normal)),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
