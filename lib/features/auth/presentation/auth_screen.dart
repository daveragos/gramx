import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';

/// Fully reimagined page-driven Telegram connection and login workflow.
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(authState, controller, theme),

            // Main Content Body
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildPage(authState, controller, theme),
              ),
            ),

            // Footer Notice
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.lg,
              ),
              child: Text(
                'gramX • Powered by official TDLib MTProto engine\n'
                'No third-party push • No tracking',
                style: AppTypography.actionCount(color: secondaryColor.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    AuthState authState,
    AuthController controller,
    ThemeData theme,
  ) {
    final bool showBack = authState.step != AuthStep.loginMethodSelection &&
        authState.step != AuthStep.loading;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => controller.reset(),
              tooltip: 'Back',
            )
          else
            const SizedBox(width: 48),

          Expanded(
            child: Center(
              child: Text(
                'gramX',
                style: AppTypography.heading(
                  color: AppColors.accent,
                ).copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPage(
    AuthState authState,
    AuthController controller,
    ThemeData theme,
  ) {
    return switch (authState.step) {
      AuthStep.loading => _ReimaginedLoadingPage(
          authState: authState,
          pulseController: _pulseController,
          controller: controller,
        ),
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
      AuthStep.error => _ReimaginedErrorPage(
          authState: authState,
          controller: controller,
        ),
      AuthStep.authenticated => _ReimaginedLoadingPage(
          authState: authState,
          pulseController: _pulseController,
          controller: controller,
        ),
    };
  }
}

// ============================================================================
// REIMAGINED CONNECTING & LOADING PAGE
// ============================================================================
class _ReimaginedLoadingPage extends StatelessWidget {
  final AuthState authState;
  final AnimationController pulseController;
  final AuthController controller;

  const _ReimaginedLoadingPage({
    required this.authState,
    required this.pulseController,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing Brand Icon Glow
            AnimatedBuilder(
              animation: pulseController,
              builder: (context, child) {
                final scale = 1.0 + (pulseController.value * 0.08);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent,
                          AppColors.accent.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(
                            alpha: 0.3 + (pulseController.value * 0.25),
                          ),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 36),

            Text(
              'Connecting to Telegram',
              style: AppTypography.heading(color: theme.colorScheme.onSurface).copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            // Live status message text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                authState.statusMessage,
                key: ValueKey(authState.statusMessage),
                style: AppTypography.body(color: secondaryColor),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 36),

            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 48),

            // Fallback retry button if stuck
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: secondaryColor,
                side: BorderSide(
                  color: secondaryColor.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => controller.resetSession(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Reset Connection',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REIMAGINED ERROR PAGE
// ============================================================================
class _ReimaginedErrorPage extends StatelessWidget {
  final AuthState authState;
  final AuthController controller;

  const _ReimaginedErrorPage({
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Connection Error',
              style: AppTypography.heading(color: primaryColor).copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              authState.errorMessage ?? 'Unable to establish connection with Telegram.',
              style: AppTypography.body(color: secondaryColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                onPressed: () => controller.retryConnection(),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: secondaryColor,
                ),
                onPressed: () => controller.resetSession(),
                icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                label: const Text(
                  'Clean Session & Restart',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
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

          // Logo & Hero
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent,
                  AppColors.accent.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Welcome to gramX',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Telegram channels, as one timeline.',
            style: AppTypography.body(color: secondaryColor),
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 3),

          if (authState.errorMessage != null) ...[
            _ErrorBanner(message: authState.errorMessage!),
            const SizedBox(height: 16),
          ],

          // Phone login button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              onPressed: isSubmitting ? null : () => controller.selectPhoneLogin(),
              icon: const Icon(Icons.phone_android_rounded, size: 20),
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
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
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
                  : const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: Text(
                isSubmitting ? 'Generating QR...' : 'Log in via QR Code',
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

class _PhoneInputPage extends StatefulWidget {
  final AuthState authState;
  final AuthController controller;
  final TextEditingController phoneController;

  const _PhoneInputPage({
    required this.authState,
    required this.controller,
    required this.phoneController,
  });

  @override
  State<_PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<_PhoneInputPage> {
  String _selectedCountryCode = '+1';
  String _selectedCountryFlag = '🇺🇸';
  String _selectedCountryName = 'United States';

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        inputDecoration: InputDecoration(
          labelText: 'Search Country',
          hintText: 'Start typing country name or code...',
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          _selectedCountryCode = '+${country.phoneCode}';
          _selectedCountryFlag = country.flagEmoji;
          _selectedCountryName = country.name;

          final currentText = widget.phoneController.text.trim();
          if (!currentText.startsWith('+')) {
            widget.phoneController.text = '+${country.phoneCode} $currentText';
          }
        });
      },
    );
  }

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

          Text(
            'Enter your phone number',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your country and enter your phone number. We will send a login code to your Telegram app.',
            style: AppTypography.body(color: secondaryColor),
          ),
          const SizedBox(height: 24),

          // Country Selector Button
          GestureDetector(
            onTap: _showCountryPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(_selectedCountryFlag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Text(
                        _selectedCountryName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _selectedCountryCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, color: secondaryColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: widget.phoneController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]')),
            ],
            decoration: InputDecoration(
              hintText: '$_selectedCountryCode 123 456 7890',
              hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.4)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: Icon(Icons.phone_rounded, color: AppColors.accent, size: 22),
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
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (widget.authState.errorMessage != null) ...[
            _ErrorBanner(message: widget.authState.errorMessage!),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              onPressed: widget.authState.isSubmitting
                  ? null
                  : () {
                      var phone = widget.phoneController.text.trim();
                      if (!phone.startsWith('+')) {
                        phone = '$_selectedCountryCode$phone';
                      }
                      if (phone.isNotEmpty) {
                        widget.controller.submitPhoneNumber(phone);
                      }
                    },
              child: widget.authState.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Continue',
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

          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Check your Telegram app',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a login code to your Telegram app'
            '${authState.phoneNumber != null ? ' (${authState.phoneNumber})' : ''}.',
            style: AppTypography.body(color: secondaryColor),
          ),
          const SizedBox(height: 28),

          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 10,
              color: primaryColor,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: TextStyle(
                color: secondaryColor.withValues(alpha: 0.3),
                fontSize: 28,
                letterSpacing: 10,
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
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 1),
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
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
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
                      'Verify Code',
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
// PASSWORD INPUT PAGE (2FA)
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
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Enter your 2FA password',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your account is protected with a cloud password.',
            style: AppTypography.body(color: secondaryColor),
          ),
          const SizedBox(height: 28),

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
              hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: Icon(Icons.lock_rounded, color: AppColors.accent, size: 22),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
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
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 1),
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
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              onPressed: authState.isSubmitting
                  ? null
                  : () {
                      final pwd = passwordController.text.trim();
                      if (pwd.isNotEmpty) {
                        controller.submitPassword(pwd);
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
    final link = authState.qrCodeLink;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          const Spacer(),

          Text(
            'Scan QR Code',
            style: AppTypography.heading(color: primaryColor).copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open Telegram on your mobile device:\n'
            'Settings → Devices → Link Desktop Device',
            style: AppTypography.body(color: secondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: link != null && link.isNotEmpty
                ? QrImageView(
                    data: link,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  )
                : const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          if (authState.errorMessage != null) ...[
            _ErrorBanner(message: authState.errorMessage!),
            const SizedBox(height: 16),
          ],

          TextButton.icon(
            onPressed: () => controller.requestQrLogin(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh QR Code'),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
