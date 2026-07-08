import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/app.dart';
import 'package:gramx/app/bootstrap.dart';

void main() async {
  final container = await bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GramXApp(),
    ),
  );
}
