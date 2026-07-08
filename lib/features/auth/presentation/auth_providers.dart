import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// State of the authentication flow.
enum AuthStep {
  loading,
  loginMethodSelection, // Phone vs QR selection
  waitPhoneNumber,
  waitCode,
  waitPassword,
  waitQrCode,
  authenticated,
  error,
}

class AuthState {
  final AuthStep step;
  final String? phoneNumber;
  final String? qrCodeLink;
  final String? errorMessage;
  final bool isSubmitting;

  AuthState({
    required this.step,
    this.phoneNumber,
    this.qrCodeLink,
    this.errorMessage,
    this.isSubmitting = false,
  });

  AuthState copyWith({
    AuthStep? step,
    String? phoneNumber,
    String? qrCodeLink,
    String? errorMessage,
    bool? isSubmitting,
  }) {
    return AuthState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      qrCodeLink: qrCodeLink ?? this.qrCodeLink,
      errorMessage: errorMessage ?? this.errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// Provides the current raw TDLib AuthorizationState stream.
final telegramAuthStateProvider = StreamProvider<td.AuthorizationState>((ref) {
  final tdlib = ref.watch(tdlibServiceProvider);
  return tdlib.authStateStream;
});

class AuthController extends Notifier<AuthState> {
  late final TdlibService _tdlib;
  StreamSubscription? _authSub;

  @override
  AuthState build() {
    _tdlib = ref.watch(tdlibServiceProvider);
    
    // Automatically listen to auth updates
    _authSub = _tdlib.authStateStream.listen((tdState) {
      _mapTdlibStateToStep(tdState);
    });
    
    ref.onDispose(() {
      _authSub?.cancel();
    });

    return AuthState(step: AuthStep.loading);
  }

  void _mapTdlibStateToStep(td.AuthorizationState tdState) {
    debugPrint('[AuthCtrl] Mapping TDLib State: ${tdState.runtimeType}');
    if (tdState is td.AuthorizationStateWaitPhoneNumber) {
      state = AuthState(step: AuthStep.waitPhoneNumber);
    } else if (tdState is td.AuthorizationStateWaitCode) {
      state = state.copyWith(step: AuthStep.waitCode);
    } else if (tdState is td.AuthorizationStateWaitPassword) {
      state = state.copyWith(step: AuthStep.waitPassword);
    } else if (tdState is td.AuthorizationStateWaitOtherDeviceConfirmation) {
      state = state.copyWith(
        step: AuthStep.waitQrCode,
        qrCodeLink: tdState.link,
      );
    } else if (tdState is td.AuthorizationStateReady) {
      state = state.copyWith(step: AuthStep.authenticated);
    }
  }

  /// Start Phone Number login flow
  Future<void> submitPhoneNumber(String phone) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final request = td.SetAuthenticationPhoneNumber(
        phoneNumber: phone,
        settings: td.PhoneNumberAuthenticationSettings(
          allowFlashCall: false,
          allowMissedCall: false,
          isCurrentPhoneNumber: false,
          allowSmsRetrieverApi: false,
          hasUnknownPhoneNumber: false,
          authenticationTokens: [],
        ),
      );
      // Send directly via TDLib service
      _tdlib.sendRequest(request);
      state = state.copyWith(phoneNumber: phone, isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false, 
        errorMessage: 'Failed to submit phone number: $e',
      );
    }
  }

  /// Start QR Code login flow
  Future<void> requestQrLogin() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      // In TDLib, requestQrCodeAuthentication has type TdFunction
      // It initiates the other device confirmation flow
      // We pass empty other_user_ids
      final request = td.RequestQrCodeAuthentication(otherUserIds: []);
      _tdlib.sendRequest(request);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to request QR login: $e',
      );
    }
  }

  /// Submit verification code
  Future<void> submitCode(String code) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final request = td.CheckAuthenticationCode(code: code);
      _tdlib.sendRequest(request);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Invalid verification code: $e',
      );
    }
  }

  /// Submit 2FA password
  Future<void> submitPassword(String password) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final request = td.CheckAuthenticationPassword(password: password);
      _tdlib.sendRequest(request);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Incorrect password: $e',
      );
    }
  }

  /// Reset state to return to login method selection
  void reset() {
    state = AuthState(step: AuthStep.loginMethodSelection);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
