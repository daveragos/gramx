import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:gramx/infrastructure/database/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Accounts, BookmarkEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // v4 only adds a column. Bookmark rows are kept because they point at
        // their copies in Saved Messages.
        if (from >= 3) {
          await m.addColumn(bookmarkEntries, bookmarkEntries.savedMessageId);
          return;
        }
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
