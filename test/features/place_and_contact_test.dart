import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chat_events.dart';
import 'package:gramx/features/chats/data/chat_message_mapper.dart';
import 'package:gramx/features/chats/data/conversation_state.dart';
import 'package:gramx/features/chats/domain/message_place.dart';

import '../support/td_fixtures.dart';

void main() {
  group('a location in a conversation', () {
    // Before this, `messageLocation` fell through to the feed's label — the
    // words "📍 Location" with the coordinates thrown away, so the one thing a
    // location is for could not be done with it.
    test('carries its coordinates rather than a label', () {
      final message = ChatMessageMapper.map(
        TdFixtures.locationMessage(id: 1, chatId: 9),
        users: const {},
        lastReadOutboxMessageId: 0,
      );

      expect(message.place, isNotNull);
      expect(message.place!.latitude, closeTo(51.5007, 0.0001));
      expect(message.place!.longitude, closeTo(-0.1246, 0.0001));
      expect(message.place!.isVenue, isFalse);
      expect(message.text, isNull);
    });

    test('a venue carries its name and address too', () {
      final message = ChatMessageMapper.map(
        TdFixtures.venueMessage(id: 1, chatId: 9),
        users: const {},
        lastReadOutboxMessageId: 0,
      );

      expect(message.place!.isVenue, isTrue);
      expect(message.place!.title, 'Big Ben');
      expect(message.place!.address, 'Westminster');
    });

    test('a live location that has run out is not live any more', () {
      final still = ChatMessageMapper.map(
        TdFixtures.locationMessage(
          id: 1,
          chatId: 9,
          livePeriod: 3600,
          expiresIn: 0,
        ),
        users: const {},
        lastReadOutboxMessageId: 0,
      ).place!;

      expect(still.isLive, isTrue);
      // Saying "live" over something that stopped moving hours ago is the
      // failure this separates out.
      expect(still.isLiveNow, isFalse);
    });

    test('a live location still running says so', () {
      final live = ChatMessageMapper.map(
        TdFixtures.locationMessage(
          id: 1,
          chatId: 9,
          livePeriod: 3600,
          expiresIn: 1200,
        ),
        users: const {},
        lastReadOutboxMessageId: 0,
      ).place!;

      expect(live.isLiveNow, isTrue);
    });
  });

  group('the geo URI', () {
    test('a bare location is a plain point', () {
      const place = MessagePlace(latitude: 51.5, longitude: -0.12);
      expect(place.geoUri, 'geo:51.5,-0.12');
    });

    // A venue arrives named rather than as a dropped pin with numbers under it.
    test('a venue carries its name as a query', () {
      const place = MessagePlace(
        latitude: 51.5,
        longitude: -0.12,
        title: 'Big Ben',
      );
      expect(place.geoUri, 'geo:51.5,-0.12?q=Big%20Ben');
    });
  });

  group('a contact in a conversation', () {
    test('carries the card rather than a label', () {
      final message = ChatMessageMapper.map(
        TdFixtures.contactMessage(id: 1, chatId: 9),
        users: const {},
        lastReadOutboxMessageId: 0,
      );

      expect(message.contact, isNotNull);
      expect(message.contact!.displayName, 'Ada Lovelace');
      expect(message.contact!.formattedPhoneNumber, '+442071234567');
      expect(message.contact!.hasTelegramAccount, isTrue);
      expect(message.text, isNull);
    });

    test('a contact not on Telegram leads nowhere', () {
      final message = ChatMessageMapper.map(
        TdFixtures.contactMessage(id: 1, chatId: 9, userId: 0),
        users: const {},
        lastReadOutboxMessageId: 0,
      );

      expect(message.contact!.hasTelegramAccount, isFalse);
    });

    test('a nameless contact falls back to its number', () {
      final message = ChatMessageMapper.map(
        TdFixtures.contactMessage(
          id: 1,
          chatId: 9,
          firstName: '',
          lastName: '',
        ),
        users: const {},
        lastReadOutboxMessageId: 0,
      );

      expect(message.contact!.displayName, '442071234567');
    });

    test('a hidden number leaves nothing to format', () {
      final message = ChatMessageMapper.map(
        TdFixtures.contactMessage(id: 1, chatId: 9, phoneNumber: ''),
        users: const {},
        lastReadOutboxMessageId: 0,
      );

      expect(message.contact!.formattedPhoneNumber, isNull);
    });
  });

  group('pinning one message', () {
    test('a pin arriving on the update stream reaches the bubble', () {
      final message = ChatMessageMapper.map(
        TdFixtures.textMessage(id: 5, chatId: 9),
        users: const {},
        lastReadOutboxMessageId: 0,
      );
      expect(message.isPinned, isFalse);

      final pinned = ConversationState(chatId: 9, messages: [message]).apply(
        const ChatMessagePinChanged(9, 5, true),
        users: const {},
      );

      expect(pinned!.messages.single.isPinned, isTrue);

      final unpinned = pinned.apply(
        const ChatMessagePinChanged(9, 5, false),
        users: const {},
      );
      expect(unpinned!.messages.single.isPinned, isFalse);
    });

    test('updateMessageIsPinned maps to the pin event', () {
      final event = ChatEvents.map(
        const td.UpdateMessageIsPinned(
          chatId: 9,
          messageId: 5,
          isPinned: true,
        ),
      );

      expect(event, isA<ChatMessagePinChanged>());
      expect((event! as ChatMessagePinChanged).isPinned, isTrue);
    });
  });
}
