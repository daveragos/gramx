import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/l10n/legal_text.dart';
import 'package:gramx/features/settings/presentation/legal_screen.dart';

void main() {
  group('the documents', () {
    test('both exist and are reachable by their route id', () {
      expect(LegalTexts.byId('privacy'), same(LegalTexts.privacy));
      expect(LegalTexts.byId('terms'), same(LegalTexts.terms));
      expect(LegalTexts.byId('nonsense'), isNull);
    });

    test('the routes match the ids the router parses', () {
      expect(LegalTexts.privacyRoute, '/legal/privacy');
      expect(LegalTexts.termsRoute, '/legal/terms');
      expect(LegalTexts.byId(LegalTexts.privacyRoute.split('/').last),
          isNotNull);
      expect(LegalTexts.byId(LegalTexts.termsRoute.split('/').last), isNotNull);
    });

    test('no section is empty, in either document', () {
      for (final document in [LegalTexts.privacy, LegalTexts.terms]) {
        expect(document.sections, isNotEmpty);
        for (final section in document.sections) {
          expect(section.heading, isNotEmpty);
          expect(section.paragraphs, isNotEmpty,
              reason: '"${section.heading}" has a heading and nothing under it');
          for (final paragraph in section.paragraphs) {
            expect(paragraph.trim(), isNotEmpty);
          }
        }
      }
    });

    // The policy makes specific promises about what this app does. These are
    // the ones that would be a lie if the code changed underneath them.
    test('the privacy policy still covers what the app actually does', () {
      final text = LegalTexts.privacy.sections
          .expand((s) => [s.heading, ...s.paragraphs])
          .join(' ')
          .toLowerCase();

      for (final claim in [
        'read', // read state syncing to their other devices
        'bookmark',
        'muted',
        'keystore', // how the local database is protected
        'analytics',
        'logging out', // how someone gets their data off the device
      ]) {
        expect(text, contains(claim),
            reason: 'the policy no longer mentions $claim');
      }
    });

    test('the terms say what the app is and is not', () {
      final text = LegalTexts.terms.sections
          .expand((s) => [s.heading, ...s.paragraphs])
          .join(' ')
          .toLowerCase();

      expect(text, contains('not made by, affiliated with, or endorsed by'));
      // The disclaimer and the liability limit are the load-bearing parts.
      expect(text, contains('no warranty'));
      expect(text, contains('not liable'));
      expect(text, contains('rate-limit'));
    });
  });

  group('version', () {
    // Three places show it and Telegram shows a fourth, in the reader's own
    // device list. One constant feeds them all; this keeps it in step with the
    // version the build is actually stamped with.
    test('matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declared = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1)!;

      expect(declared.split('+').first, AppStrings.appVersion);
    });

    test('the drawer label uses that one constant', () {
      expect(AppStrings.appVersionLabel(), contains(AppStrings.appVersion));
    });
  });

  group('LegalScreen', () {
    testWidgets('renders a document, headings and all', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LegalScreen(documentId: 'privacy'),
      ));

      expect(find.text(LegalTexts.privacy.title), findsOneWidget);
      expect(
        find.text(LegalTexts.privacy.sections.first.heading),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.legalLastUpdated(LegalTexts.lastUpdated)),
        findsOneWidget,
      );
    });

    testWidgets('an unknown document says so instead of crashing',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LegalScreen(documentId: 'nope'),
      ));

      expect(find.text(AppStrings.legalNotFoundBody), findsOneWidget);
    });
  });
}
