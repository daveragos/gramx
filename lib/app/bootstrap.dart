import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gramx/infrastructure/database/database_provider.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Initializes services before running the app.
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  try {
    // Initialize DB
    final db = container.read(databaseProvider);
    
    // One-off cleanup of old mock data from Milestone 1 using a local file marker
    final appDir = await getApplicationDocumentsDirectory();
    final markerFile = File('${appDir.path}/.mock_cleared_marker');
    if (!markerFile.existsSync()) {
      await db.customStatement('DELETE FROM bookmark_entries');
      await db.customStatement('DELETE FROM media_items');
      await db.customStatement('DELETE FROM posts');
      await db.customStatement('DELETE FROM channels');
      await db.customStatement('DELETE FROM accounts');
      await markerFile.create();
      debugPrint('[Bootstrap] Executed one-off cleanup of database.');
    }
    
    // Initialize TDLib Service and start Updates Isolate asynchronously
    container.read(tdlibServiceProvider).initialize().catchError((e, stack) {
      debugPrint('TDLib initialization error: $e\n$stack');
    });
  } catch (e, stack) {
    debugPrint('Bootstrap initialization error: $e\n$stack');
  }

  return container;
}
