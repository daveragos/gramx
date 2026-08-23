import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_selection_page.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_top_bar.dart';

/// The page only reads its [AuthState] to build; the controller is touched on
/// tap, which these tests don't do.
final controller = AuthController();

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('the sign-in screen', () {
    testWidgets('introduces the app with its own icon', (tester) async {
      await tester.pumpWidget(host(AuthSelectionPage(
        authState: const AuthState(step: AuthStep.loginMethodSelection),
        controller: controller,
      )));

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName,
          'assets/icon/app_icon.png');
    });

    // The reported complaint: spacers pushed the welcome block and the buttons
    // to opposite ends, leaving a hand's width of nothing between them.
    testWidgets('keeps the welcome and the buttons together', (tester) async {
      await tester.pumpWidget(host(AuthSelectionPage(
        authState: const AuthState(step: AuthStep.loginMethodSelection),
        controller: controller,
      )));

      final taglineBottom =
          tester.getBottomLeft(find.text(AppStrings.authTagline)).dy;
      final firstButtonTop =
          tester.getTopLeft(find.text(AppStrings.authContinueWithPhone)).dy;

      expect(firstButtonTop - taglineBottom, lessThan(120),
          reason: 'they read as one block, not two ends of the screen');
      expect(firstButtonTop, greaterThan(taglineBottom));
    });

    testWidgets('keeps the agreement line at the bottom', (tester) async {
      await tester.pumpWidget(host(AuthSelectionPage(
        authState: const AuthState(step: AuthStep.loginMethodSelection),
        controller: controller,
      )));

      final qrButton =
          tester.getBottomLeft(find.text(AppStrings.authLogInWithQr)).dy;
      final agreement =
          tester.getTopLeft(find.byType(LegalAgreementLine)).dy;

      expect(agreement, greaterThan(qrButton));
    });

    testWidgets('an error is shown above the buttons, not instead of them',
        (tester) async {
      await tester.pumpWidget(host(AuthSelectionPage(
        authState: const AuthState(
          step: AuthStep.loginMethodSelection,
          errorMessage: 'Something went wrong',
        ),
        controller: controller,
      )));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text(AppStrings.authContinueWithPhone), findsOneWidget);
    });
  });

  group('the top bar', () {
    // The app names itself once, under its own icon. A wordmark above that is
    // furniture.
    testWidgets('carries no wordmark', (tester) async {
      await tester.pumpWidget(host(AuthTopBar(
        authState: const AuthState(step: AuthStep.loginMethodSelection),
        controller: controller,
      )));

      expect(find.text(AppStrings.appName), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('offers a way back from a sub-step', (tester) async {
      await tester.pumpWidget(host(AuthTopBar(
        authState: const AuthState(step: AuthStep.waitQrCode),
        controller: controller,
      )));

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });
}
