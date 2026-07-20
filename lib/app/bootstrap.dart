import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/auth/presentation/auth_providers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Initializes services before running the app.
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Initialize TDLib Service and start Updates Isolate asynchronously.
  // We await this so auth state is available before the first frame renders.
  try {
    await container.read(tdlibServiceProvider).initialize();
  } catch (e, stack) {
    debugPrint('TDLib initialization error: $e\n$stack');
  }

  // Eagerly prime the AuthController so it subscribes to TDLib auth events
  // BEFORE the first frame. Without this, the auth subscription only starts
  // when a widget reads authControllerProvider — which may never happen if
  // the router hasn't redirected to /auth yet.
  container.read(authControllerProvider);

  return container;
}
