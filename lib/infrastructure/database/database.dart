import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:gramx/infrastructure/database/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Accounts, Channels, Posts, MediaItems, BookmarkEntries, Folders, FolderChannels])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'gramx_db');
  }
}
