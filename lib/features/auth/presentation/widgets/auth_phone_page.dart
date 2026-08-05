import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/features/auth/presentation/widgets/auth_inline_error_banner.dart';

class AuthPhonePage extends StatefulWidget {
  final AuthState authState;
  final AuthController controller;
  final TextEditingController phoneController;

  const AuthPhonePage({
    super.key,
    required this.authState,
    required this.controller,
    required this.phoneController,
  });

  @override
  State<AuthPhonePage> createState() => _AuthPhonePageState();
}

class _AuthPhonePageState extends State<AuthPhonePage> {
  String _selectedCountryCode = '+1';
  String _selectedCountryFlag = '🇺🇸';
  String _selectedCountryName = 'United States';

  @override
  void initState() {
    super.initState();
    widget.phoneController.addListener(_onPhoneChanged);
    _onPhoneChanged();
  }

  @override
  void didUpdateWidget(AuthPhonePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phoneController != widget.phoneController) {
      oldWidget.phoneController.removeListener(_onPhoneChanged);
      widget.phoneController.addListener(_onPhoneChanged);
    }
  }

  @override
  void dispose() {
    widget.phoneController.removeListener(_onPhoneChanged);
    super.dispose();
  }

  void _onPhoneChanged() {
    final text = widget.phoneController.text.trim();
    if (text.isEmpty) return;

    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return;

    Country? matchedCountry;
    for (int len = digits.length < 4 ? digits.length : 4; len >= 1; len--) {
      final codeCandidate = digits.substring(0, len);
      final country = CountryParser.tryParsePhoneCode(codeCandidate);
      if (country != null) {
        matchedCountry = country;
        break;
      }
    }

    if (matchedCountry != null) {
      final newCode = '+${matchedCountry.phoneCode}';
      if (_selectedCountryCode != newCode) {
        setState(() {
          _selectedCountryCode = newCode;
          _selectedCountryFlag = matchedCountry!.flagEmoji;
          _selectedCountryName = matchedCountry.name;
        });
      }
    }
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      searchAutofocus: true,
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
            AuthInlineErrorBanner(message: widget.authState.errorMessage!),
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
                      if (phone.isNotEmpty) {
                        if (!phone.startsWith('+')) {
                          final rawCc = _selectedCountryCode.replaceAll('+', '');
                          if (phone.startsWith(rawCc)) {
                            phone = '+$phone';
                          } else {
                            phone = '$_selectedCountryCode$phone';
                          }
                        }
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
