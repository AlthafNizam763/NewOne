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

  testWidgets('BrutalButton renders its label and fires onPressed',
      (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: BrutalButton(
          label: 'OPEN CHAT',
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('OPEN CHAT'), findsOneWidget);

    await tester.tap(find.text('OPEN CHAT'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('BrutalButton ignores taps when disabled',
      (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(
        body: BrutalButton(
          label: 'DISABLED',
          onPressed: null,
        ),
      ),
    ));

    await tester.tap(find.text('DISABLED'));
    await tester.pump();

    expect(tapped, isFalse);
  });
}
