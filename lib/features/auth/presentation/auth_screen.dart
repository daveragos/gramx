import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Navigate to home if authenticated
    if (authState.step == AuthStep.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/home');
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Log in to gramX'),
        centerTitle: true,
        leading: authState.step != AuthStep.loginMethodSelection && authState.step != AuthStep.loading
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => controller.reset(),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // gramX Logo
              Center(
                child: Text(
                  'gramX',
                  style: AppTypography.heading(color: AppColors.accent).copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'A Telegram feed client with a timeline UI',
                  style: AppTypography.body(color: secondaryTextColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              
              if (authState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error, width: 0.5),
                  ),
                  child: Text(
                    authState.errorMessage!,
                    style: AppTypography.body(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Content based on authentication step
              Expanded(
                flex: 4,
                child: _buildStepContent(authState, controller, primaryTextColor, secondaryTextColor),
              ),
              
              const Spacer(),
              // Legal / Guidelines Disclosure
              Text(
                'By signing in, you agree to our Terms of Service and Privacy Policy. This is an unofficial client powered by the Telegram Database Library (TDLib).',
                style: AppTypography.actionCount(color: secondaryTextColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(
    AuthState authState,
    AuthController controller,
    Color primaryColor,
    Color secondaryColor,
  ) {
    if (authState.step == AuthStep.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    switch (authState.step) {
      case AuthStep.waitPhoneNumber:
        return _buildPhoneInputStep(authState, controller, primaryColor, secondaryColor);
      case AuthStep.waitCode:
        return _buildCodeInputStep(authState, controller, primaryColor, secondaryColor);
      case AuthStep.waitPassword:
        return _buildPasswordInputStep(authState, controller, primaryColor, secondaryColor);
      case AuthStep.waitQrCode:
        return _buildQrCodeStep(authState, controller, primaryColor, secondaryColor);
      default:
        return _buildSelectionStep(controller, primaryColor, secondaryColor);
    }
  }

  Widget _buildSelectionStep(
    AuthController controller,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () {
            // Push to phone login state
            controller.submitPhoneNumber(''); // triggers parameter wait/phone wait
          },
          child: const Text('Log in with Phone Number', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: BorderSide(color: primaryColor),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () => controller.requestQrLogin(),
          child: const Text('Log in via QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () {
            // Guest Mode - skip authentication and navigate to feed
            context.go('/home');
          },
          child: Text(
            'Use Offline / Guest Mode',
            style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInputStep(
    AuthState authState,
    AuthController controller,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter phone number',
          style: AppTypography.heading(color: primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Please verify your country code and enter your full phone number in international format.',
          style: AppTypography.body(color: secondaryColor),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: '+1 555 123 4567',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: secondaryColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: authState.isSubmitting
              ? null
              : () {
                  if (_phoneController.text.isNotEmpty) {
                    controller.submitPhoneNumber(_phoneController.text.trim());
                  }
                },
          child: authState.isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCodeInputStep(
    AuthState authState,
    AuthController controller,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter verification code',
          style: AppTypography.heading(color: primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a verification code to your Telegram account or phone.',
          style: AppTypography.body(color: secondaryColor),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: InputDecoration(
            labelText: 'Code',
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: secondaryColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: authState.isSubmitting
              ? null
              : () {
                  if (_codeController.text.isNotEmpty) {
                    controller.submitCode(_codeController.text.trim());
                  }
                },
          child: authState.isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildPasswordInputStep(
    AuthState authState,
    AuthController controller,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter cloud password',
          style: AppTypography.heading(color: primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Your Telegram account is protected by 2-step verification. Enter your password.',
          style: AppTypography.body(color: secondaryColor),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: secondaryColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: authState.isSubmitting
              ? null
              : () {
                  if (_passwordController.text.isNotEmpty) {
                    controller.submitPassword(_passwordController.text.trim());
                  }
                },
          child: authState.isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildQrCodeStep(
    AuthState authState,
    AuthController controller,
    Color primaryColor,
    Color secondaryColor,
  ) {
    final qrLink = authState.qrCodeLink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scan this QR code',
          style: AppTypography.heading(color: primaryColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Open Telegram on your phone, go to Settings > Devices > Link Desktop Device and scan the code below.',
          style: AppTypography.body(color: secondaryColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (qrLink != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: qrLink,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => controller.reset(),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
