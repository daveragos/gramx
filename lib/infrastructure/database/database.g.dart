// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _telegramUserIdMeta = const VerificationMeta(
    'telegramUserId',
  );
  @override
  late final GeneratedColumn<String> telegramUserId = GeneratedColumn<String>(
    'telegram_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneNumberMeta = const VerificationMeta(
    'phoneNumber',
  );
  @override
  late final GeneratedColumn<String> phoneNumber = GeneratedColumn<String>(
    'phone_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarPathMeta = const VerificationMeta(
    'avatarPath',
  );
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
    'avatar_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    telegramUserId,
    displayName,
    username,
    phoneNumber,
    avatarPath,
    isActive,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('telegram_user_id')) {
      context.handle(
        _telegramUserIdMeta,
        telegramUserId.isAcceptableOrUnknown(
          data['telegram_user_id']!,
          _telegramUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_telegramUserIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('phone_number')) {
      context.handle(
        _phoneNumberMeta,
        phoneNumber.isAcceptableOrUnknown(
          data['phone_number']!,
          _phoneNumberMeta,
        ),
      );
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
        _avatarPathMeta,
        avatarPath.isAcceptableOrUnknown(data['avatar_path']!, _avatarPathMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      telegramUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}telegram_user_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      phoneNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_number'],
      ),
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final int id;
  final String telegramUserId;
  final String? displayName;
  final String? username;
  final String? phoneNumber;
  final String? avatarPath;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Account({
    required this.id,
    required this.telegramUserId,
    this.displayName,
    this.username,
    this.phoneNumber,
    this.avatarPath,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['telegram_user_id'] = Variable<String>(telegramUserId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || phoneNumber != null) {
      map['phone_number'] = Variable<String>(phoneNumber);
    }
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      telegramUserId: Value(telegramUserId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      phoneNumber: phoneNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(phoneNumber),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<int>(json['id']),
      telegramUserId: serializer.fromJson<String>(json['telegramUserId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      username: serializer.fromJson<String?>(json['username']),
      phoneNumber: serializer.fromJson<String?>(json['phoneNumber']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'telegramUserId': serializer.toJson<String>(telegramUserId),
      'displayName': serializer.toJson<String?>(displayName),
      'username': serializer.toJson<String?>(username),
      'phoneNumber': serializer.toJson<String?>(phoneNumber),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Account copyWith({
    int? id,
    String? telegramUserId,
    Value<String?> displayName = const Value.absent(),
    Value<String?> username = const Value.absent(),
    Value<String?> phoneNumber = const Value.absent(),
    Value<String?> avatarPath = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Account(
    id: id ?? this.id,
    telegramUserId: telegramUserId ?? this.telegramUserId,
    displayName: displayName.present ? displayName.value : this.displayName,
    username: username.present ? username.value : this.username,
    phoneNumber: phoneNumber.present ? phoneNumber.value : this.phoneNumber,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      telegramUserId: data.telegramUserId.present
          ? data.telegramUserId.value
          : this.telegramUserId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      username: data.username.present ? data.username.value : this.username,
      phoneNumber: data.phoneNumber.present
          ? data.phoneNumber.value
          : this.phoneNumber,
      avatarPath: data.avatarPath.present
          ? data.avatarPath.value
          : this.avatarPath,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('telegramUserId: $telegramUserId, ')
          ..write('displayName: $displayName, ')
          ..write('username: $username, ')
          ..write('phoneNumber: $phoneNumber, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    telegramUserId,
    displayName,
    username,
    phoneNumber,
    avatarPath,
    isActive,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.telegramUserId == this.telegramUserId &&
          other.displayName == this.displayName &&
          other.username == this.username &&
          other.phoneNumber == this.phoneNumber &&
          other.avatarPath == this.avatarPath &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> id;
  final Value<String> telegramUserId;
  final Value<String?> displayName;
  final Value<String?> username;
  final Value<String?> phoneNumber;
  final Value<String?> avatarPath;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.telegramUserId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.username = const Value.absent(),
    this.phoneNumber = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required String telegramUserId,
    this.displayName = const Value.absent(),
    this.username = const Value.absent(),
    this.phoneNumber = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : telegramUserId = Value(telegramUserId);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<String>? telegramUserId,
    Expression<String>? displayName,
    Expression<String>? username,
    Expression<String>? phoneNumber,
    Expression<String>? avatarPath,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (telegramUserId != null) 'telegram_user_id': telegramUserId,
      if (displayName != null) 'display_name': displayName,
      if (username != null) 'username': username,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AccountsCompanion copyWith({
    Value<int>? id,
    Value<String>? telegramUserId,
    Value<String?>? displayName,
    Value<String?>? username,
    Value<String?>? phoneNumber,
    Value<String?>? avatarPath,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      telegramUserId: telegramUserId ?? this.telegramUserId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarPath: avatarPath ?? this.avatarPath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (telegramUserId.present) {
      map['telegram_user_id'] = Variable<String>(telegramUserId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (phoneNumber.present) {
      map['phone_number'] = Variable<String>(phoneNumber.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('telegramUserId: $telegramUserId, ')
          ..write('displayName: $displayName, ')
          ..write('username: $username, ')
          ..write('phoneNumber: $phoneNumber, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ChannelsTable extends Channels
    with TableInfo<$ChannelsTable, ChannelEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<int> chatId = GeneratedColumn<int>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarColorMeta = const VerificationMeta(
    'avatarColor',
  );
  @override
  late final GeneratedColumn<String> avatarColor = GeneratedColumn<String>(
    'avatar_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subscriberCountMeta = const VerificationMeta(
    'subscriberCount',
  );
  @override
  late final GeneratedColumn<int> subscriberCount = GeneratedColumn<int>(
    'subscriber_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isVerifiedMeta = const VerificationMeta(
    'isVerified',
  );
  @override
  late final GeneratedColumn<bool> isVerified = GeneratedColumn<bool>(
    'is_verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_verified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isMutedMeta = const VerificationMeta(
    'isMuted',
  );
  @override
  late final GeneratedColumn<bool> isMuted = GeneratedColumn<bool>(
    'is_muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastReadInboxMessageIdMeta =
      const VerificationMeta('lastReadInboxMessageId');
  @override
  late final GeneratedColumn<int> lastReadInboxMessageId = GeneratedColumn<int>(
    'last_read_inbox_message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPostAtMeta = const VerificationMeta(
    'lastPostAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPostAt = GeneratedColumn<DateTime>(
    'last_post_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    chatId,
    title,
    username,
    description,
    avatarUrl,
    avatarColor,
    subscriberCount,
    isVerified,
    isFavorite,
    isMuted,
    isHidden,
    lastReadInboxMessageId,
    lastPostAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChannelEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('avatar_color')) {
      context.handle(
        _avatarColorMeta,
        avatarColor.isAcceptableOrUnknown(
          data['avatar_color']!,
          _avatarColorMeta,
        ),
      );
    }
    if (data.containsKey('subscriber_count')) {
      context.handle(
        _subscriberCountMeta,
        subscriberCount.isAcceptableOrUnknown(
          data['subscriber_count']!,
          _subscriberCountMeta,
        ),
      );
    }
    if (data.containsKey('is_verified')) {
      context.handle(
        _isVerifiedMeta,
        isVerified.isAcceptableOrUnknown(data['is_verified']!, _isVerifiedMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('is_muted')) {
      context.handle(
        _isMutedMeta,
        isMuted.isAcceptableOrUnknown(data['is_muted']!, _isMutedMeta),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    if (data.containsKey('last_read_inbox_message_id')) {
      context.handle(
        _lastReadInboxMessageIdMeta,
        lastReadInboxMessageId.isAcceptableOrUnknown(
          data['last_read_inbox_message_id']!,
          _lastReadInboxMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('last_post_at')) {
      context.handle(
        _lastPostAtMeta,
        lastPostAt.isAcceptableOrUnknown(
          data['last_post_at']!,
          _lastPostAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountId, chatId},
  ];
  @override
  ChannelEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChannelEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chat_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      avatarColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_color'],
      ),
      subscriberCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subscriber_count'],
      )!,
      isVerified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_verified'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      isMuted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_muted'],
      )!,
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
      lastReadInboxMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_inbox_message_id'],
      )!,
      lastPostAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_post_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChannelsTable createAlias(String alias) {
    return $ChannelsTable(attachedDatabase, alias);
  }
}

class ChannelEntry extends DataClass implements Insertable<ChannelEntry> {
  final int id;
  final int accountId;
  final int chatId;
  final String title;
  final String? username;
  final String? description;
  final String? avatarUrl;
  final String? avatarColor;
  final int subscriberCount;
  final bool isVerified;
  final bool isFavorite;
  final bool isMuted;
  final bool isHidden;
  final int lastReadInboxMessageId;
  final DateTime? lastPostAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChannelEntry({
    required this.id,
    required this.accountId,
    required this.chatId,
    required this.title,
    this.username,
    this.description,
    this.avatarUrl,
    this.avatarColor,
    required this.subscriberCount,
    required this.isVerified,
    required this.isFavorite,
    required this.isMuted,
    required this.isHidden,
    required this.lastReadInboxMessageId,
    this.lastPostAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['chat_id'] = Variable<int>(chatId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    if (!nullToAbsent || avatarColor != null) {
      map['avatar_color'] = Variable<String>(avatarColor);
    }
    map['subscriber_count'] = Variable<int>(subscriberCount);
    map['is_verified'] = Variable<bool>(isVerified);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_muted'] = Variable<bool>(isMuted);
    map['is_hidden'] = Variable<bool>(isHidden);
    map['last_read_inbox_message_id'] = Variable<int>(lastReadInboxMessageId);
    if (!nullToAbsent || lastPostAt != null) {
      map['last_post_at'] = Variable<DateTime>(lastPostAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChannelsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      chatId: Value(chatId),
      title: Value(title),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      avatarColor: avatarColor == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarColor),
      subscriberCount: Value(subscriberCount),
      isVerified: Value(isVerified),
      isFavorite: Value(isFavorite),
      isMuted: Value(isMuted),
      isHidden: Value(isHidden),
      lastReadInboxMessageId: Value(lastReadInboxMessageId),
      lastPostAt: lastPostAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPostAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChannelEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChannelEntry(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      chatId: serializer.fromJson<int>(json['chatId']),
      title: serializer.fromJson<String>(json['title']),
      username: serializer.fromJson<String?>(json['username']),
      description: serializer.fromJson<String?>(json['description']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      avatarColor: serializer.fromJson<String?>(json['avatarColor']),
      subscriberCount: serializer.fromJson<int>(json['subscriberCount']),
      isVerified: serializer.fromJson<bool>(json['isVerified']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isMuted: serializer.fromJson<bool>(json['isMuted']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
      lastReadInboxMessageId: serializer.fromJson<int>(
        json['lastReadInboxMessageId'],
      ),
      lastPostAt: serializer.fromJson<DateTime?>(json['lastPostAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'chatId': serializer.toJson<int>(chatId),
      'title': serializer.toJson<String>(title),
      'username': serializer.toJson<String?>(username),
      'description': serializer.toJson<String?>(description),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'avatarColor': serializer.toJson<String?>(avatarColor),
      'subscriberCount': serializer.toJson<int>(subscriberCount),
      'isVerified': serializer.toJson<bool>(isVerified),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isMuted': serializer.toJson<bool>(isMuted),
      'isHidden': serializer.toJson<bool>(isHidden),
      'lastReadInboxMessageId': serializer.toJson<int>(lastReadInboxMessageId),
      'lastPostAt': serializer.toJson<DateTime?>(lastPostAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChannelEntry copyWith({
    int? id,
    int? accountId,
    int? chatId,
    String? title,
    Value<String?> username = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
    Value<String?> avatarColor = const Value.absent(),
    int? subscriberCount,
    bool? isVerified,
    bool? isFavorite,
    bool? isMuted,
    bool? isHidden,
    int? lastReadInboxMessageId,
    Value<DateTime?> lastPostAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChannelEntry(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    chatId: chatId ?? this.chatId,
    title: title ?? this.title,
    username: username.present ? username.value : this.username,
    description: description.present ? description.value : this.description,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    avatarColor: avatarColor.present ? avatarColor.value : this.avatarColor,
    subscriberCount: subscriberCount ?? this.subscriberCount,
    isVerified: isVerified ?? this.isVerified,
    isFavorite: isFavorite ?? this.isFavorite,
    isMuted: isMuted ?? this.isMuted,
    isHidden: isHidden ?? this.isHidden,
    lastReadInboxMessageId:
        lastReadInboxMessageId ?? this.lastReadInboxMessageId,
    lastPostAt: lastPostAt.present ? lastPostAt.value : this.lastPostAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChannelEntry copyWithCompanion(ChannelsCompanion data) {
    return ChannelEntry(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      title: data.title.present ? data.title.value : this.title,
      username: data.username.present ? data.username.value : this.username,
      description: data.description.present
          ? data.description.value
          : this.description,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      avatarColor: data.avatarColor.present
          ? data.avatarColor.value
          : this.avatarColor,
      subscriberCount: data.subscriberCount.present
          ? data.subscriberCount.value
          : this.subscriberCount,
      isVerified: data.isVerified.present
          ? data.isVerified.value
          : this.isVerified,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      isMuted: data.isMuted.present ? data.isMuted.value : this.isMuted,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
      lastReadInboxMessageId: data.lastReadInboxMessageId.present
          ? data.lastReadInboxMessageId.value
          : this.lastReadInboxMessageId,
      lastPostAt: data.lastPostAt.present
          ? data.lastPostAt.value
          : this.lastPostAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChannelEntry(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('chatId: $chatId, ')
          ..write('title: $title, ')
          ..write('username: $username, ')
          ..write('description: $description, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('avatarColor: $avatarColor, ')
          ..write('subscriberCount: $subscriberCount, ')
          ..write('isVerified: $isVerified, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isMuted: $isMuted, ')
          ..write('isHidden: $isHidden, ')
          ..write('lastReadInboxMessageId: $lastReadInboxMessageId, ')
          ..write('lastPostAt: $lastPostAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    chatId,
    title,
    username,
    description,
    avatarUrl,
    avatarColor,
    subscriberCount,
    isVerified,
    isFavorite,
    isMuted,
    isHidden,
    lastReadInboxMessageId,
    lastPostAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelEntry &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.chatId == this.chatId &&
          other.title == this.title &&
          other.username == this.username &&
          other.description == this.description &&
          other.avatarUrl == this.avatarUrl &&
          other.avatarColor == this.avatarColor &&
          other.subscriberCount == this.subscriberCount &&
          other.isVerified == this.isVerified &&
          other.isFavorite == this.isFavorite &&
          other.isMuted == this.isMuted &&
          other.isHidden == this.isHidden &&
          other.lastReadInboxMessageId == this.lastReadInboxMessageId &&
          other.lastPostAt == this.lastPostAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChannelsCompanion extends UpdateCompanion<ChannelEntry> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<int> chatId;
  final Value<String> title;
  final Value<String?> username;
  final Value<String?> description;
  final Value<String?> avatarUrl;
  final Value<String?> avatarColor;
  final Value<int> subscriberCount;
  final Value<bool> isVerified;
  final Value<bool> isFavorite;
  final Value<bool> isMuted;
  final Value<bool> isHidden;
  final Value<int> lastReadInboxMessageId;
  final Value<DateTime?> lastPostAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ChannelsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.chatId = const Value.absent(),
    this.title = const Value.absent(),
    this.username = const Value.absent(),
    this.description = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.avatarColor = const Value.absent(),
    this.subscriberCount = const Value.absent(),
    this.isVerified = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.lastReadInboxMessageId = const Value.absent(),
    this.lastPostAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ChannelsCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required int chatId,
    required String title,
    this.username = const Value.absent(),
    this.description = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.avatarColor = const Value.absent(),
    this.subscriberCount = const Value.absent(),
    this.isVerified = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.lastReadInboxMessageId = const Value.absent(),
    this.lastPostAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : accountId = Value(accountId),
       chatId = Value(chatId),
       title = Value(title);
  static Insertable<ChannelEntry> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<int>? chatId,
    Expression<String>? title,
    Expression<String>? username,
    Expression<String>? description,
    Expression<String>? avatarUrl,
    Expression<String>? avatarColor,
    Expression<int>? subscriberCount,
    Expression<bool>? isVerified,
    Expression<bool>? isFavorite,
    Expression<bool>? isMuted,
    Expression<bool>? isHidden,
    Expression<int>? lastReadInboxMessageId,
    Expression<DateTime>? lastPostAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (chatId != null) 'chat_id': chatId,
      if (title != null) 'title': title,
      if (username != null) 'username': username,
      if (description != null) 'description': description,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (avatarColor != null) 'avatar_color': avatarColor,
      if (subscriberCount != null) 'subscriber_count': subscriberCount,
      if (isVerified != null) 'is_verified': isVerified,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isMuted != null) 'is_muted': isMuted,
      if (isHidden != null) 'is_hidden': isHidden,
      if (lastReadInboxMessageId != null)
        'last_read_inbox_message_id': lastReadInboxMessageId,
      if (lastPostAt != null) 'last_post_at': lastPostAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ChannelsCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<int>? chatId,
    Value<String>? title,
    Value<String?>? username,
    Value<String?>? description,
    Value<String?>? avatarUrl,
    Value<String?>? avatarColor,
    Value<int>? subscriberCount,
    Value<bool>? isVerified,
    Value<bool>? isFavorite,
    Value<bool>? isMuted,
    Value<bool>? isHidden,
    Value<int>? lastReadInboxMessageId,
    Value<DateTime?>? lastPostAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ChannelsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      chatId: chatId ?? this.chatId,
      title: title ?? this.title,
      username: username ?? this.username,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarColor: avatarColor ?? this.avatarColor,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      isVerified: isVerified ?? this.isVerified,
      isFavorite: isFavorite ?? this.isFavorite,
      isMuted: isMuted ?? this.isMuted,
      isHidden: isHidden ?? this.isHidden,
      lastReadInboxMessageId:
          lastReadInboxMessageId ?? this.lastReadInboxMessageId,
      lastPostAt: lastPostAt ?? this.lastPostAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<int>(chatId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (avatarColor.present) {
      map['avatar_color'] = Variable<String>(avatarColor.value);
    }
    if (subscriberCount.present) {
      map['subscriber_count'] = Variable<int>(subscriberCount.value);
    }
    if (isVerified.present) {
      map['is_verified'] = Variable<bool>(isVerified.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isMuted.present) {
      map['is_muted'] = Variable<bool>(isMuted.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (lastReadInboxMessageId.present) {
      map['last_read_inbox_message_id'] = Variable<int>(
        lastReadInboxMessageId.value,
      );
    }
    if (lastPostAt.present) {
      map['last_post_at'] = Variable<DateTime>(lastPostAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('chatId: $chatId, ')
          ..write('title: $title, ')
          ..write('username: $username, ')
          ..write('description: $description, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('avatarColor: $avatarColor, ')
          ..write('subscriberCount: $subscriberCount, ')
          ..write('isVerified: $isVerified, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isMuted: $isMuted, ')
          ..write('isHidden: $isHidden, ')
          ..write('lastReadInboxMessageId: $lastReadInboxMessageId, ')
          ..write('lastPostAt: $lastPostAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PostsTable extends Posts with TableInfo<$PostsTable, PostEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<int> channelId = GeneratedColumn<int>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES channels (id)',
    ),
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viewCountMeta = const VerificationMeta(
    'viewCount',
  );
  @override
  late final GeneratedColumn<int> viewCount = GeneratedColumn<int>(
    'view_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _replyCountMeta = const VerificationMeta(
    'replyCount',
  );
  @override
  late final GeneratedColumn<int> replyCount = GeneratedColumn<int>(
    'reply_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _forwardCountMeta = const VerificationMeta(
    'forwardCount',
  );
  @override
  late final GeneratedColumn<int> forwardCount = GeneratedColumn<int>(
    'forward_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reactionsJsonMeta = const VerificationMeta(
    'reactionsJson',
  );
  @override
  late final GeneratedColumn<String> reactionsJson = GeneratedColumn<String>(
    'reactions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _isBookmarkedMeta = const VerificationMeta(
    'isBookmarked',
  );
  @override
  late final GeneratedColumn<bool> isBookmarked = GeneratedColumn<bool>(
    'is_bookmarked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_bookmarked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _linkPreviewUrlMeta = const VerificationMeta(
    'linkPreviewUrl',
  );
  @override
  late final GeneratedColumn<String> linkPreviewUrl = GeneratedColumn<String>(
    'link_preview_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkPreviewTitleMeta = const VerificationMeta(
    'linkPreviewTitle',
  );
  @override
  late final GeneratedColumn<String> linkPreviewTitle = GeneratedColumn<String>(
    'link_preview_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkPreviewDescriptionMeta =
      const VerificationMeta('linkPreviewDescription');
  @override
  late final GeneratedColumn<String> linkPreviewDescription =
      GeneratedColumn<String>(
        'link_preview_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _linkPreviewImageUrlMeta =
      const VerificationMeta('linkPreviewImageUrl');
  @override
  late final GeneratedColumn<String> linkPreviewImageUrl =
      GeneratedColumn<String>(
        'link_preview_image_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _forwardedFromTitleMeta =
      const VerificationMeta('forwardedFromTitle');
  @override
  late final GeneratedColumn<String> forwardedFromTitle =
      GeneratedColumn<String>(
        'forwarded_from_title',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _forwardedFromUsernameMeta =
      const VerificationMeta('forwardedFromUsername');
  @override
  late final GeneratedColumn<String> forwardedFromUsername =
      GeneratedColumn<String>(
        'forwarded_from_username',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    channelId,
    messageId,
    body,
    publishedAt,
    viewCount,
    replyCount,
    forwardCount,
    reactionsJson,
    isBookmarked,
    isRead,
    isDeleted,
    linkPreviewUrl,
    linkPreviewTitle,
    linkPreviewDescription,
    linkPreviewImageUrl,
    forwardedFromTitle,
    forwardedFromUsername,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'posts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PostEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('view_count')) {
      context.handle(
        _viewCountMeta,
        viewCount.isAcceptableOrUnknown(data['view_count']!, _viewCountMeta),
      );
    }
    if (data.containsKey('reply_count')) {
      context.handle(
        _replyCountMeta,
        replyCount.isAcceptableOrUnknown(data['reply_count']!, _replyCountMeta),
      );
    }
    if (data.containsKey('forward_count')) {
      context.handle(
        _forwardCountMeta,
        forwardCount.isAcceptableOrUnknown(
          data['forward_count']!,
          _forwardCountMeta,
        ),
      );
    }
    if (data.containsKey('reactions_json')) {
      context.handle(
        _reactionsJsonMeta,
        reactionsJson.isAcceptableOrUnknown(
          data['reactions_json']!,
          _reactionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_bookmarked')) {
      context.handle(
        _isBookmarkedMeta,
        isBookmarked.isAcceptableOrUnknown(
          data['is_bookmarked']!,
          _isBookmarkedMeta,
        ),
      );
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('link_preview_url')) {
      context.handle(
        _linkPreviewUrlMeta,
        linkPreviewUrl.isAcceptableOrUnknown(
          data['link_preview_url']!,
          _linkPreviewUrlMeta,
        ),
      );
    }
    if (data.containsKey('link_preview_title')) {
      context.handle(
        _linkPreviewTitleMeta,
        linkPreviewTitle.isAcceptableOrUnknown(
          data['link_preview_title']!,
          _linkPreviewTitleMeta,
        ),
      );
    }
    if (data.containsKey('link_preview_description')) {
      context.handle(
        _linkPreviewDescriptionMeta,
        linkPreviewDescription.isAcceptableOrUnknown(
          data['link_preview_description']!,
          _linkPreviewDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('link_preview_image_url')) {
      context.handle(
        _linkPreviewImageUrlMeta,
        linkPreviewImageUrl.isAcceptableOrUnknown(
          data['link_preview_image_url']!,
          _linkPreviewImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('forwarded_from_title')) {
      context.handle(
        _forwardedFromTitleMeta,
        forwardedFromTitle.isAcceptableOrUnknown(
          data['forwarded_from_title']!,
          _forwardedFromTitleMeta,
        ),
      );
    }
    if (data.containsKey('forwarded_from_username')) {
      context.handle(
        _forwardedFromUsernameMeta,
        forwardedFromUsername.isAcceptableOrUnknown(
          data['forwarded_from_username']!,
          _forwardedFromUsernameMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountId, channelId, messageId},
  ];
  @override
  PostEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PostEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channel_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      )!,
      viewCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}view_count'],
      )!,
      replyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reply_count'],
      )!,
      forwardCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}forward_count'],
      )!,
      reactionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reactions_json'],
      )!,
      isBookmarked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_bookmarked'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      linkPreviewUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_preview_url'],
      ),
      linkPreviewTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_preview_title'],
      ),
      linkPreviewDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_preview_description'],
      ),
      linkPreviewImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_preview_image_url'],
      ),
      forwardedFromTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}forwarded_from_title'],
      ),
      forwardedFromUsername: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}forwarded_from_username'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PostsTable createAlias(String alias) {
    return $PostsTable(attachedDatabase, alias);
  }
}

class PostEntry extends DataClass implements Insertable<PostEntry> {
  final int id;
  final int accountId;
  final int channelId;
  final int messageId;
  final String? body;
  final DateTime publishedAt;
  final int viewCount;
  final int replyCount;
  final int forwardCount;
  final String reactionsJson;
  final bool isBookmarked;
  final bool isRead;
  final bool isDeleted;
  final String? linkPreviewUrl;
  final String? linkPreviewTitle;
  final String? linkPreviewDescription;
  final String? linkPreviewImageUrl;
  final String? forwardedFromTitle;
  final String? forwardedFromUsername;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PostEntry({
    required this.id,
    required this.accountId,
    required this.channelId,
    required this.messageId,
    this.body,
    required this.publishedAt,
    required this.viewCount,
    required this.replyCount,
    required this.forwardCount,
    required this.reactionsJson,
    required this.isBookmarked,
    required this.isRead,
    required this.isDeleted,
    this.linkPreviewUrl,
    this.linkPreviewTitle,
    this.linkPreviewDescription,
    this.linkPreviewImageUrl,
    this.forwardedFromTitle,
    this.forwardedFromUsername,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['channel_id'] = Variable<int>(channelId);
    map['message_id'] = Variable<int>(messageId);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    map['published_at'] = Variable<DateTime>(publishedAt);
    map['view_count'] = Variable<int>(viewCount);
    map['reply_count'] = Variable<int>(replyCount);
    map['forward_count'] = Variable<int>(forwardCount);
    map['reactions_json'] = Variable<String>(reactionsJson);
    map['is_bookmarked'] = Variable<bool>(isBookmarked);
    map['is_read'] = Variable<bool>(isRead);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || linkPreviewUrl != null) {
      map['link_preview_url'] = Variable<String>(linkPreviewUrl);
    }
    if (!nullToAbsent || linkPreviewTitle != null) {
      map['link_preview_title'] = Variable<String>(linkPreviewTitle);
    }
    if (!nullToAbsent || linkPreviewDescription != null) {
      map['link_preview_description'] = Variable<String>(
        linkPreviewDescription,
      );
    }
    if (!nullToAbsent || linkPreviewImageUrl != null) {
      map['link_preview_image_url'] = Variable<String>(linkPreviewImageUrl);
    }
    if (!nullToAbsent || forwardedFromTitle != null) {
      map['forwarded_from_title'] = Variable<String>(forwardedFromTitle);
    }
    if (!nullToAbsent || forwardedFromUsername != null) {
      map['forwarded_from_username'] = Variable<String>(forwardedFromUsername);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PostsCompanion toCompanion(bool nullToAbsent) {
    return PostsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      channelId: Value(channelId),
      messageId: Value(messageId),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      publishedAt: Value(publishedAt),
      viewCount: Value(viewCount),
      replyCount: Value(replyCount),
      forwardCount: Value(forwardCount),
      reactionsJson: Value(reactionsJson),
      isBookmarked: Value(isBookmarked),
      isRead: Value(isRead),
      isDeleted: Value(isDeleted),
      linkPreviewUrl: linkPreviewUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(linkPreviewUrl),
      linkPreviewTitle: linkPreviewTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(linkPreviewTitle),
      linkPreviewDescription: linkPreviewDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(linkPreviewDescription),
      linkPreviewImageUrl: linkPreviewImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(linkPreviewImageUrl),
      forwardedFromTitle: forwardedFromTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(forwardedFromTitle),
      forwardedFromUsername: forwardedFromUsername == null && nullToAbsent
          ? const Value.absent()
          : Value(forwardedFromUsername),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PostEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PostEntry(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      channelId: serializer.fromJson<int>(json['channelId']),
      messageId: serializer.fromJson<int>(json['messageId']),
      body: serializer.fromJson<String?>(json['body']),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      viewCount: serializer.fromJson<int>(json['viewCount']),
      replyCount: serializer.fromJson<int>(json['replyCount']),
      forwardCount: serializer.fromJson<int>(json['forwardCount']),
      reactionsJson: serializer.fromJson<String>(json['reactionsJson']),
      isBookmarked: serializer.fromJson<bool>(json['isBookmarked']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      linkPreviewUrl: serializer.fromJson<String?>(json['linkPreviewUrl']),
      linkPreviewTitle: serializer.fromJson<String?>(json['linkPreviewTitle']),
      linkPreviewDescription: serializer.fromJson<String?>(
        json['linkPreviewDescription'],
      ),
      linkPreviewImageUrl: serializer.fromJson<String?>(
        json['linkPreviewImageUrl'],
      ),
      forwardedFromTitle: serializer.fromJson<String?>(
        json['forwardedFromTitle'],
      ),
      forwardedFromUsername: serializer.fromJson<String?>(
        json['forwardedFromUsername'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'channelId': serializer.toJson<int>(channelId),
      'messageId': serializer.toJson<int>(messageId),
      'body': serializer.toJson<String?>(body),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'viewCount': serializer.toJson<int>(viewCount),
      'replyCount': serializer.toJson<int>(replyCount),
      'forwardCount': serializer.toJson<int>(forwardCount),
      'reactionsJson': serializer.toJson<String>(reactionsJson),
      'isBookmarked': serializer.toJson<bool>(isBookmarked),
      'isRead': serializer.toJson<bool>(isRead),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'linkPreviewUrl': serializer.toJson<String?>(linkPreviewUrl),
      'linkPreviewTitle': serializer.toJson<String?>(linkPreviewTitle),
      'linkPreviewDescription': serializer.toJson<String?>(
        linkPreviewDescription,
      ),
      'linkPreviewImageUrl': serializer.toJson<String?>(linkPreviewImageUrl),
      'forwardedFromTitle': serializer.toJson<String?>(forwardedFromTitle),
      'forwardedFromUsername': serializer.toJson<String?>(
        forwardedFromUsername,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PostEntry copyWith({
    int? id,
    int? accountId,
    int? channelId,
    int? messageId,
    Value<String?> body = const Value.absent(),
    DateTime? publishedAt,
    int? viewCount,
    int? replyCount,
    int? forwardCount,
    String? reactionsJson,
    bool? isBookmarked,
    bool? isRead,
    bool? isDeleted,
    Value<String?> linkPreviewUrl = const Value.absent(),
    Value<String?> linkPreviewTitle = const Value.absent(),
    Value<String?> linkPreviewDescription = const Value.absent(),
    Value<String?> linkPreviewImageUrl = const Value.absent(),
    Value<String?> forwardedFromTitle = const Value.absent(),
    Value<String?> forwardedFromUsername = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PostEntry(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    channelId: channelId ?? this.channelId,
    messageId: messageId ?? this.messageId,
    body: body.present ? body.value : this.body,
    publishedAt: publishedAt ?? this.publishedAt,
    viewCount: viewCount ?? this.viewCount,
    replyCount: replyCount ?? this.replyCount,
    forwardCount: forwardCount ?? this.forwardCount,
    reactionsJson: reactionsJson ?? this.reactionsJson,
    isBookmarked: isBookmarked ?? this.isBookmarked,
    isRead: isRead ?? this.isRead,
    isDeleted: isDeleted ?? this.isDeleted,
    linkPreviewUrl: linkPreviewUrl.present
        ? linkPreviewUrl.value
        : this.linkPreviewUrl,
    linkPreviewTitle: linkPreviewTitle.present
        ? linkPreviewTitle.value
        : this.linkPreviewTitle,
    linkPreviewDescription: linkPreviewDescription.present
        ? linkPreviewDescription.value
        : this.linkPreviewDescription,
    linkPreviewImageUrl: linkPreviewImageUrl.present
        ? linkPreviewImageUrl.value
        : this.linkPreviewImageUrl,
    forwardedFromTitle: forwardedFromTitle.present
        ? forwardedFromTitle.value
        : this.forwardedFromTitle,
    forwardedFromUsername: forwardedFromUsername.present
        ? forwardedFromUsername.value
        : this.forwardedFromUsername,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PostEntry copyWithCompanion(PostsCompanion data) {
    return PostEntry(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      body: data.body.present ? data.body.value : this.body,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      viewCount: data.viewCount.present ? data.viewCount.value : this.viewCount,
      replyCount: data.replyCount.present
          ? data.replyCount.value
          : this.replyCount,
      forwardCount: data.forwardCount.present
          ? data.forwardCount.value
          : this.forwardCount,
      reactionsJson: data.reactionsJson.present
          ? data.reactionsJson.value
          : this.reactionsJson,
      isBookmarked: data.isBookmarked.present
          ? data.isBookmarked.value
          : this.isBookmarked,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      linkPreviewUrl: data.linkPreviewUrl.present
          ? data.linkPreviewUrl.value
          : this.linkPreviewUrl,
      linkPreviewTitle: data.linkPreviewTitle.present
          ? data.linkPreviewTitle.value
          : this.linkPreviewTitle,
      linkPreviewDescription: data.linkPreviewDescription.present
          ? data.linkPreviewDescription.value
          : this.linkPreviewDescription,
      linkPreviewImageUrl: data.linkPreviewImageUrl.present
          ? data.linkPreviewImageUrl.value
          : this.linkPreviewImageUrl,
      forwardedFromTitle: data.forwardedFromTitle.present
          ? data.forwardedFromTitle.value
          : this.forwardedFromTitle,
      forwardedFromUsername: data.forwardedFromUsername.present
          ? data.forwardedFromUsername.value
          : this.forwardedFromUsername,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PostEntry(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('channelId: $channelId, ')
          ..write('messageId: $messageId, ')
          ..write('body: $body, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('viewCount: $viewCount, ')
          ..write('replyCount: $replyCount, ')
          ..write('forwardCount: $forwardCount, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('isBookmarked: $isBookmarked, ')
          ..write('isRead: $isRead, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('linkPreviewUrl: $linkPreviewUrl, ')
          ..write('linkPreviewTitle: $linkPreviewTitle, ')
          ..write('linkPreviewDescription: $linkPreviewDescription, ')
          ..write('linkPreviewImageUrl: $linkPreviewImageUrl, ')
          ..write('forwardedFromTitle: $forwardedFromTitle, ')
          ..write('forwardedFromUsername: $forwardedFromUsername, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    accountId,
    channelId,
    messageId,
    body,
    publishedAt,
    viewCount,
    replyCount,
    forwardCount,
    reactionsJson,
    isBookmarked,
    isRead,
    isDeleted,
    linkPreviewUrl,
    linkPreviewTitle,
    linkPreviewDescription,
    linkPreviewImageUrl,
    forwardedFromTitle,
    forwardedFromUsername,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PostEntry &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.channelId == this.channelId &&
          other.messageId == this.messageId &&
          other.body == this.body &&
          other.publishedAt == this.publishedAt &&
          other.viewCount == this.viewCount &&
          other.replyCount == this.replyCount &&
          other.forwardCount == this.forwardCount &&
          other.reactionsJson == this.reactionsJson &&
          other.isBookmarked == this.isBookmarked &&
          other.isRead == this.isRead &&
          other.isDeleted == this.isDeleted &&
          other.linkPreviewUrl == this.linkPreviewUrl &&
          other.linkPreviewTitle == this.linkPreviewTitle &&
          other.linkPreviewDescription == this.linkPreviewDescription &&
          other.linkPreviewImageUrl == this.linkPreviewImageUrl &&
          other.forwardedFromTitle == this.forwardedFromTitle &&
          other.forwardedFromUsername == this.forwardedFromUsername &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PostsCompanion extends UpdateCompanion<PostEntry> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<int> channelId;
  final Value<int> messageId;
  final Value<String?> body;
  final Value<DateTime> publishedAt;
  final Value<int> viewCount;
  final Value<int> replyCount;
  final Value<int> forwardCount;
  final Value<String> reactionsJson;
  final Value<bool> isBookmarked;
  final Value<bool> isRead;
  final Value<bool> isDeleted;
  final Value<String?> linkPreviewUrl;
  final Value<String?> linkPreviewTitle;
  final Value<String?> linkPreviewDescription;
  final Value<String?> linkPreviewImageUrl;
  final Value<String?> forwardedFromTitle;
  final Value<String?> forwardedFromUsername;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PostsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.body = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.viewCount = const Value.absent(),
    this.replyCount = const Value.absent(),
    this.forwardCount = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.isBookmarked = const Value.absent(),
    this.isRead = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.linkPreviewUrl = const Value.absent(),
    this.linkPreviewTitle = const Value.absent(),
    this.linkPreviewDescription = const Value.absent(),
    this.linkPreviewImageUrl = const Value.absent(),
    this.forwardedFromTitle = const Value.absent(),
    this.forwardedFromUsername = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PostsCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required int channelId,
    required int messageId,
    this.body = const Value.absent(),
    required DateTime publishedAt,
    this.viewCount = const Value.absent(),
    this.replyCount = const Value.absent(),
    this.forwardCount = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.isBookmarked = const Value.absent(),
    this.isRead = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.linkPreviewUrl = const Value.absent(),
    this.linkPreviewTitle = const Value.absent(),
    this.linkPreviewDescription = const Value.absent(),
    this.linkPreviewImageUrl = const Value.absent(),
    this.forwardedFromTitle = const Value.absent(),
    this.forwardedFromUsername = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : accountId = Value(accountId),
       channelId = Value(channelId),
       messageId = Value(messageId),
       publishedAt = Value(publishedAt);
  static Insertable<PostEntry> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<int>? channelId,
    Expression<int>? messageId,
    Expression<String>? body,
    Expression<DateTime>? publishedAt,
    Expression<int>? viewCount,
    Expression<int>? replyCount,
    Expression<int>? forwardCount,
    Expression<String>? reactionsJson,
    Expression<bool>? isBookmarked,
    Expression<bool>? isRead,
    Expression<bool>? isDeleted,
    Expression<String>? linkPreviewUrl,
    Expression<String>? linkPreviewTitle,
    Expression<String>? linkPreviewDescription,
    Expression<String>? linkPreviewImageUrl,
    Expression<String>? forwardedFromTitle,
    Expression<String>? forwardedFromUsername,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (channelId != null) 'channel_id': channelId,
      if (messageId != null) 'message_id': messageId,
      if (body != null) 'body': body,
      if (publishedAt != null) 'published_at': publishedAt,
      if (viewCount != null) 'view_count': viewCount,
      if (replyCount != null) 'reply_count': replyCount,
      if (forwardCount != null) 'forward_count': forwardCount,
      if (reactionsJson != null) 'reactions_json': reactionsJson,
      if (isBookmarked != null) 'is_bookmarked': isBookmarked,
      if (isRead != null) 'is_read': isRead,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (linkPreviewUrl != null) 'link_preview_url': linkPreviewUrl,
      if (linkPreviewTitle != null) 'link_preview_title': linkPreviewTitle,
      if (linkPreviewDescription != null)
        'link_preview_description': linkPreviewDescription,
      if (linkPreviewImageUrl != null)
        'link_preview_image_url': linkPreviewImageUrl,
      if (forwardedFromTitle != null)
        'forwarded_from_title': forwardedFromTitle,
      if (forwardedFromUsername != null)
        'forwarded_from_username': forwardedFromUsername,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PostsCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<int>? channelId,
    Value<int>? messageId,
    Value<String?>? body,
    Value<DateTime>? publishedAt,
    Value<int>? viewCount,
    Value<int>? replyCount,
    Value<int>? forwardCount,
    Value<String>? reactionsJson,
    Value<bool>? isBookmarked,
    Value<bool>? isRead,
    Value<bool>? isDeleted,
    Value<String?>? linkPreviewUrl,
    Value<String?>? linkPreviewTitle,
    Value<String?>? linkPreviewDescription,
    Value<String?>? linkPreviewImageUrl,
    Value<String?>? forwardedFromTitle,
    Value<String?>? forwardedFromUsername,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return PostsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      channelId: channelId ?? this.channelId,
      messageId: messageId ?? this.messageId,
      body: body ?? this.body,
      publishedAt: publishedAt ?? this.publishedAt,
      viewCount: viewCount ?? this.viewCount,
      replyCount: replyCount ?? this.replyCount,
      forwardCount: forwardCount ?? this.forwardCount,
      reactionsJson: reactionsJson ?? this.reactionsJson,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
      linkPreviewUrl: linkPreviewUrl ?? this.linkPreviewUrl,
      linkPreviewTitle: linkPreviewTitle ?? this.linkPreviewTitle,
      linkPreviewDescription:
          linkPreviewDescription ?? this.linkPreviewDescription,
      linkPreviewImageUrl: linkPreviewImageUrl ?? this.linkPreviewImageUrl,
      forwardedFromTitle: forwardedFromTitle ?? this.forwardedFromTitle,
      forwardedFromUsername:
          forwardedFromUsername ?? this.forwardedFromUsername,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<int>(channelId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (viewCount.present) {
      map['view_count'] = Variable<int>(viewCount.value);
    }
    if (replyCount.present) {
      map['reply_count'] = Variable<int>(replyCount.value);
    }
    if (forwardCount.present) {
      map['forward_count'] = Variable<int>(forwardCount.value);
    }
    if (reactionsJson.present) {
      map['reactions_json'] = Variable<String>(reactionsJson.value);
    }
    if (isBookmarked.present) {
      map['is_bookmarked'] = Variable<bool>(isBookmarked.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (linkPreviewUrl.present) {
      map['link_preview_url'] = Variable<String>(linkPreviewUrl.value);
    }
    if (linkPreviewTitle.present) {
      map['link_preview_title'] = Variable<String>(linkPreviewTitle.value);
    }
    if (linkPreviewDescription.present) {
      map['link_preview_description'] = Variable<String>(
        linkPreviewDescription.value,
      );
    }
    if (linkPreviewImageUrl.present) {
      map['link_preview_image_url'] = Variable<String>(
        linkPreviewImageUrl.value,
      );
    }
    if (forwardedFromTitle.present) {
      map['forwarded_from_title'] = Variable<String>(forwardedFromTitle.value);
    }
    if (forwardedFromUsername.present) {
      map['forwarded_from_username'] = Variable<String>(
        forwardedFromUsername.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PostsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('channelId: $channelId, ')
          ..write('messageId: $messageId, ')
          ..write('body: $body, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('viewCount: $viewCount, ')
          ..write('replyCount: $replyCount, ')
          ..write('forwardCount: $forwardCount, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('isBookmarked: $isBookmarked, ')
          ..write('isRead: $isRead, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('linkPreviewUrl: $linkPreviewUrl, ')
          ..write('linkPreviewTitle: $linkPreviewTitle, ')
          ..write('linkPreviewDescription: $linkPreviewDescription, ')
          ..write('linkPreviewImageUrl: $linkPreviewImageUrl, ')
          ..write('forwardedFromTitle: $forwardedFromTitle, ')
          ..write('forwardedFromUsername: $forwardedFromUsername, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MediaItemsTable extends MediaItems
    with TableInfo<$MediaItemsTable, MediaItemEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _postIdMeta = const VerificationMeta('postId');
  @override
  late final GeneratedColumn<int> postId = GeneratedColumn<int>(
    'post_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES posts (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    postId,
    type,
    url,
    thumbnailUrl,
    width,
    height,
    duration,
    fileSize,
    fileName,
    mimeType,
    localPath,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaItemEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('post_id')) {
      context.handle(
        _postIdMeta,
        postId.isAcceptableOrUnknown(data['post_id']!, _postIdMeta),
      );
    } else if (isInserting) {
      context.missing(_postIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaItemEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaItemEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      postId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}post_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $MediaItemsTable createAlias(String alias) {
    return $MediaItemsTable(attachedDatabase, alias);
  }
}

class MediaItemEntry extends DataClass implements Insertable<MediaItemEntry> {
  final int id;
  final int postId;
  final String type;
  final String? url;
  final String? thumbnailUrl;
  final int width;
  final int height;
  final int duration;
  final int fileSize;
  final String? fileName;
  final String? mimeType;
  final String? localPath;
  final int sortOrder;
  const MediaItemEntry({
    required this.id,
    required this.postId,
    required this.type,
    this.url,
    this.thumbnailUrl,
    required this.width,
    required this.height,
    required this.duration,
    required this.fileSize,
    this.fileName,
    this.mimeType,
    this.localPath,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['post_id'] = Variable<int>(postId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['duration'] = Variable<int>(duration);
    map['file_size'] = Variable<int>(fileSize);
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  MediaItemsCompanion toCompanion(bool nullToAbsent) {
    return MediaItemsCompanion(
      id: Value(id),
      postId: Value(postId),
      type: Value(type),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      width: Value(width),
      height: Value(height),
      duration: Value(duration),
      fileSize: Value(fileSize),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      sortOrder: Value(sortOrder),
    );
  }

  factory MediaItemEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaItemEntry(
      id: serializer.fromJson<int>(json['id']),
      postId: serializer.fromJson<int>(json['postId']),
      type: serializer.fromJson<String>(json['type']),
      url: serializer.fromJson<String?>(json['url']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      duration: serializer.fromJson<int>(json['duration']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'postId': serializer.toJson<int>(postId),
      'type': serializer.toJson<String>(type),
      'url': serializer.toJson<String?>(url),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'duration': serializer.toJson<int>(duration),
      'fileSize': serializer.toJson<int>(fileSize),
      'fileName': serializer.toJson<String?>(fileName),
      'mimeType': serializer.toJson<String?>(mimeType),
      'localPath': serializer.toJson<String?>(localPath),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  MediaItemEntry copyWith({
    int? id,
    int? postId,
    String? type,
    Value<String?> url = const Value.absent(),
    Value<String?> thumbnailUrl = const Value.absent(),
    int? width,
    int? height,
    int? duration,
    int? fileSize,
    Value<String?> fileName = const Value.absent(),
    Value<String?> mimeType = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    int? sortOrder,
  }) => MediaItemEntry(
    id: id ?? this.id,
    postId: postId ?? this.postId,
    type: type ?? this.type,
    url: url.present ? url.value : this.url,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    width: width ?? this.width,
    height: height ?? this.height,
    duration: duration ?? this.duration,
    fileSize: fileSize ?? this.fileSize,
    fileName: fileName.present ? fileName.value : this.fileName,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    localPath: localPath.present ? localPath.value : this.localPath,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  MediaItemEntry copyWithCompanion(MediaItemsCompanion data) {
    return MediaItemEntry(
      id: data.id.present ? data.id.value : this.id,
      postId: data.postId.present ? data.postId.value : this.postId,
      type: data.type.present ? data.type.value : this.type,
      url: data.url.present ? data.url.value : this.url,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      duration: data.duration.present ? data.duration.value : this.duration,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaItemEntry(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('type: $type, ')
          ..write('url: $url, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('duration: $duration, ')
          ..write('fileSize: $fileSize, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('localPath: $localPath, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    postId,
    type,
    url,
    thumbnailUrl,
    width,
    height,
    duration,
    fileSize,
    fileName,
    mimeType,
    localPath,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaItemEntry &&
          other.id == this.id &&
          other.postId == this.postId &&
          other.type == this.type &&
          other.url == this.url &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.width == this.width &&
          other.height == this.height &&
          other.duration == this.duration &&
          other.fileSize == this.fileSize &&
          other.fileName == this.fileName &&
          other.mimeType == this.mimeType &&
          other.localPath == this.localPath &&
          other.sortOrder == this.sortOrder);
}

class MediaItemsCompanion extends UpdateCompanion<MediaItemEntry> {
  final Value<int> id;
  final Value<int> postId;
  final Value<String> type;
  final Value<String?> url;
  final Value<String?> thumbnailUrl;
  final Value<int> width;
  final Value<int> height;
  final Value<int> duration;
  final Value<int> fileSize;
  final Value<String?> fileName;
  final Value<String?> mimeType;
  final Value<String?> localPath;
  final Value<int> sortOrder;
  const MediaItemsCompanion({
    this.id = const Value.absent(),
    this.postId = const Value.absent(),
    this.type = const Value.absent(),
    this.url = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.duration = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  MediaItemsCompanion.insert({
    this.id = const Value.absent(),
    required int postId,
    required String type,
    this.url = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.duration = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : postId = Value(postId),
       type = Value(type);
  static Insertable<MediaItemEntry> custom({
    Expression<int>? id,
    Expression<int>? postId,
    Expression<String>? type,
    Expression<String>? url,
    Expression<String>? thumbnailUrl,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? duration,
    Expression<int>? fileSize,
    Expression<String>? fileName,
    Expression<String>? mimeType,
    Expression<String>? localPath,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (postId != null) 'post_id': postId,
      if (type != null) 'type': type,
      if (url != null) 'url': url,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      if (fileSize != null) 'file_size': fileSize,
      if (fileName != null) 'file_name': fileName,
      if (mimeType != null) 'mime_type': mimeType,
      if (localPath != null) 'local_path': localPath,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  MediaItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? postId,
    Value<String>? type,
    Value<String?>? url,
    Value<String?>? thumbnailUrl,
    Value<int>? width,
    Value<int>? height,
    Value<int>? duration,
    Value<int>? fileSize,
    Value<String?>? fileName,
    Value<String?>? mimeType,
    Value<String?>? localPath,
    Value<int>? sortOrder,
  }) {
    return MediaItemsCompanion(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      type: type ?? this.type,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (postId.present) {
      map['post_id'] = Variable<int>(postId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaItemsCompanion(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('type: $type, ')
          ..write('url: $url, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('duration: $duration, ')
          ..write('fileSize: $fileSize, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('localPath: $localPath, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $BookmarkEntriesTable extends BookmarkEntries
    with TableInfo<$BookmarkEntriesTable, BookmarkEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarkEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _postIdMeta = const VerificationMeta('postId');
  @override
  late final GeneratedColumn<int> postId = GeneratedColumn<int>(
    'post_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES posts (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, accountId, postId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmark_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarkEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('post_id')) {
      context.handle(
        _postIdMeta,
        postId.isAcceptableOrUnknown(data['post_id']!, _postIdMeta),
      );
    } else if (isInserting) {
      context.missing(_postIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountId, postId},
  ];
  @override
  BookmarkEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      postId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}post_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookmarkEntriesTable createAlias(String alias) {
    return $BookmarkEntriesTable(attachedDatabase, alias);
  }
}

class BookmarkEntry extends DataClass implements Insertable<BookmarkEntry> {
  final int id;
  final int accountId;
  final int postId;
  final DateTime createdAt;
  const BookmarkEntry({
    required this.id,
    required this.accountId,
    required this.postId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['post_id'] = Variable<int>(postId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarkEntriesCompanion toCompanion(bool nullToAbsent) {
    return BookmarkEntriesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      postId: Value(postId),
      createdAt: Value(createdAt),
    );
  }

  factory BookmarkEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkEntry(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      postId: serializer.fromJson<int>(json['postId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'postId': serializer.toJson<int>(postId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BookmarkEntry copyWith({
    int? id,
    int? accountId,
    int? postId,
    DateTime? createdAt,
  }) => BookmarkEntry(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    postId: postId ?? this.postId,
    createdAt: createdAt ?? this.createdAt,
  );
  BookmarkEntry copyWithCompanion(BookmarkEntriesCompanion data) {
    return BookmarkEntry(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      postId: data.postId.present ? data.postId.value : this.postId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkEntry(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('postId: $postId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accountId, postId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkEntry &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.postId == this.postId &&
          other.createdAt == this.createdAt);
}

class BookmarkEntriesCompanion extends UpdateCompanion<BookmarkEntry> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<int> postId;
  final Value<DateTime> createdAt;
  const BookmarkEntriesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.postId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookmarkEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required int postId,
    this.createdAt = const Value.absent(),
  }) : accountId = Value(accountId),
       postId = Value(postId);
  static Insertable<BookmarkEntry> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<int>? postId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (postId != null) 'post_id': postId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookmarkEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<int>? postId,
    Value<DateTime>? createdAt,
  }) {
    return BookmarkEntriesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      postId: postId ?? this.postId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (postId.present) {
      map['post_id'] = Variable<int>(postId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkEntriesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('postId: $postId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, FolderEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, accountId, folderId, title];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountId, folderId},
  ];
  @override
  FolderEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class FolderEntry extends DataClass implements Insertable<FolderEntry> {
  final int id;
  final int accountId;
  final int folderId;
  final String title;
  const FolderEntry({
    required this.id,
    required this.accountId,
    required this.folderId,
    required this.title,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['folder_id'] = Variable<int>(folderId);
    map['title'] = Variable<String>(title);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      accountId: Value(accountId),
      folderId: Value(folderId),
      title: Value(title),
    );
  }

  factory FolderEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderEntry(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      folderId: serializer.fromJson<int>(json['folderId']),
      title: serializer.fromJson<String>(json['title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'folderId': serializer.toJson<int>(folderId),
      'title': serializer.toJson<String>(title),
    };
  }

  FolderEntry copyWith({
    int? id,
    int? accountId,
    int? folderId,
    String? title,
  }) => FolderEntry(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    folderId: folderId ?? this.folderId,
    title: title ?? this.title,
  );
  FolderEntry copyWithCompanion(FoldersCompanion data) {
    return FolderEntry(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      title: data.title.present ? data.title.value : this.title,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderEntry(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('folderId: $folderId, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accountId, folderId, title);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderEntry &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.folderId == this.folderId &&
          other.title == this.title);
}

class FoldersCompanion extends UpdateCompanion<FolderEntry> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<int> folderId;
  final Value<String> title;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.title = const Value.absent(),
  });
  FoldersCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required int folderId,
    required String title,
  }) : accountId = Value(accountId),
       folderId = Value(folderId),
       title = Value(title);
  static Insertable<FolderEntry> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<int>? folderId,
    Expression<String>? title,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (folderId != null) 'folder_id': folderId,
      if (title != null) 'title': title,
    });
  }

  FoldersCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<int>? folderId,
    Value<String>? title,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('folderId: $folderId, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }
}

class $FolderChannelsTable extends FolderChannels
    with TableInfo<$FolderChannelsTable, FolderChannel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FolderChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _folderDbIdMeta = const VerificationMeta(
    'folderDbId',
  );
  @override
  late final GeneratedColumn<int> folderDbId = GeneratedColumn<int>(
    'folder_db_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id)',
    ),
  );
  static const VerificationMeta _channelDbIdMeta = const VerificationMeta(
    'channelDbId',
  );
  @override
  late final GeneratedColumn<int> channelDbId = GeneratedColumn<int>(
    'channel_db_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES channels (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, folderDbId, channelDbId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folder_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderChannel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('folder_db_id')) {
      context.handle(
        _folderDbIdMeta,
        folderDbId.isAcceptableOrUnknown(
          data['folder_db_id']!,
          _folderDbIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_folderDbIdMeta);
    }
    if (data.containsKey('channel_db_id')) {
      context.handle(
        _channelDbIdMeta,
        channelDbId.isAcceptableOrUnknown(
          data['channel_db_id']!,
          _channelDbIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_channelDbIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {folderDbId, channelDbId},
  ];
  @override
  FolderChannel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderChannel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      folderDbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_db_id'],
      )!,
      channelDbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channel_db_id'],
      )!,
    );
  }

  @override
  $FolderChannelsTable createAlias(String alias) {
    return $FolderChannelsTable(attachedDatabase, alias);
  }
}

class FolderChannel extends DataClass implements Insertable<FolderChannel> {
  final int id;
  final int folderDbId;
  final int channelDbId;
  const FolderChannel({
    required this.id,
    required this.folderDbId,
    required this.channelDbId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['folder_db_id'] = Variable<int>(folderDbId);
    map['channel_db_id'] = Variable<int>(channelDbId);
    return map;
  }

  FolderChannelsCompanion toCompanion(bool nullToAbsent) {
    return FolderChannelsCompanion(
      id: Value(id),
      folderDbId: Value(folderDbId),
      channelDbId: Value(channelDbId),
    );
  }

  factory FolderChannel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderChannel(
      id: serializer.fromJson<int>(json['id']),
      folderDbId: serializer.fromJson<int>(json['folderDbId']),
      channelDbId: serializer.fromJson<int>(json['channelDbId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'folderDbId': serializer.toJson<int>(folderDbId),
      'channelDbId': serializer.toJson<int>(channelDbId),
    };
  }

  FolderChannel copyWith({int? id, int? folderDbId, int? channelDbId}) =>
      FolderChannel(
        id: id ?? this.id,
        folderDbId: folderDbId ?? this.folderDbId,
        channelDbId: channelDbId ?? this.channelDbId,
      );
  FolderChannel copyWithCompanion(FolderChannelsCompanion data) {
    return FolderChannel(
      id: data.id.present ? data.id.value : this.id,
      folderDbId: data.folderDbId.present
          ? data.folderDbId.value
          : this.folderDbId,
      channelDbId: data.channelDbId.present
          ? data.channelDbId.value
          : this.channelDbId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderChannel(')
          ..write('id: $id, ')
          ..write('folderDbId: $folderDbId, ')
          ..write('channelDbId: $channelDbId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, folderDbId, channelDbId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderChannel &&
          other.id == this.id &&
          other.folderDbId == this.folderDbId &&
          other.channelDbId == this.channelDbId);
}

class FolderChannelsCompanion extends UpdateCompanion<FolderChannel> {
  final Value<int> id;
  final Value<int> folderDbId;
  final Value<int> channelDbId;
  const FolderChannelsCompanion({
    this.id = const Value.absent(),
    this.folderDbId = const Value.absent(),
    this.channelDbId = const Value.absent(),
  });
  FolderChannelsCompanion.insert({
    this.id = const Value.absent(),
    required int folderDbId,
    required int channelDbId,
  }) : folderDbId = Value(folderDbId),
       channelDbId = Value(channelDbId);
  static Insertable<FolderChannel> custom({
    Expression<int>? id,
    Expression<int>? folderDbId,
    Expression<int>? channelDbId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderDbId != null) 'folder_db_id': folderDbId,
      if (channelDbId != null) 'channel_db_id': channelDbId,
    });
  }

  FolderChannelsCompanion copyWith({
    Value<int>? id,
    Value<int>? folderDbId,
    Value<int>? channelDbId,
  }) {
    return FolderChannelsCompanion(
      id: id ?? this.id,
      folderDbId: folderDbId ?? this.folderDbId,
      channelDbId: channelDbId ?? this.channelDbId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (folderDbId.present) {
      map['folder_db_id'] = Variable<int>(folderDbId.value);
    }
    if (channelDbId.present) {
      map['channel_db_id'] = Variable<int>(channelDbId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FolderChannelsCompanion(')
          ..write('id: $id, ')
          ..write('folderDbId: $folderDbId, ')
          ..write('channelDbId: $channelDbId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $ChannelsTable channels = $ChannelsTable(this);
  late final $PostsTable posts = $PostsTable(this);
  late final $MediaItemsTable mediaItems = $MediaItemsTable(this);
  late final $BookmarkEntriesTable bookmarkEntries = $BookmarkEntriesTable(
    this,
  );
  late final $FoldersTable folders = $FoldersTable(this);
  late final $FolderChannelsTable folderChannels = $FolderChannelsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    channels,
    posts,
    mediaItems,
    bookmarkEntries,
    folders,
    folderChannels,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> id,
      required String telegramUserId,
      Value<String?> displayName,
      Value<String?> username,
      Value<String?> phoneNumber,
      Value<String?> avatarPath,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> id,
      Value<String> telegramUserId,
      Value<String?> displayName,
      Value<String?> username,
      Value<String?> phoneNumber,
      Value<String?> avatarPath,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ChannelsTable, List<ChannelEntry>>
  _channelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.channels,
    aliasName: 'accounts__id__channels__account_id',
  );

  $$ChannelsTableProcessedTableManager get channelsRefs {
    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_channelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PostsTable, List<PostEntry>> _postsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.posts,
    aliasName: 'accounts__id__posts__account_id',
  );

  $$PostsTableProcessedTableManager get postsRefs {
    final manager = $$PostsTableTableManager(
      $_db,
      $_db.posts,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_postsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarkEntriesTable, List<BookmarkEntry>>
  _bookmarkEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarkEntries,
    aliasName: 'accounts__id__bookmark_entries__account_id',
  );

  $$BookmarkEntriesTableProcessedTableManager get bookmarkEntriesRefs {
    final manager = $$BookmarkEntriesTableTableManager(
      $_db,
      $_db.bookmarkEntries,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _bookmarkEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FoldersTable, List<FolderEntry>>
  _foldersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.folders,
    aliasName: 'accounts__id__folders__account_id',
  );

  $$FoldersTableProcessedTableManager get foldersRefs {
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_foldersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get telegramUserId => $composableBuilder(
    column: $table.telegramUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> channelsRefs(
    Expression<bool> Function($$ChannelsTableFilterComposer f) f,
  ) {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> postsRefs(
    Expression<bool> Function($$PostsTableFilterComposer f) f,
  ) {
    final $$PostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableFilterComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarkEntriesRefs(
    Expression<bool> Function($$BookmarkEntriesTableFilterComposer f) f,
  ) {
    final $$BookmarkEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarkEntries,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarkEntriesTableFilterComposer(
            $db: $db,
            $table: $db.bookmarkEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> foldersRefs(
    Expression<bool> Function($$FoldersTableFilterComposer f) f,
  ) {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get telegramUserId => $composableBuilder(
    column: $table.telegramUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get telegramUserId => $composableBuilder(
    column: $table.telegramUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> channelsRefs<T extends Object>(
    Expression<T> Function($$ChannelsTableAnnotationComposer a) f,
  ) {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> postsRefs<T extends Object>(
    Expression<T> Function($$PostsTableAnnotationComposer a) f,
  ) {
    final $$PostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableAnnotationComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookmarkEntriesRefs<T extends Object>(
    Expression<T> Function($$BookmarkEntriesTableAnnotationComposer a) f,
  ) {
    final $$BookmarkEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarkEntries,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarkEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarkEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> foldersRefs<T extends Object>(
    Expression<T> Function($$FoldersTableAnnotationComposer a) f,
  ) {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({
            bool channelsRefs,
            bool postsRefs,
            bool bookmarkEntriesRefs,
            bool foldersRefs,
          })
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> telegramUserId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> phoneNumber = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                telegramUserId: telegramUserId,
                displayName: displayName,
                username: username,
                phoneNumber: phoneNumber,
                avatarPath: avatarPath,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String telegramUserId,
                Value<String?> displayName = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> phoneNumber = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                telegramUserId: telegramUserId,
                displayName: displayName,
                username: username,
                phoneNumber: phoneNumber,
                avatarPath: avatarPath,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                channelsRefs = false,
                postsRefs = false,
                bookmarkEntriesRefs = false,
                foldersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (channelsRefs) db.channels,
                    if (postsRefs) db.posts,
                    if (bookmarkEntriesRefs) db.bookmarkEntries,
                    if (foldersRefs) db.folders,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (channelsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          ChannelEntry
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._channelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).channelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (postsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          PostEntry
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._postsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).postsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarkEntriesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          BookmarkEntry
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._bookmarkEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarkEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (foldersRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          FolderEntry
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._foldersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).foldersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({
        bool channelsRefs,
        bool postsRefs,
        bool bookmarkEntriesRefs,
        bool foldersRefs,
      })
    >;
typedef $$ChannelsTableCreateCompanionBuilder =
    ChannelsCompanion Function({
      Value<int> id,
      required int accountId,
      required int chatId,
      required String title,
      Value<String?> username,
      Value<String?> description,
      Value<String?> avatarUrl,
      Value<String?> avatarColor,
      Value<int> subscriberCount,
      Value<bool> isVerified,
      Value<bool> isFavorite,
      Value<bool> isMuted,
      Value<bool> isHidden,
      Value<int> lastReadInboxMessageId,
      Value<DateTime?> lastPostAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ChannelsTableUpdateCompanionBuilder =
    ChannelsCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<int> chatId,
      Value<String> title,
      Value<String?> username,
      Value<String?> description,
      Value<String?> avatarUrl,
      Value<String?> avatarColor,
      Value<int> subscriberCount,
      Value<bool> isVerified,
      Value<bool> isFavorite,
      Value<bool> isMuted,
      Value<bool> isHidden,
      Value<int> lastReadInboxMessageId,
      Value<DateTime?> lastPostAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ChannelsTableReferences
    extends BaseReferences<_$AppDatabase, $ChannelsTable, ChannelEntry> {
  $$ChannelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('channels__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PostsTable, List<PostEntry>> _postsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.posts,
    aliasName: 'channels__id__posts__channel_id',
  );

  $$PostsTableProcessedTableManager get postsRefs {
    final manager = $$PostsTableTableManager(
      $_db,
      $_db.posts,
    ).filter((f) => f.channelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_postsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FolderChannelsTable, List<FolderChannel>>
  _folderChannelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.folderChannels,
    aliasName: 'channels__id__folder_channels__channel_db_id',
  );

  $$FolderChannelsTableProcessedTableManager get folderChannelsRefs {
    final manager = $$FolderChannelsTableTableManager(
      $_db,
      $_db.folderChannels,
    ).filter((f) => f.channelDbId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_folderChannelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarColor => $composableBuilder(
    column: $table.avatarColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subscriberCount => $composableBuilder(
    column: $table.subscriberCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVerified => $composableBuilder(
    column: $table.isVerified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMuted => $composableBuilder(
    column: $table.isMuted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadInboxMessageId => $composableBuilder(
    column: $table.lastReadInboxMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPostAt => $composableBuilder(
    column: $table.lastPostAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> postsRefs(
    Expression<bool> Function($$PostsTableFilterComposer f) f,
  ) {
    final $$PostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.channelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableFilterComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> folderChannelsRefs(
    Expression<bool> Function($$FolderChannelsTableFilterComposer f) f,
  ) {
    final $$FolderChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folderChannels,
      getReferencedColumn: (t) => t.channelDbId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderChannelsTableFilterComposer(
            $db: $db,
            $table: $db.folderChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarColor => $composableBuilder(
    column: $table.avatarColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subscriberCount => $composableBuilder(
    column: $table.subscriberCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVerified => $composableBuilder(
    column: $table.isVerified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMuted => $composableBuilder(
    column: $table.isMuted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadInboxMessageId => $composableBuilder(
    column: $table.lastReadInboxMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPostAt => $composableBuilder(
    column: $table.lastPostAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get avatarColor => $composableBuilder(
    column: $table.avatarColor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subscriberCount => $composableBuilder(
    column: $table.subscriberCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isVerified => $composableBuilder(
    column: $table.isVerified,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMuted =>
      $composableBuilder(column: $table.isMuted, builder: (column) => column);

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  GeneratedColumn<int> get lastReadInboxMessageId => $composableBuilder(
    column: $table.lastReadInboxMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPostAt => $composableBuilder(
    column: $table.lastPostAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> postsRefs<T extends Object>(
    Expression<T> Function($$PostsTableAnnotationComposer a) f,
  ) {
    final $$PostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.channelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableAnnotationComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> folderChannelsRefs<T extends Object>(
    Expression<T> Function($$FolderChannelsTableAnnotationComposer a) f,
  ) {
    final $$FolderChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folderChannels,
      getReferencedColumn: (t) => t.channelDbId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.folderChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChannelsTable,
          ChannelEntry,
          $$ChannelsTableFilterComposer,
          $$ChannelsTableOrderingComposer,
          $$ChannelsTableAnnotationComposer,
          $$ChannelsTableCreateCompanionBuilder,
          $$ChannelsTableUpdateCompanionBuilder,
          (ChannelEntry, $$ChannelsTableReferences),
          ChannelEntry,
          PrefetchHooks Function({
            bool accountId,
            bool postsRefs,
            bool folderChannelsRefs,
          })
        > {
  $$ChannelsTableTableManager(_$AppDatabase db, $ChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> chatId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String?> avatarColor = const Value.absent(),
                Value<int> subscriberCount = const Value.absent(),
                Value<bool> isVerified = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isMuted = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int> lastReadInboxMessageId = const Value.absent(),
                Value<DateTime?> lastPostAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChannelsCompanion(
                id: id,
                accountId: accountId,
                chatId: chatId,
                title: title,
                username: username,
                description: description,
                avatarUrl: avatarUrl,
                avatarColor: avatarColor,
                subscriberCount: subscriberCount,
                isVerified: isVerified,
                isFavorite: isFavorite,
                isMuted: isMuted,
                isHidden: isHidden,
                lastReadInboxMessageId: lastReadInboxMessageId,
                lastPostAt: lastPostAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required int chatId,
                required String title,
                Value<String?> username = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String?> avatarColor = const Value.absent(),
                Value<int> subscriberCount = const Value.absent(),
                Value<bool> isVerified = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isMuted = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int> lastReadInboxMessageId = const Value.absent(),
                Value<DateTime?> lastPostAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChannelsCompanion.insert(
                id: id,
                accountId: accountId,
                chatId: chatId,
                title: title,
                username: username,
                description: description,
                avatarUrl: avatarUrl,
                avatarColor: avatarColor,
                subscriberCount: subscriberCount,
                isVerified: isVerified,
                isFavorite: isFavorite,
                isMuted: isMuted,
                isHidden: isHidden,
                lastReadInboxMessageId: lastReadInboxMessageId,
                lastPostAt: lastPostAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                postsRefs = false,
                folderChannelsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (postsRefs) db.posts,
                    if (folderChannelsRefs) db.folderChannels,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable: $$ChannelsTableReferences
                                        ._accountIdTable(db),
                                    referencedColumn: $$ChannelsTableReferences
                                        ._accountIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (postsRefs)
                        await $_getPrefetchedData<
                          ChannelEntry,
                          $ChannelsTable,
                          PostEntry
                        >(
                          currentTable: table,
                          referencedTable: $$ChannelsTableReferences
                              ._postsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChannelsTableReferences(
                                db,
                                table,
                                p0,
                              ).postsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.channelId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (folderChannelsRefs)
                        await $_getPrefetchedData<
                          ChannelEntry,
                          $ChannelsTable,
                          FolderChannel
                        >(
                          currentTable: table,
                          referencedTable: $$ChannelsTableReferences
                              ._folderChannelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChannelsTableReferences(
                                db,
                                table,
                                p0,
                              ).folderChannelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.channelDbId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChannelsTable,
      ChannelEntry,
      $$ChannelsTableFilterComposer,
      $$ChannelsTableOrderingComposer,
      $$ChannelsTableAnnotationComposer,
      $$ChannelsTableCreateCompanionBuilder,
      $$ChannelsTableUpdateCompanionBuilder,
      (ChannelEntry, $$ChannelsTableReferences),
      ChannelEntry,
      PrefetchHooks Function({
        bool accountId,
        bool postsRefs,
        bool folderChannelsRefs,
      })
    >;
typedef $$PostsTableCreateCompanionBuilder =
    PostsCompanion Function({
      Value<int> id,
      required int accountId,
      required int channelId,
      required int messageId,
      Value<String?> body,
      required DateTime publishedAt,
      Value<int> viewCount,
      Value<int> replyCount,
      Value<int> forwardCount,
      Value<String> reactionsJson,
      Value<bool> isBookmarked,
      Value<bool> isRead,
      Value<bool> isDeleted,
      Value<String?> linkPreviewUrl,
      Value<String?> linkPreviewTitle,
      Value<String?> linkPreviewDescription,
      Value<String?> linkPreviewImageUrl,
      Value<String?> forwardedFromTitle,
      Value<String?> forwardedFromUsername,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$PostsTableUpdateCompanionBuilder =
    PostsCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<int> channelId,
      Value<int> messageId,
      Value<String?> body,
      Value<DateTime> publishedAt,
      Value<int> viewCount,
      Value<int> replyCount,
      Value<int> forwardCount,
      Value<String> reactionsJson,
      Value<bool> isBookmarked,
      Value<bool> isRead,
      Value<bool> isDeleted,
      Value<String?> linkPreviewUrl,
      Value<String?> linkPreviewTitle,
      Value<String?> linkPreviewDescription,
      Value<String?> linkPreviewImageUrl,
      Value<String?> forwardedFromTitle,
      Value<String?> forwardedFromUsername,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$PostsTableReferences
    extends BaseReferences<_$AppDatabase, $PostsTable, PostEntry> {
  $$PostsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('posts__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ChannelsTable _channelIdTable(_$AppDatabase db) =>
      db.channels.createAlias('posts__channel_id__channels__id');

  $$ChannelsTableProcessedTableManager get channelId {
    final $_column = $_itemColumn<int>('channel_id')!;

    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_channelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MediaItemsTable, List<MediaItemEntry>>
  _mediaItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mediaItems,
    aliasName: 'posts__id__media_items__post_id',
  );

  $$MediaItemsTableProcessedTableManager get mediaItemsRefs {
    final manager = $$MediaItemsTableTableManager(
      $_db,
      $_db.mediaItems,
    ).filter((f) => f.postId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarkEntriesTable, List<BookmarkEntry>>
  _bookmarkEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarkEntries,
    aliasName: 'posts__id__bookmark_entries__post_id',
  );

  $$BookmarkEntriesTableProcessedTableManager get bookmarkEntriesRefs {
    final manager = $$BookmarkEntriesTableTableManager(
      $_db,
      $_db.bookmarkEntries,
    ).filter((f) => f.postId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _bookmarkEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PostsTableFilterComposer extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get viewCount => $composableBuilder(
    column: $table.viewCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get replyCount => $composableBuilder(
    column: $table.replyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get forwardCount => $composableBuilder(
    column: $table.forwardCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reactionsJson => $composableBuilder(
    column: $table.reactionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBookmarked => $composableBuilder(
    column: $table.isBookmarked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkPreviewUrl => $composableBuilder(
    column: $table.linkPreviewUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkPreviewTitle => $composableBuilder(
    column: $table.linkPreviewTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkPreviewDescription => $composableBuilder(
    column: $table.linkPreviewDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkPreviewImageUrl => $composableBuilder(
    column: $table.linkPreviewImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get forwardedFromTitle => $composableBuilder(
    column: $table.forwardedFromTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get forwardedFromUsername => $composableBuilder(
    column: $table.forwardedFromUsername,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableFilterComposer get channelId {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> mediaItemsRefs(
    Expression<bool> Function($$MediaItemsTableFilterComposer f) f,
  ) {
    final $$MediaItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableFilterComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarkEntriesRefs(
    Expression<bool> Function($$BookmarkEntriesTableFilterComposer f) f,
  ) {
    final $$BookmarkEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarkEntries,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarkEntriesTableFilterComposer(
            $db: $db,
            $table: $db.bookmarkEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PostsTableOrderingComposer
    extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get viewCount => $composableBuilder(
    column: $table.viewCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get replyCount => $composableBuilder(
    column: $table.replyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get forwardCount => $composableBuilder(
    column: $table.forwardCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reactionsJson => $composableBuilder(
    column: $table.reactionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBookmarked => $composableBuilder(
    column: $table.isBookmarked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkPreviewUrl => $composableBuilder(
    column: $table.linkPreviewUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkPreviewTitle => $composableBuilder(
    column: $table.linkPreviewTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkPreviewDescription => $composableBuilder(
    column: $table.linkPreviewDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkPreviewImageUrl => $composableBuilder(
    column: $table.linkPreviewImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get forwardedFromTitle => $composableBuilder(
    column: $table.forwardedFromTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get forwardedFromUsername => $composableBuilder(
    column: $table.forwardedFromUsername,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableOrderingComposer get channelId {
    final $$ChannelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableOrderingComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get viewCount =>
      $composableBuilder(column: $table.viewCount, builder: (column) => column);

  GeneratedColumn<int> get replyCount => $composableBuilder(
    column: $table.replyCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get forwardCount => $composableBuilder(
    column: $table.forwardCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reactionsJson => $composableBuilder(
    column: $table.reactionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBookmarked => $composableBuilder(
    column: $table.isBookmarked,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get linkPreviewUrl => $composableBuilder(
    column: $table.linkPreviewUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkPreviewTitle => $composableBuilder(
    column: $table.linkPreviewTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkPreviewDescription => $composableBuilder(
    column: $table.linkPreviewDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkPreviewImageUrl => $composableBuilder(
    column: $table.linkPreviewImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get forwardedFromTitle => $composableBuilder(
    column: $table.forwardedFromTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get forwardedFromUsername => $composableBuilder(
    column: $table.forwardedFromUsername,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableAnnotationComposer get channelId {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> mediaItemsRefs<T extends Object>(
    Expression<T> Function($$MediaItemsTableAnnotationComposer a) f,
  ) {
    final $$MediaItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookmarkEntriesRefs<T extends Object>(
    Expression<T> Function($$BookmarkEntriesTableAnnotationComposer a) f,
  ) {
    final $$BookmarkEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarkEntries,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarkEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarkEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PostsTable,
          PostEntry,
          $$PostsTableFilterComposer,
          $$PostsTableOrderingComposer,
          $$PostsTableAnnotationComposer,
          $$PostsTableCreateCompanionBuilder,
          $$PostsTableUpdateCompanionBuilder,
          (PostEntry, $$PostsTableReferences),
          PostEntry,
          PrefetchHooks Function({
            bool accountId,
            bool channelId,
            bool mediaItemsRefs,
            bool bookmarkEntriesRefs,
          })
        > {
  $$PostsTableTableManager(_$AppDatabase db, $PostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> channelId = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<DateTime> publishedAt = const Value.absent(),
                Value<int> viewCount = const Value.absent(),
                Value<int> replyCount = const Value.absent(),
                Value<int> forwardCount = const Value.absent(),
                Value<String> reactionsJson = const Value.absent(),
                Value<bool> isBookmarked = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> linkPreviewUrl = const Value.absent(),
                Value<String?> linkPreviewTitle = const Value.absent(),
                Value<String?> linkPreviewDescription = const Value.absent(),
                Value<String?> linkPreviewImageUrl = const Value.absent(),
                Value<String?> forwardedFromTitle = const Value.absent(),
                Value<String?> forwardedFromUsername = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PostsCompanion(
                id: id,
                accountId: accountId,
                channelId: channelId,
                messageId: messageId,
                body: body,
                publishedAt: publishedAt,
                viewCount: viewCount,
                replyCount: replyCount,
                forwardCount: forwardCount,
                reactionsJson: reactionsJson,
                isBookmarked: isBookmarked,
                isRead: isRead,
                isDeleted: isDeleted,
                linkPreviewUrl: linkPreviewUrl,
                linkPreviewTitle: linkPreviewTitle,
                linkPreviewDescription: linkPreviewDescription,
                linkPreviewImageUrl: linkPreviewImageUrl,
                forwardedFromTitle: forwardedFromTitle,
                forwardedFromUsername: forwardedFromUsername,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required int channelId,
                required int messageId,
                Value<String?> body = const Value.absent(),
                required DateTime publishedAt,
                Value<int> viewCount = const Value.absent(),
                Value<int> replyCount = const Value.absent(),
                Value<int> forwardCount = const Value.absent(),
                Value<String> reactionsJson = const Value.absent(),
                Value<bool> isBookmarked = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> linkPreviewUrl = const Value.absent(),
                Value<String?> linkPreviewTitle = const Value.absent(),
                Value<String?> linkPreviewDescription = const Value.absent(),
                Value<String?> linkPreviewImageUrl = const Value.absent(),
                Value<String?> forwardedFromTitle = const Value.absent(),
                Value<String?> forwardedFromUsername = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PostsCompanion.insert(
                id: id,
                accountId: accountId,
                channelId: channelId,
                messageId: messageId,
                body: body,
                publishedAt: publishedAt,
                viewCount: viewCount,
                replyCount: replyCount,
                forwardCount: forwardCount,
                reactionsJson: reactionsJson,
                isBookmarked: isBookmarked,
                isRead: isRead,
                isDeleted: isDeleted,
                linkPreviewUrl: linkPreviewUrl,
                linkPreviewTitle: linkPreviewTitle,
                linkPreviewDescription: linkPreviewDescription,
                linkPreviewImageUrl: linkPreviewImageUrl,
                forwardedFromTitle: forwardedFromTitle,
                forwardedFromUsername: forwardedFromUsername,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PostsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                channelId = false,
                mediaItemsRefs = false,
                bookmarkEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mediaItemsRefs) db.mediaItems,
                    if (bookmarkEntriesRefs) db.bookmarkEntries,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable: $$PostsTableReferences
                                        ._accountIdTable(db),
                                    referencedColumn: $$PostsTableReferences
                                        ._accountIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (channelId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.channelId,
                                    referencedTable: $$PostsTableReferences
                                        ._channelIdTable(db),
                                    referencedColumn: $$PostsTableReferences
                                        ._channelIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mediaItemsRefs)
                        await $_getPrefetchedData<
                          PostEntry,
                          $PostsTable,
                          MediaItemEntry
                        >(
                          currentTable: table,
                          referencedTable: $$PostsTableReferences
                              ._mediaItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PostsTableReferences(
                                db,
                                table,
                                p0,
                              ).mediaItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.postId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarkEntriesRefs)
                        await $_getPrefetchedData<
                          PostEntry,
                          $PostsTable,
                          BookmarkEntry
                        >(
                          currentTable: table,
                          referencedTable: $$PostsTableReferences
                              ._bookmarkEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PostsTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarkEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.postId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PostsTable,
      PostEntry,
      $$PostsTableFilterComposer,
      $$PostsTableOrderingComposer,
      $$PostsTableAnnotationComposer,
      $$PostsTableCreateCompanionBuilder,
      $$PostsTableUpdateCompanionBuilder,
      (PostEntry, $$PostsTableReferences),
      PostEntry,
      PrefetchHooks Function({
        bool accountId,
        bool channelId,
        bool mediaItemsRefs,
        bool bookmarkEntriesRefs,
      })
    >;
typedef $$MediaItemsTableCreateCompanionBuilder =
    MediaItemsCompanion Function({
      Value<int> id,
      required int postId,
      required String type,
      Value<String?> url,
      Value<String?> thumbnailUrl,
      Value<int> width,
      Value<int> height,
      Value<int> duration,
      Value<int> fileSize,
      Value<String?> fileName,
      Value<String?> mimeType,
      Value<String?> localPath,
      Value<int> sortOrder,
    });
typedef $$MediaItemsTableUpdateCompanionBuilder =
    MediaItemsCompanion Function({
      Value<int> id,
      Value<int> postId,
      Value<String> type,
      Value<String?> url,
      Value<String?> thumbnailUrl,
      Value<int> width,
      Value<int> height,
      Value<int> duration,
      Value<int> fileSize,
      Value<String?> fileName,
      Value<String?> mimeType,
      Value<String?> localPath,
      Value<int> sortOrder,
    });

final class $$MediaItemsTableReferences
    extends BaseReferences<_$AppDatabase, $MediaItemsTable, MediaItemEntry> {
  $$MediaItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PostsTable _postIdTable(_$AppDatabase db) =>
      db.posts.createAlias('media_items__post_id__posts__id');

  $$PostsTableProcessedTableManager get postId {
    final $_column = $_itemColumn<int>('post_id')!;

    final manager = $$PostsTableTableManager(
      $_db,
      $_db.posts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_postIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MediaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$PostsTableFilterComposer get postId {
    final $$PostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableFilterComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$PostsTableOrderingComposer get postId {
    final $$PostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableOrderingComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$PostsTableAnnotationComposer get postId {
    final $$PostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableAnnotationComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaItemsTable,
          MediaItemEntry,
          $$MediaItemsTableFilterComposer,
          $$MediaItemsTableOrderingComposer,
          $$MediaItemsTableAnnotationComposer,
          $$MediaItemsTableCreateCompanionBuilder,
          $$MediaItemsTableUpdateCompanionBuilder,
          (MediaItemEntry, $$MediaItemsTableReferences),
          MediaItemEntry,
          PrefetchHooks Function({bool postId})
        > {
  $$MediaItemsTableTableManager(_$AppDatabase db, $MediaItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> postId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => MediaItemsCompanion(
                id: id,
                postId: postId,
                type: type,
                url: url,
                thumbnailUrl: thumbnailUrl,
                width: width,
                height: height,
                duration: duration,
                fileSize: fileSize,
                fileName: fileName,
                mimeType: mimeType,
                localPath: localPath,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int postId,
                required String type,
                Value<String?> url = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => MediaItemsCompanion.insert(
                id: id,
                postId: postId,
                type: type,
                url: url,
                thumbnailUrl: thumbnailUrl,
                width: width,
                height: height,
                duration: duration,
                fileSize: fileSize,
                fileName: fileName,
                mimeType: mimeType,
                localPath: localPath,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({postId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (postId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.postId,
                                referencedTable: $$MediaItemsTableReferences
                                    ._postIdTable(db),
                                referencedColumn: $$MediaItemsTableReferences
                                    ._postIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MediaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaItemsTable,
      MediaItemEntry,
      $$MediaItemsTableFilterComposer,
      $$MediaItemsTableOrderingComposer,
      $$MediaItemsTableAnnotationComposer,
      $$MediaItemsTableCreateCompanionBuilder,
      $$MediaItemsTableUpdateCompanionBuilder,
      (MediaItemEntry, $$MediaItemsTableReferences),
      MediaItemEntry,
      PrefetchHooks Function({bool postId})
    >;
typedef $$BookmarkEntriesTableCreateCompanionBuilder =
    BookmarkEntriesCompanion Function({
      Value<int> id,
      required int accountId,
      required int postId,
      Value<DateTime> createdAt,
    });
typedef $$BookmarkEntriesTableUpdateCompanionBuilder =
    BookmarkEntriesCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<int> postId,
      Value<DateTime> createdAt,
    });

final class $$BookmarkEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $BookmarkEntriesTable, BookmarkEntry> {
  $$BookmarkEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('bookmark_entries__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PostsTable _postIdTable(_$AppDatabase db) =>
      db.posts.createAlias('bookmark_entries__post_id__posts__id');

  $$PostsTableProcessedTableManager get postId {
    final $_column = $_itemColumn<int>('post_id')!;

    final manager = $$PostsTableTableManager(
      $_db,
      $_db.posts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_postIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookmarkEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarkEntriesTable> {
  $$BookmarkEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PostsTableFilterComposer get postId {
    final $$PostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableFilterComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarkEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarkEntriesTable> {
  $$BookmarkEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PostsTableOrderingComposer get postId {
    final $$PostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableOrderingComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarkEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarkEntriesTable> {
  $$BookmarkEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PostsTableAnnotationComposer get postId {
    final $$PostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableAnnotationComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarkEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarkEntriesTable,
          BookmarkEntry,
          $$BookmarkEntriesTableFilterComposer,
          $$BookmarkEntriesTableOrderingComposer,
          $$BookmarkEntriesTableAnnotationComposer,
          $$BookmarkEntriesTableCreateCompanionBuilder,
          $$BookmarkEntriesTableUpdateCompanionBuilder,
          (BookmarkEntry, $$BookmarkEntriesTableReferences),
          BookmarkEntry,
          PrefetchHooks Function({bool accountId, bool postId})
        > {
  $$BookmarkEntriesTableTableManager(
    _$AppDatabase db,
    $BookmarkEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarkEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarkEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarkEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> postId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BookmarkEntriesCompanion(
                id: id,
                accountId: accountId,
                postId: postId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required int postId,
                Value<DateTime> createdAt = const Value.absent(),
              }) => BookmarkEntriesCompanion.insert(
                id: id,
                accountId: accountId,
                postId: postId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookmarkEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false, postId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable:
                                    $$BookmarkEntriesTableReferences
                                        ._accountIdTable(db),
                                referencedColumn:
                                    $$BookmarkEntriesTableReferences
                                        ._accountIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (postId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.postId,
                                referencedTable:
                                    $$BookmarkEntriesTableReferences
                                        ._postIdTable(db),
                                referencedColumn:
                                    $$BookmarkEntriesTableReferences
                                        ._postIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookmarkEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarkEntriesTable,
      BookmarkEntry,
      $$BookmarkEntriesTableFilterComposer,
      $$BookmarkEntriesTableOrderingComposer,
      $$BookmarkEntriesTableAnnotationComposer,
      $$BookmarkEntriesTableCreateCompanionBuilder,
      $$BookmarkEntriesTableUpdateCompanionBuilder,
      (BookmarkEntry, $$BookmarkEntriesTableReferences),
      BookmarkEntry,
      PrefetchHooks Function({bool accountId, bool postId})
    >;
typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      Value<int> id,
      required int accountId,
      required int folderId,
      required String title,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<int> folderId,
      Value<String> title,
    });

final class $$FoldersTableReferences
    extends BaseReferences<_$AppDatabase, $FoldersTable, FolderEntry> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('folders__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FolderChannelsTable, List<FolderChannel>>
  _folderChannelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.folderChannels,
    aliasName: 'folders__id__folder_channels__folder_db_id',
  );

  $$FolderChannelsTableProcessedTableManager get folderChannelsRefs {
    final manager = $$FolderChannelsTableTableManager(
      $_db,
      $_db.folderChannels,
    ).filter((f) => f.folderDbId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_folderChannelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> folderChannelsRefs(
    Expression<bool> Function($$FolderChannelsTableFilterComposer f) f,
  ) {
    final $$FolderChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folderChannels,
      getReferencedColumn: (t) => t.folderDbId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderChannelsTableFilterComposer(
            $db: $db,
            $table: $db.folderChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> folderChannelsRefs<T extends Object>(
    Expression<T> Function($$FolderChannelsTableAnnotationComposer a) f,
  ) {
    final $$FolderChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folderChannels,
      getReferencedColumn: (t) => t.folderDbId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.folderChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          FolderEntry,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (FolderEntry, $$FoldersTableReferences),
          FolderEntry,
          PrefetchHooks Function({bool accountId, bool folderChannelsRefs})
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> folderId = const Value.absent(),
                Value<String> title = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                accountId: accountId,
                folderId: folderId,
                title: title,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required int folderId,
                required String title,
              }) => FoldersCompanion.insert(
                id: id,
                accountId: accountId,
                folderId: folderId,
                title: title,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({accountId = false, folderChannelsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (folderChannelsRefs) db.folderChannels,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable: $$FoldersTableReferences
                                        ._accountIdTable(db),
                                    referencedColumn: $$FoldersTableReferences
                                        ._accountIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (folderChannelsRefs)
                        await $_getPrefetchedData<
                          FolderEntry,
                          $FoldersTable,
                          FolderChannel
                        >(
                          currentTable: table,
                          referencedTable: $$FoldersTableReferences
                              ._folderChannelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoldersTableReferences(
                                db,
                                table,
                                p0,
                              ).folderChannelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.folderDbId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      FolderEntry,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (FolderEntry, $$FoldersTableReferences),
      FolderEntry,
      PrefetchHooks Function({bool accountId, bool folderChannelsRefs})
    >;
typedef $$FolderChannelsTableCreateCompanionBuilder =
    FolderChannelsCompanion Function({
      Value<int> id,
      required int folderDbId,
      required int channelDbId,
    });
typedef $$FolderChannelsTableUpdateCompanionBuilder =
    FolderChannelsCompanion Function({
      Value<int> id,
      Value<int> folderDbId,
      Value<int> channelDbId,
    });

final class $$FolderChannelsTableReferences
    extends BaseReferences<_$AppDatabase, $FolderChannelsTable, FolderChannel> {
  $$FolderChannelsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FoldersTable _folderDbIdTable(_$AppDatabase db) =>
      db.folders.createAlias('folder_channels__folder_db_id__folders__id');

  $$FoldersTableProcessedTableManager get folderDbId {
    final $_column = $_itemColumn<int>('folder_db_id')!;

    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderDbIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ChannelsTable _channelDbIdTable(_$AppDatabase db) =>
      db.channels.createAlias('folder_channels__channel_db_id__channels__id');

  $$ChannelsTableProcessedTableManager get channelDbId {
    final $_column = $_itemColumn<int>('channel_db_id')!;

    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_channelDbIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FolderChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $FolderChannelsTable> {
  $$FolderChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  $$FoldersTableFilterComposer get folderDbId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderDbId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableFilterComposer get channelDbId {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelDbId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FolderChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $FolderChannelsTable> {
  $$FolderChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoldersTableOrderingComposer get folderDbId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderDbId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableOrderingComposer get channelDbId {
    final $$ChannelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelDbId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableOrderingComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FolderChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FolderChannelsTable> {
  $$FolderChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  $$FoldersTableAnnotationComposer get folderDbId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderDbId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableAnnotationComposer get channelDbId {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelDbId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FolderChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FolderChannelsTable,
          FolderChannel,
          $$FolderChannelsTableFilterComposer,
          $$FolderChannelsTableOrderingComposer,
          $$FolderChannelsTableAnnotationComposer,
          $$FolderChannelsTableCreateCompanionBuilder,
          $$FolderChannelsTableUpdateCompanionBuilder,
          (FolderChannel, $$FolderChannelsTableReferences),
          FolderChannel,
          PrefetchHooks Function({bool folderDbId, bool channelDbId})
        > {
  $$FolderChannelsTableTableManager(
    _$AppDatabase db,
    $FolderChannelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FolderChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FolderChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FolderChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> folderDbId = const Value.absent(),
                Value<int> channelDbId = const Value.absent(),
              }) => FolderChannelsCompanion(
                id: id,
                folderDbId: folderDbId,
                channelDbId: channelDbId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int folderDbId,
                required int channelDbId,
              }) => FolderChannelsCompanion.insert(
                id: id,
                folderDbId: folderDbId,
                channelDbId: channelDbId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FolderChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderDbId = false, channelDbId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (folderDbId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.folderDbId,
                                referencedTable: $$FolderChannelsTableReferences
                                    ._folderDbIdTable(db),
                                referencedColumn:
                                    $$FolderChannelsTableReferences
                                        ._folderDbIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (channelDbId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.channelDbId,
                                referencedTable: $$FolderChannelsTableReferences
                                    ._channelDbIdTable(db),
                                referencedColumn:
                                    $$FolderChannelsTableReferences
                                        ._channelDbIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FolderChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FolderChannelsTable,
      FolderChannel,
      $$FolderChannelsTableFilterComposer,
      $$FolderChannelsTableOrderingComposer,
      $$FolderChannelsTableAnnotationComposer,
      $$FolderChannelsTableCreateCompanionBuilder,
      $$FolderChannelsTableUpdateCompanionBuilder,
      (FolderChannel, $$FolderChannelsTableReferences),
      FolderChannel,
      PrefetchHooks Function({bool folderDbId, bool channelDbId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db, _db.channels);
  $$PostsTableTableManager get posts =>
      $$PostsTableTableManager(_db, _db.posts);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db, _db.mediaItems);
  $$BookmarkEntriesTableTableManager get bookmarkEntries =>
      $$BookmarkEntriesTableTableManager(_db, _db.bookmarkEntries);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$FolderChannelsTableTableManager get folderChannels =>
      $$FolderChannelsTableTableManager(_db, _db.folderChannels);
}
