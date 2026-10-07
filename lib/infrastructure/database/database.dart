import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:gramx/infrastructure/database/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Accounts, BookmarkEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 3) {
          for (final table in allTables) {
            await m.drop(table);
          }
          await m.createAll();
          return;
        }
        // v4 and v5 only add columns. Bookmark rows are kept because they
        // point at their copies in Saved Messages.
        if (from < 4) {
          await m.addColumn(bookmarkEntries, bookmarkEntries.savedMessageId);
        }
        if (from < 5) {
          await m.addColumn(bookmarkEntries, bookmarkEntries.isRestored);
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'gramx_db');
  }
}
