import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/l10n/app_localizations.dart';

void main() {
  for (final (code, text) in [('de', 'Video abrufen'), ('en', 'Fetch video')]) {
    testWidgets('localizes loadVideo for $code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (c) => Text(AppLocalizations.of(c).loadVideo)),
        ),
      );
      expect(find.text(text), findsOneWidget);
    });
  }
}
