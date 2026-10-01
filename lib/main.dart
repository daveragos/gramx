import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/app.dart';
import 'package:gramx/app/bootstrap.dart';
import 'package:gramx/core/diagnostics/error_handlers.dart';
import 'package:gramx/core/diagnostics/error_log.dart';
import 'package:gramx/core/diagnostics/startup_trace.dart';

void main() {
  // Installed first so errors thrown during startup are captured too.
  ErrorHandlers.install();
  StartupTrace.mark('Dart started');

  // `bootstrap()` initialises the binding, which Flutter requires to be in the
  // same zone as `runApp`.
  runZonedGuarded(() async {
    final container = await bootstrap();

    ErrorHandlers.connect(
      (error, stack, source) => container
          .read(errorLogProvider.notifier)
          .record(error, stack: stack, source: source),
    );

    runApp(
      UncontrolledProviderScope(container: container, child: const GramXApp()),
    );
  }, ErrorHandlers.onZoneError);
}
