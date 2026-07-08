import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Initializes services before running the app.
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  try {
    // Initialize DB
    container.read(databaseProvider);
    // Initialize TDLib Service and start Updates Isolate asynchronously
    await container.read(tdlibServiceProvider).initialize().catchError((
      e,
      stack,
    ) {
      debugPrint('TDLib initialization error: $e\n$stack');
    });
  } catch (e, stack) {
    debugPrint('Bootstrap initialization error: $e\n$stack');
  }

  return container;
}
