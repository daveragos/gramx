import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:gramx/infrastructure/database/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Accounts, Channels, Posts, MediaItems, BookmarkEntries, Folders, FolderChannels])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // Drop and recreate all tables in development to handle schema modifications easily
        for (final table in allTables) {
          await m.drop(table);
        }
        await m.createAll();
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'gramx_db');
  }
}
