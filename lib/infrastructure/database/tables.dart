import 'package:drift/drift.dart';

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get telegramUserId => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get username => text().nullable()();
  TextColumn get phoneNumber => text().nullable()();
  TextColumn get avatarPath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class BookmarkEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get chatId => integer()(); // TDLib chat ID
  IntColumn get messageId => integer()(); // TDLib message ID

  /// The id of this post's copy in Saved Messages, which is how a bookmark
  /// syncs across devices. Null if the copy could not be written (offline or
  /// flood wait); that is not retried.
  IntColumn get savedMessageId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {accountId, chatId, messageId},
  ];
}
