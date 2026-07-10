import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

// ============================================================================
// AuthScreen — page‑driven Telegram login flow.
//
// Each AuthStep maps to its own full‑screen page. Transitions between pages
// are animated with a horizontal slide. The screen listens to
// [authControllerProvider] and reacts to step changes automatically.
// ============================================================================

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  // Text controllers — one per input field. They survive page transitions
  // because ConsumerStatefulWidget keeps state alive as long as the route is.
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Page animation
  late final AnimationController _pageAnimController;
  late final Animation<Offset> _slideIn;
  late final Animation<double> _fadeIn;

  AuthStep _previousStep = AuthStep.loading;

  @override
  void initState() {
    super.initState();
    _pageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageAnimController,
      curve: Curves.easeOutCubic,
    ));
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _pageAnimController,
      curve: Curves.easeOut,
    ));
    _pageAnimController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _pageAnimController.dispose();
    super.dispose();
  }

  void _animateStepChange() {
    _pageAnimController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Animate when step changes.
    if (authState.step != _previousStep) {
      _previousStep = authState.step;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateStepChange();
      });
    }

    // Navigate home on authentication.
    if (authState.step == AuthStep.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────
            _buildTopBar(authState, controller, theme),

            // ── Content ────────────────────────────────────────────────
            Expanded(
              child: SlideTransition(
                position: _slideIn,
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: _buildPage(authState, controller, theme),
                ),
              ),
            ),

            // ── Footer ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.lg,
              ),
              child: Text(
                'By signing in, you agree to our Terms of Service and Privacy Policy.\n'
                'This is an unofficial client powered by TDLib.',
                style: AppTypography.actionCount(color: secondaryColor),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Top bar
  // ==========================================================================
  Widget _buildTopBar(
    AuthState authState,
    AuthController controller,
    ThemeData theme,
  ) {
    final bool showBack = authState.step != AuthStep.loginMethodSelection &&
        authState.step != AuthStep.loading;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => controller.reset(),
              tooltip: 'Back',
            )
          else
            const SizedBox(width: 48), // balance the row

          Expanded(
            child: Center(
              child: Text(
                'Log in to gramX',
                style: AppTypography.heading(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),

          const SizedBox(width: 48), // balance
        ],
      ),
    );
  }

  // ==========================================================================
  // Page router — picks the right page for the current step.
  // ==========================================================================
  Widget _buildPage(
    AuthState authState,
    AuthController controller,
    ThemeData theme,
  ) {
    return switch (authState.step) {
      AuthStep.loading => _LoadingPage(),
      AuthStep.loginMethodSelection => _SelectionPage(
          authState: authState,
          controller: controller,
        ),
      AuthStep.waitPhoneNumber => _PhoneInputPage(
          authState: authState,
          controller: controller,
          phoneController: _phoneController,
        ),
      AuthStep.waitCode => _CodeInputPage(
          authState: authState,
          controller: controller,
          codeController: _codeController,
        ),
      AuthStep.waitPassword => _PasswordInputPage(
          authState: authState,
          controller: controller,
          passwordController: _passwordController,
          obscurePassword: _obscurePassword,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      AuthStep.waitQrCode => _QrCodePage(
          authState: authState,
          controller: controller,
        ),
      AuthStep.error => _ErrorPage(
          authState: authState,
          controller: controller,
        ),
      AuthStep.authenticated => _LoadingPage(), // brief flash before redirect
    };
  }
}

// ============================================================================
// LOADING PAGE
// ============================================================================
class _LoadingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'gramX',
            style: AppTypography.heading(color: AppColors.accent).copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A Telegram feed client with a timeline UI',
            style: AppTypography.body(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 48),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Connecting to Telegram…',
            style: AppTypography.actionCount(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// METHOD SELECTION PAGE
// ============================================================================
class _SelectionPage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;

  const _SelectionPage({
    required this.authState,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isSubmitting = authState.isSubmitting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Logo
          Text(
            'gramX',
            style: AppTypography.heading(color: AppColors.accent).copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A Telegram feed client with a timeline UI',
            style: AppTypography.body(color: secondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Log in with your Telegram account\nto get started.',
            style: AppTypography.body(color: secondaryColor),
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 3),

          // Error banner
          if (authState.errorMessage != null) ...[
            _ErrorBanner(message: authState.errorMessage!),
            const SizedBox(height: 16),
          ],

          // Phone login button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              onPressed: isSubmitting ? null : () => controller.selectPhoneLogin(),
              icon: const Icon(Icons.phone, size: 20),
              label: const Text(
                'Continue with Phone Number',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // QR code button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: isSubmitting ? null : () => controller.requestQrLogin(),
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(Icons.qr_code_2, size: 20),
              label: Text(
                isSubmitting ? 'Connecting…' : 'Log in via QR Code',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ============================================================================
// PHONE INPUT PAGE
// ============================================================================
class _PhoneInputPage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;
  final TextEditingController phoneController;

  const _PhoneInputPage({
    required this.authState,
    required this.controller,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),

          // Header
          Text(
            'Enter your\nphone number',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please enter your phone number in international format. '
            'We\'ll send a verification code to your Telegram account.',
            style: AppTypography.body(color: secondaryColor),
          ),
          const SizedBox(height: 32),

          // Phone input
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]')),
            ],
            decoration: InputDecoration(
              hintText: '+1 555 123 4567',
              hintStyle: TextStyle(color: secondaryColor.withOpacity(0.5)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: Icon(Icons.phone_outlined, color: AppColors.accent, size: 22),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Error
          if (authState.errorMessage != null) ...[
            _ErrorBanner(message: authState.errorMessage!),
            const SizedBox(height: 16),
          ],

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              onPressed: authState.isSubmitting
                  ? null
                  : () {
                      final phone = phoneController.text.trim();
                      if (phone.isNotEmpty) {
                        controller.submitPhoneNumber(phone);
                      }
                    },
              child: authState.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Next',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ============================================================================
// CODE INPUT PAGE
// ============================================================================
class _CodeInputPage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;
  final TextEditingController codeController;

  const _CodeInputPage({
    required this.authState,
    required this.controller,
    required this.codeController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),

          // Animated checkmark icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.message_outlined,
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Enter the code',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a verification code to your Telegram account'
            '${authState.phoneNumber != null ? ' (${authState.phoneNumber})' : ''}.',
            style: AppTypography.body(color: secondaryColor),
          ),
          const SizedBox(height: 32),

          // Code input
          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
              color: primaryColor,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • • • •',
              hintStyle: TextStyle(
                color: secondaryColor.withOpacity(0.3),
                fontSize: 28,
                letterSpacing: 12,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (authState.errorMessage != null) ...[
            _ErrorBanner(message: authState.errorMessage!),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              onPressed: authState.isSubmitting
                  ? null
                  : () {
                      final code = codeController.text.trim();
                      if (code.isNotEmpty) {
                        controller.submitCode(code);
                      }
                    },
              child: authState.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Verify',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ============================================================================
// PASSWORD INPUT PAGE
// ============================================================================
class _PasswordInputPage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;

  const _PasswordInputPage({
    required this.authState,
    required this.controller,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),

          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_outline,
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Two-step verification',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your account is protected with a cloud password. '
            'Enter it below to continue.',
            style: AppTypography.body(color: secondaryColor),
          ),
          const SizedBox(height: 32),

          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            autofocus: true,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
            decoration: InputDecoration(
              hintText: 'Cloud password',
              hintStyle: TextStyle(color: secondaryColor.withOpacity(0.5)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: Icon(Icons.lock_outline, color: AppColors.accent, size: 22),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: secondaryColor,
                  size: 22,
                ),
                onPressed: onToggleObscure,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (authState.errorMessage != null) ...[
            _ErrorBanner(message: authState.errorMessage!),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              onPressed: authState.isSubmitting
                  ? null
                  : () {
                      final pw = passwordController.text.trim();
                      if (pw.isNotEmpty) {
                        controller.submitPassword(pw);
                      }
                    },
              child: authState.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Log In',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ============================================================================
// QR CODE PAGE
// ============================================================================
class _QrCodePage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;

  const _QrCodePage({
    required this.authState,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final qrLink = authState.qrCodeLink;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          const Spacer(),

          Text(
            'Scan QR Code',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Open Telegram on your phone →\n'
            'Settings → Devices → Link Desktop Device',
            style: AppTypography.body(color: secondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // QR code
          if (qrLink != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.08),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: QrImageView(
                data: qrLink,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: Color(0xFF1D1F23),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Color(0xFF1D1F23),
                ),
              ),
            )
          else
            const SizedBox(
              width: 200,
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accent,
                ),
              ),
            ),
          const SizedBox(height: 32),

          TextButton(
            onPressed: () => controller.reset(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: secondaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR PAGE
// ============================================================================
class _ErrorPage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;

  const _ErrorPage({
    required this.authState,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Something went wrong',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            authState.errorMessage ?? 'An unknown error occurred.',
            style: AppTypography.body(color: secondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              onPressed: () => controller.reset(),
              child: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SHARED: Error banner
// ============================================================================
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.25), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.actionCount(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
