import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haizhucode/l10n/app_localizations.dart';
import 'package:haizhucode/ui/app_theme.dart';
import 'package:opencode_widgetbook/chat/conversation.dart';

import 'standard_measure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'AppSans': 'fonts/geist/Geist-Variable.ttf',
      'AppMono': 'fonts/geist/GeistMono-Variable.ttf',
      'AppPhosphorRegular': 'fonts/phosphor/Phosphor.ttf',
      'AppPhosphorDuotone': 'fonts/phosphor/Phosphor-Duotone.ttf',
      'AppPhosphorFill': 'fonts/phosphor/Phosphor-Fill.ttf',
      'Noto Sans Arabic': '../test/fixtures/fonts/NotoSansArabic-Regular.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(File(entry.value).readAsBytesSync()),
          ),
        );
      await loader.load();
    }
  });
  for (final (language, scale, dark) in [
    ('en', 1.0, false),
    ('en', 2.0, false),
    ('ar', 1.0, false),
    ('en', 1.0, true),
  ]) {
    testWidgets('unconfirmed send: $language, $scale, dark=$dark', (
      tester,
    ) async {
      final useCase = conversationScreen().component.useCases.singleWhere(
        (entry) => entry.name == 'Unconfirmed send',
      );
      final locale = Locale(language);
      final firstView = language == 'en' && scale == 1 && !dark;
      final result = await measurePass(
        tester,
        name: '$language-$scale-$dark',
        home: useCase.builder,
        theme: AppTheme.forLocale(
          dark ? AppTheme.dark() : AppTheme.light(),
          locale,
        ),
        locale: locale,
        scale: scale,
        delegates: AppLocalizations.localizationsDelegates,
        locales: AppLocalizations.supportedLocales,
        firstViewRules: firstView,
      );
      expect(result.skipped, isFalse);
      expect(
        findings(result, firstViewRules: firstView),
        isEmpty,
        reason: result.toJson().toString(),
      );
    });
  }
}
