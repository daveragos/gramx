import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/app.dart';
import 'package:gramx/app/bootstrap.dart';
import 'package:gramx/core/diagnostics/error_handlers.dart';
import 'package:gramx/core/diagnostics/error_log.dart';
import 'package:gramx/core/diagnostics/startup_trace.dart';

void main() {
  // Before anything else, including the binding: the errors most worth having
  // are the ones thrown while starting up, and they are also the only ones a
  // reader can never describe, because the app never got far enough to show
  // them anything.
  ErrorHandlers.install();
  StartupTrace.mark('Dart started');

  // `bootstrap()` initialises the binding, so it has to run inside this zone —
  // Flutter requires the binding and `runApp` to share one, and a mismatch is
  // reported as an error of its own.
  runZonedGuarded(() async {
    final container = await bootstrap();

    ErrorHandlers.connect(
      (error, stack, source) => container
          .read(errorLogProvider.notifier)
          .record(error, stack: stack, source: source),
    );

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const GramXApp(),
      ),
    );
  }, ErrorHandlers.onZoneError);
}
