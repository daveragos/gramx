import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/theme/brand_assets.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_selection_page.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_top_bar.dart';

/// The page only reads [AuthState] to build; these tests don't tap.
final controller = AuthController();

Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: child),
    );

void main() {
  group('the sign-in screen', () {
    testWidgets('introduces the app with its own icon', (tester) async {
      await tester.pumpWidget(
        host(
          AuthSelectionPage(
            authState: const AuthState(step: AuthStep.loginMethodSelection),
            controller: controller,
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        BrandAssets.appIconFor(Brightness.light),
      );
    });

    // Each brightness has its own icon file. Each gets a fresh pump, since
    // swapping the theme on a live tree makes MaterialApp animate it.
    for (final brightness in Brightness.values) {
      testWidgets(
        'picks the icon variant a ${brightness.name} screen can show',
        (tester) async {
          await tester.pumpWidget(
            host(
              AuthSelectionPage(
                authState: const AuthState(step: AuthStep.loginMethodSelection),
                controller: controller,
              ),
              brightness: brightness,
            ),
          );

          final image = tester.widget<Image>(find.byType(Image));
          expect(
            (image.image as AssetImage).assetName,
            BrandAssets.appIconFor(brightness),
          );
        },
      );
    }

    test('has a different icon for each ground', () {
      expect(
        BrandAssets.appIconFor(Brightness.dark),
        isNot(BrandAssets.appIconFor(Brightness.light)),
      );
    });

    testWidgets('keeps the welcome and the buttons together', (tester) async {
      await tester.pumpWidget(
        host(
          AuthSelectionPage(
            authState: const AuthState(step: AuthStep.loginMethodSelection),
            controller: controller,
          ),
        ),
      );

      final taglineBottom = tester
          .getBottomLeft(find.text(AppStrings.authTagline))
          .dy;
      final firstButtonTop = tester
          .getTopLeft(find.text(AppStrings.authContinueWithPhone))
          .dy;

      expect(
        firstButtonTop - taglineBottom,
        lessThan(120),
        reason: 'they read as one block, not two ends of the screen',
      );
      expect(firstButtonTop, greaterThan(taglineBottom));
    });

    testWidgets('keeps the agreement line at the bottom', (tester) async {
      await tester.pumpWidget(
        host(
          AuthSelectionPage(
            authState: const AuthState(step: AuthStep.loginMethodSelection),
            controller: controller,
          ),
        ),
      );

      final qrButton = tester
          .getBottomLeft(find.text(AppStrings.authLogInWithQr))
          .dy;
      final agreement = tester.getTopLeft(find.byType(LegalAgreementLine)).dy;

      expect(agreement, greaterThan(qrButton));
    });

    testWidgets('an error is shown above the buttons, not instead of them', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AuthSelectionPage(
            authState: const AuthState(
              step: AuthStep.loginMethodSelection,
              errorMessage: 'Something went wrong',
            ),
            controller: controller,
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text(AppStrings.authContinueWithPhone), findsOneWidget);
    });
  });

  group('the top bar', () {
    // The app name appears once, under the icon.
    testWidgets('carries no wordmark', (tester) async {
      await tester.pumpWidget(
        host(
          AuthTopBar(
            authState: const AuthState(step: AuthStep.loginMethodSelection),
            controller: controller,
          ),
        ),
      );

      expect(find.text(AppStrings.appName), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('offers a way back from a sub-step', (tester) async {
      await tester.pumpWidget(
        host(
          AuthTopBar(
            authState: const AuthState(step: AuthStep.waitQrCode),
            controller: controller,
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });
}
