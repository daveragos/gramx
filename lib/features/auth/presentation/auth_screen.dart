import 'package:flutter/material.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_code_page.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_loading_page.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_password_page.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_phone_page.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_qr_page.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_selection_page.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_top_bar.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If on sub-step (phone input, code, password, QR), pop to method selection
        if (authState.step != AuthStep.loginMethodSelection &&
            authState.step != AuthStep.loading) {
          controller.goBackToSelection();
          return;
        }

        // On root selection step: "Press back again to exit" UX
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.authPressBackAgain),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              AuthTopBar(authState: authState, controller: controller),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildPage(authState, controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(AuthState authState, AuthController controller) {
    return switch (authState.step) {
      AuthStep.loading => AuthLoadingPage(
          authState: authState,
          pulseController: _pulseController,
          controller: controller,
        ),
      AuthStep.loginMethodSelection => AuthSelectionPage(
          authState: authState,
          controller: controller,
        ),
      AuthStep.waitPhoneNumber => AuthPhonePage(
          authState: authState,
          controller: controller,
          phoneController: _phoneController,
        ),
      AuthStep.waitCode => AuthCodePage(
          authState: authState,
          controller: controller,
          codeController: _codeController,
        ),
      AuthStep.waitPassword => AuthPasswordPage(
          authState: authState,
          controller: controller,
          passwordController: _passwordController,
          obscurePassword: _obscurePassword,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      AuthStep.waitQrCode => AuthQrPage(
          authState: authState,
          controller: controller,
        ),
      AuthStep.error => AuthErrorPage(
          authState: authState,
          controller: controller,
        ),
      AuthStep.authenticated => AuthLoadingPage(
          authState: authState,
          pulseController: _pulseController,
          controller: controller,
        ),
    };
  }
}
