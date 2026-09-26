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

  /// The id of this post's copy in Saved Messages, when there is one.
  ///
  /// A bookmark used to be a row here and nothing else, so it died with the
  /// install and never followed the account to a second device. Telegram's own
  /// durable "save" is a forward to Saved Messages, so that is what a bookmark
  /// now is; this is the handle needed to take it back out again.
  ///
  /// Null for a bookmark whose mirror could not be written — an offline tap, a
  /// flood wait. The local row still stands, and the mirror is not retried:
  /// a bookmark is not worth a queue.
  IntColumn get savedMessageId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {accountId, chatId, messageId},
  ];
}
