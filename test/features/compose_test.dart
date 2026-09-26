import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_draft.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/domain/compose_target.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

import '../support/td_fixtures.dart';

ComposeTarget _target({
  int chatId = 1,
  ComposeTargetKind kind = ComposeTargetKind.channel,
}) => ComposeTarget(chatId: chatId, title: 'Somewhere', kind: kind);

ComposeAttachment _photo({String path = '/tmp/a.jpg'}) => ComposeAttachment(
  path: path,
  kind: ComposeMediaKind.photo,
  width: 1200,
  height: 800,
);

ComposeAttachment _video() => const ComposeAttachment(
  path: '/tmp/a.mp4',
  kind: ComposeMediaKind.video,
  width: 1920,
  height: 1080,
  durationSeconds: 42,
);

/// Stands in for the live target list, which reads the chat cache.
class _FixedTargets extends ComposeTargetsNotifier {
  _FixedTargets(this._targets);

  final List<ComposeTarget> _targets;

  @override
  List<ComposeTarget> build() => _targets;
}

const _sticker = ComposeRemoteMedia(
  fileId: 900,
  kind: ComposeRemoteKind.sticker,
  width: 512,
  height: 512,
  emoji: '🎉',
);

const _gif = ComposeRemoteMedia(
  fileId: 901,
  kind: ComposeRemoteKind.animation,
  width: 480,
  height: 270,
  durationSeconds: 3,
);

void main() {
  group('ComposeTargets.fromChats', () {
    test('channels come before groups, groups before direct chats', () {
      final targets = ComposeTargets.fromChats([
        TdFixtures.privateChat(id: 7),
        TdFixtures.chat(
          id: -100200,
          title: 'A group',
          isChannel: false,
          mainOrder: 5,
          canSendBasicMessages: true,
        ),
        TdFixtures.chat(id: -100100, title: 'My channel', mainOrder: 1),
      ]);

      expect(targets.map((t) => t.kind), [
        ComposeTargetKind.channel,
        ComposeTargetKind.group,
        ComposeTargetKind.direct,
      ]);
    });

    // The rule that makes this list different from the forward picker's. TDLib
    // orders by recency alone, which puts the group somebody chatted in five
    // minutes ago above the channel they opened this screen to post to.
    test('a busier group does not outrank a quiet channel', () {
      final targets = ComposeTargets.fromChats([
        TdFixtures.chat(
          id: -100200,
          title: 'Busy group',
          isChannel: false,
          mainOrder: 9999,
          canSendBasicMessages: true,
        ),
        TdFixtures.chat(id: -100100, title: 'Quiet channel', mainOrder: 1),
      ]);

      expect(targets.first.title, 'Quiet channel');
    });

    test('within one kind, the most recent comes first', () {
      final targets = ComposeTargets.fromChats([
        TdFixtures.chat(id: -100100, title: 'Older', mainOrder: 10),
        TdFixtures.chat(id: -100200, title: 'Newer', mainOrder: 90),
      ]);

      expect(targets.map((t) => t.title), ['Newer', 'Older']);
    });

    test('a private chat with yourself is Saved Messages', () {
      final targets = ComposeTargets.fromChats([
        TdFixtures.privateChat(id: 42),
      ], selfUserId: 42);

      expect(targets.single.kind, ComposeTargetKind.savedMessages);
    });

    test('and with anybody else is not', () {
      final targets = ComposeTargets.fromChats([
        TdFixtures.privateChat(id: 43),
      ], selfUserId: 42);

      expect(targets.single.kind, ComposeTargetKind.direct);
    });

    // The account record loads asynchronously, so the id can genuinely be
    // missing on the first build. Reading as a direct chat is the safe answer:
    // it is still a destination, just under a different heading.
    test(
      'without knowing who you are, Saved Messages reads as a direct chat',
      () {
        final targets = ComposeTargets.fromChats([
          TdFixtures.privateChat(id: 42),
        ]);

        expect(targets.single.kind, ComposeTargetKind.direct);
      },
    );

    test('a basic group is a group', () {
      final targets = ComposeTargets.fromChats([
        TdFixtures.basicGroupChat(id: -55),
      ]);

      expect(targets.single.kind, ComposeTargetKind.group);
    });

    test('carries the chat photo through for the picker to draw', () {
      final targets = ComposeTargets.fromChats([
        TdFixtures.chat(id: -100100, mainOrder: 3),
      ]);

      expect(targets.single.chatId, -100100);
      expect(targets.single.mainListOrder, 3);
    });
  });

  group('ComposeDraft', () {
    test('nothing written and nothing attached cannot be posted', () {
      expect(ComposeDraft(target: _target()).canPost, isFalse);
    });

    test('whitespace is nothing written', () {
      final draft = ComposeDraft(target: _target(), text: '   \n  ');
      expect(draft.isEmpty, isTrue);
      expect(draft.canPost, isFalse);
    });

    test('a photo with no words is a post', () {
      final draft = ComposeDraft(target: _target(), attachments: [_photo()]);
      expect(draft.canPost, isTrue);
    });

    test('with nowhere to send it, it cannot be posted', () {
      const draft = ComposeDraft(text: 'hello');
      expect(draft.canPost, isFalse);
    });

    test('a send already in flight refuses a second one', () {
      final draft = ComposeDraft(
        target: _target(),
        text: 'hello',
        isSending: true,
      );
      expect(draft.canPost, isFalse);
    });

    test('a plain post gets the full message length', () {
      final draft = ComposeDraft(target: _target(), text: 'hi');
      expect(draft.characterLimit, ComposeLengthLimits.free.text);
    });

    // The trap this class exists to make visible: attaching a photo turns the
    // message into a caption, and Telegram's caption limit is a quarter of the
    // message limit. A draft that was fine a second ago is now too long.
    test('attaching media drops the limit to the caption limit', () {
      final text = 'x' * 2000;
      final plain = ComposeDraft(target: _target(), text: text);
      final withPhoto = plain.copyWith(attachments: [_photo()]);

      expect(plain.isOverLimit, isFalse);
      expect(plain.canPost, isTrue);

      expect(withPhoto.characterLimit, ComposeLengthLimits.free.caption);
      expect(withPhoto.isOverLimit, isTrue);
      expect(withPhoto.canPost, isFalse);
    });

    test(
      'the counter reports what is left, and goes negative past the end',
      () {
        final draft = ComposeDraft(
          target: _target(),
          text: 'x' * (ComposeLengthLimits.free.text + 3),
        );
        expect(draft.remaining, -3);
        expect(draft.isOverLimit, isTrue);
      },
    );

    test('the tenth attachment is the last one', () {
      final full = ComposeDraft(
        target: _target(),
        attachments: [
          for (var i = 0; i < ComposeLimits.maxAttachments; i++)
            _photo(path: '/tmp/$i.jpg'),
        ],
      );
      expect(full.canAttachMore, isFalse);
      expect(full.copyWith(attachments: [_photo()]).canAttachMore, isTrue);
    });
  });

  // Telegram Premium raises the message limit to 8192 and the caption limit to
  // 4096 — four times the free caption allowance. A composer that assumed the
  // free tier would tell a subscriber they were out of room at a quarter of
  // their real limit, which is why the numbers are read from TDLib rather than
  // written down. Numbers per https://limits.tginfo.me/en.
  group('ComposeLengthLimits', () {
    test('free and Premium are the numbers Telegram publishes', () {
      expect(ComposeLengthLimits.free.text, 4096);
      expect(ComposeLengthLimits.free.caption, 1024);
      expect(ComposeLengthLimits.premium.text, 8192);
      expect(ComposeLengthLimits.premium.caption, 4096);
    });

    test('media switches which of the two applies', () {
      const limits = ComposeLengthLimits.premium;
      expect(limits.forDraft(hasMedia: false), 8192);
      expect(limits.forDraft(hasMedia: true), 4096);
    });

    test('a Premium draft has the room a free one would not', () {
      final text = 'x' * 3000;
      final free = ComposeDraft(
        target: _target(),
        text: text,
        attachments: [_photo()],
      );
      final premium = free.copyWith(limits: ComposeLengthLimits.premium);

      expect(free.canPost, isFalse);
      expect(premium.canPost, isTrue);
    });

    test('a draft assumes the free tier until told otherwise', () {
      expect(const ComposeDraft().limits, ComposeLengthLimits.free);
    });
  });

  // Telegram answers all three of these with one unhelpful error, and it does
  // so after the upload rather than before it.
  group('ComposeLimits.photoRejection', () {
    ComposeAttachment photo({
      int width = 1200,
      int height = 800,
      int sizeBytes = 1024,
    }) => ComposeAttachment(
      path: '/tmp/a.jpg',
      kind: ComposeMediaKind.photo,
      width: width,
      height: height,
      sizeBytes: sizeBytes,
    );

    test('an ordinary photo is fine', () {
      expect(ComposeLimits.photoRejection(photo()), isNull);
    });

    test('over ten megabytes is refused', () {
      expect(
        ComposeLimits.photoRejection(
          photo(sizeBytes: ComposeLimits.maxPhotoBytes + 1),
        ),
        ComposePhotoRejection.tooLarge,
      );
    });

    // The ceiling is on width *plus* height, not on either alone — so two
    // dimensions that each look reasonable can still fail together.
    test('width plus height over ten thousand is refused', () {
      expect(
        ComposeLimits.photoRejection(photo(width: 6000, height: 5000)),
        ComposePhotoRejection.tooManyPixels,
      );
    });

    test('a panorama past twenty to one is refused', () {
      expect(
        ComposeLimits.photoRejection(photo(width: 2100, height: 100)),
        ComposePhotoRejection.tooWide,
      );
    });

    test('exactly twenty to one still goes', () {
      expect(
        ComposeLimits.photoRejection(photo(width: 2000, height: 100)),
        isNull,
      );
    });

    // Refusing on a measurement that failed would block a photo Telegram would
    // have taken. Let it through and let the server decide.
    test('a photo the probe could not measure is not judged', () {
      expect(ComposeLimits.photoRejection(photo(width: 0, height: 0)), isNull);
    });

    test('a video is not held to the photo rules', () {
      expect(ComposeLimits.photoRejection(_video()), isNull);
    });
  });

  // The regression this group exists for: signing in never reached the feed.
  //
  // Login had in fact succeeded — the account was in the database, and a
  // relaunch went straight to the feed. What failed was the *frame*. Rebuilding
  // the destination list filters and sorts every cached chat, and it was doing
  // that once per chat update; the initial sync delivers those in a burst of
  // hundreds, synchronously, on the UI thread. The UI froze, and a frozen UI
  // keeps painting its last frame — "Loading account profile", long after the
  // profile had loaded.
  group('ComposeTargetsNotifier coalescing', () {
    late StreamController<void> changes;
    late int rebuilds;

    ProviderContainer containerWith() {
      changes = StreamController<void>.broadcast();
      rebuilds = 0;

      final container = ProviderContainer(
        overrides: [
          chatCacheChangesProvider.overrideWithValue(changes.stream),
          composeTargetsSourceProvider.overrideWithValue(() {
            rebuilds++;
            return [_target()];
          }),
        ],
      );
      addTearDown(() {
        container.dispose();
        changes.close();
      });
      return container;
    }

    /// Long enough for the settle window to have elapsed.
    Future<void> settle() =>
        Future<void>.delayed(ComposeTargetsNotifier.settleWindow * 2);

    test('a burst of chat updates costs one rebuild, not one each', () async {
      final container = containerWith();
      container.listen(composeTargetsProvider, (_, _) {});
      expect(rebuilds, 1, reason: 'the initial build');

      for (var i = 0; i < 200; i++) {
        changes.add(null);
      }
      await settle();

      expect(
        rebuilds,
        2,
        reason: '200 updates in a burst must collapse into one recompute',
      );
    });

    test('updates far apart are not collapsed into one', () async {
      final container = containerWith();
      container.listen(composeTargetsProvider, (_, _) {});

      changes.add(null);
      await settle();
      changes.add(null);
      await settle();

      expect(rebuilds, 3, reason: 'the build, then one per settled update');
    });

    test('a pending recompute does not fire after disposal', () async {
      final container = containerWith();
      container.listen(composeTargetsProvider, (_, _) {});

      changes.add(null);
      // Disposed mid-window, so the timer is still armed when it goes.
      container.dispose();
      await settle();

      expect(rebuilds, 1, reason: 'only the initial build ever ran');
    });
  });

  group('ComposeMessages.build', () {
    test('no attachments makes one text message', () {
      final contents = ComposeMessages.build(
        text: 'hello',
        attachments: const [],
      );

      expect(contents, hasLength(1));
      final content = contents.single as td.InputMessageText;
      expect(content.text.text, 'hello');
      expect(ComposeMessages.isAlbum(contents), isFalse);
    });

    test('one photo makes one message, not an album', () {
      final contents = ComposeMessages.build(
        text: 'look',
        attachments: [_photo()],
      );

      expect(contents, hasLength(1));
      expect(ComposeMessages.isAlbum(contents), isFalse);

      final content = contents.single as td.InputMessagePhoto;
      expect(content.caption?.text, 'look');
      expect(content.width, 1200);
      expect(content.height, 800);
      expect((content.photo as td.InputFileLocal).path, '/tmp/a.jpg');
    });

    // Repeating the caption on every album item is what a naive loop does, and
    // Telegram renders it once under each picture.
    test('an album captions the first item and only the first', () {
      final contents = ComposeMessages.build(
        text: 'three of them',
        attachments: [
          _photo(path: '/tmp/1.jpg'),
          _photo(path: '/tmp/2.jpg'),
          _photo(path: '/tmp/3.jpg'),
        ],
      );

      expect(contents, hasLength(3));
      expect(ComposeMessages.isAlbum(contents), isTrue);

      final captions = contents
          .cast<td.InputMessagePhoto>()
          .map((c) => c.caption?.text)
          .toList();
      expect(captions, ['three of them', null, null]);
    });

    test('two attachments is already an album', () {
      final contents = ComposeMessages.build(
        text: '',
        attachments: [
          _photo(path: '/tmp/1.jpg'),
          _photo(path: '/tmp/2.jpg'),
        ],
      );
      expect(ComposeMessages.isAlbum(contents), isTrue);
    });

    test('a wordless media post carries no caption at all', () {
      final contents = ComposeMessages.build(text: '', attachments: [_photo()]);

      expect((contents.single as td.InputMessagePhoto).caption, isNull);
    });

    test('a video carries its duration', () {
      final contents = ComposeMessages.build(text: '', attachments: [_video()]);

      final content = contents.single as td.InputMessageVideo;
      expect(content.duration, 42);
      expect(content.width, 1920);
      expect(content.height, 1080);
    });

    // gramX does not transcode, so it cannot know whether a picked video was
    // muxed with its index at the front. Claiming otherwise stalls every player
    // that trusts the flag — this app's own streaming path included.
    test('a video is never claimed to be streamable', () {
      final contents = ComposeMessages.build(text: '', attachments: [_video()]);

      expect(
        (contents.single as td.InputMessageVideo).supportsStreaming,
        isFalse,
      );
    });

    test('photos and videos mix in one album', () {
      final contents = ComposeMessages.build(
        text: 'mixed',
        attachments: [_photo(), _video()],
      );

      expect(contents.first, isA<td.InputMessagePhoto>());
      expect(contents.last, isA<td.InputMessageVideo>());
      expect((contents.last as td.InputMessageVideo).caption, isNull);
    });
  });

  // The hard rule: a control that renders and does
  // nothing is a bug. The compose button has two ways to become one, and both
  // are here.

  // Stickers and GIFs are not two flavours of one thing, and the difference is
  // the whole reason this group exists: `inputMessageSticker` has no caption
  // field, `inputMessageAnimation` does, and neither can go in an album.
  group('stickers and GIFs', () {
    test('a sticker alone is a post', () {
      final draft = ComposeDraft(target: _target()).withRemote(_sticker);
      expect(draft.isEmpty, isFalse);
      expect(draft.canPost, isTrue);
    });

    // The one that would otherwise drop what somebody wrote: there is nowhere
    // on a sticker message for the text to go, so it must not send silently.
    test('a sticker refuses to carry words', () {
      final draft = ComposeDraft(
        target: _target(),
        text: 'happy birthday',
      ).withRemote(_sticker);

      expect(draft.stickerBlocksText, isTrue);
      expect(draft.canPost, isFalse);
    });

    test('clearing the words unblocks it', () {
      final draft = ComposeDraft(
        target: _target(),
        text: 'hi',
      ).withRemote(_sticker).copyWith(text: '');

      expect(draft.stickerBlocksText, isFalse);
      expect(draft.canPost, isTrue);
    });

    test('a GIF does take a caption', () {
      final draft = ComposeDraft(
        target: _target(),
        text: 'look at this',
      ).withRemote(_gif);

      expect(draft.stickerBlocksText, isFalse);
      expect(draft.canPost, isTrue);
      expect(draft.isCaptioned, isTrue);
      expect(draft.characterLimit, ComposeLengthLimits.free.caption);
    });

    // A sticker takes no caption at all, so it is not "captioned" and the limit
    // question never applies to it.
    test('a sticker is not captioned', () {
      final draft = ComposeDraft(target: _target()).withRemote(_sticker);
      expect(draft.isCaptioned, isFalse);
    });

    // sendMessageAlbum groups only audio, document, photo and video — so these
    // two selections cannot coexist, and picking one must drop the other.
    test('choosing a sticker drops the photos', () {
      final draft = ComposeDraft(
        target: _target(),
        attachments: [_photo()],
      ).withRemote(_gif);

      expect(draft.attachments, isEmpty);
      expect(draft.remote, _gif);
    });

    test('choosing photos drops the sticker', () {
      final draft = ComposeDraft(
        target: _target(),
      ).withRemote(_sticker).withAttachments([_photo()]);

      expect(draft.remote, isNull);
      expect(draft.attachments, hasLength(1));
    });

    test('nothing more can be attached while one is chosen', () {
      final draft = ComposeDraft(target: _target()).withRemote(_gif);
      expect(draft.canAttachMore, isFalse);
    });

    test('withRemote(null) clears it', () {
      final draft = ComposeDraft(
        target: _target(),
      ).withRemote(_sticker).withRemote(null);
      expect(draft.remote, isNull);
      expect(draft.isEmpty, isTrue);
    });
  });

  group('ComposeMessages.build for stickers and GIFs', () {
    test('a sticker is one sticker message, never an album', () {
      final contents = ComposeMessages.build(
        text: '',
        attachments: const [],
        remote: _sticker,
      );

      expect(contents, hasLength(1));
      expect(ComposeMessages.isAlbum(contents), isFalse);

      final content = contents.single as td.InputMessageSticker;
      expect((content.sticker as td.InputFileId).id, 900);
      expect(content.emoji, '🎉');
      expect(content.width, 512);
    });

    test('a GIF carries its caption and duration', () {
      final contents = ComposeMessages.build(
        text: 'look',
        attachments: const [],
        remote: _gif,
      );

      final content = contents.single as td.InputMessageAnimation;
      expect(content.caption?.text, 'look');
      expect(content.duration, 3);
      expect((content.animation as td.InputFileId).id, 901);
    });

    test('a wordless GIF carries no caption', () {
      final contents = ComposeMessages.build(
        text: '',
        attachments: const [],
        remote: _gif,
      );

      expect((contents.single as td.InputMessageAnimation).caption, isNull);
    });

    // Sent by file id, not re-uploaded: the file is already on Telegram's
    // servers, so posting a sticker moves no bytes.
    test('neither is uploaded again', () {
      for (final media in [_sticker, _gif]) {
        final contents = ComposeMessages.build(
          text: '',
          attachments: const [],
          remote: media,
        );
        final content = contents.single;
        final file = content is td.InputMessageSticker
            ? content.sticker
            : (content as td.InputMessageAnimation).animation;
        expect(file, isA<td.InputFileId>());
      }
    });

    // The draft makes these exclusive; this pins that the builder agrees, so a
    // caller that somehow passes both cannot produce a mixed album.
    test('a chosen sticker wins over any attachments', () {
      final contents = ComposeMessages.build(
        text: '',
        attachments: [
          _photo(),
          _photo(path: '/tmp/2.jpg'),
        ],
        remote: _sticker,
      );

      expect(contents, hasLength(1));
      expect(contents.single, isA<td.InputMessageSticker>());
    });
  });

  group('canComposeProvider', () {
    ProviderContainer containerWith({
      required ReaderCapabilities capabilities,
      required List<ComposeTarget> targets,
    }) {
      final container = ProviderContainer(
        overrides: [
          readerCapabilitiesProvider.overrideWithValue(capabilities),
          composeTargetsProvider.overrideWith(() => _FixedTargets(targets)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a guest has no account to post as, so there is no button', () {
      final container = containerWith(
        capabilities: ReaderCapabilities.guest,
        targets: [_target()],
      );

      expect(container.read(canComposeProvider), isFalse);
    });

    test('signed in with nowhere to post, there is still no button', () {
      final container = containerWith(
        capabilities: ReaderCapabilities.signedIn,
        targets: const [],
      );

      expect(container.read(canComposeProvider), isFalse);
    });

    test('one destination is enough', () {
      final container = containerWith(
        capabilities: ReaderCapabilities.signedIn,
        targets: [_target()],
      );

      expect(container.read(canComposeProvider), isTrue);
    });
  });
}
