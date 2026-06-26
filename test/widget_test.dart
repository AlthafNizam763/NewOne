import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisoka/config/theme.dart';
import 'package:hisoka/core/widgets/app_chrome.dart';

void main() {
  testWidgets('AppTheme.darkTheme applies without throwing',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(body: Text('Hisoka')),
    ));

    expect(find.text('Hisoka'), findsOneWidget);
  });

  testWidgets('AppTheme.lightTheme applies without throwing',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: Text('Hisoka')),
    ));

    expect(find.text('Hisoka'), findsOneWidget);
  });

  testWidgets('AppButton renders its label and fires onPressed',
      (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: AppButton(
          label: 'Open Chat',
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Open Chat'), findsOneWidget);

    await tester.tap(find.text('Open Chat'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('AppButton ignores taps when disabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(
        body: AppButton(
          label: 'Disabled',
          onPressed: null,
        ),
      ),
    ));

    await tester.tap(find.text('Disabled'));
    await tester.pump();

    // No exception thrown and the button stays put — nothing else to assert
    // since onPressed is null.
    expect(find.text('Disabled'), findsOneWidget);
  });
}
