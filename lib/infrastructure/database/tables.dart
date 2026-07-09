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

@DataClassName('ChannelEntry')
class Channels extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get chatId => integer()();
  TextColumn get title => text()();
  TextColumn get username => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get avatarColor => text().nullable()();
  IntColumn get subscriberCount => integer().withDefault(const Constant(0))();
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  IntColumn get lastReadInboxMessageId => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPostAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{accountId, chatId}];
}

@DataClassName('FolderEntry')
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get folderId => integer()();
  TextColumn get title => text()();

  @override
  List<Set<Column>> get uniqueKeys => [{accountId, folderId}];
}

class FolderChannels extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get folderDbId => integer().references(Folders, #id)();
  IntColumn get channelDbId => integer().references(Channels, #id)();

  @override
  List<Set<Column>> get uniqueKeys => [{folderDbId, channelDbId}];
}

@DataClassName('PostEntry')
class Posts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get channelId => integer().references(Channels, #id)();
  IntColumn get messageId => integer()();
  TextColumn get body => text().nullable()();
  DateTimeColumn get publishedAt => dateTime()();
  IntColumn get viewCount => integer().withDefault(const Constant(0))();
  IntColumn get replyCount => integer().withDefault(const Constant(0))();
  IntColumn get forwardCount => integer().withDefault(const Constant(0))();
  TextColumn get reactionsJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isBookmarked => boolean().withDefault(const Constant(false))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get linkPreviewUrl => text().nullable()();
  TextColumn get linkPreviewTitle => text().nullable()();
  TextColumn get linkPreviewDescription => text().nullable()();
  TextColumn get linkPreviewImageUrl => text().nullable()();
  TextColumn get forwardedFromTitle => text().nullable()();
  TextColumn get forwardedFromUsername => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{accountId, channelId, messageId}];
}

@DataClassName('MediaItemEntry')
class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get postId => integer().references(Posts, #id)();
  TextColumn get type => text()();
  TextColumn get url => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  IntColumn get duration => integer().withDefault(const Constant(0))();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
  TextColumn get fileName => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  TextColumn get localPath => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class BookmarkEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get postId => integer().references(Posts, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{accountId, postId}];
}
