import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/presentation/post_progress_provider.dart';

import '../support/td_fixtures.dart';

td.File _file({
  required int id,
  int size = 0,
  int expectedSize = 0,
  int uploaded = 0,
}) => td.File(
  id: id,
  size: size,
  expectedSize: expectedSize,
  local: const td.LocalFile(
    path: '',
    canBeDownloaded: false,
    canBeDeleted: false,
    isDownloadingActive: false,
    isDownloadingCompleted: false,
    downloadOffset: 0,
    downloadedPrefixSize: 0,
    downloadedSize: 0,
  ),
  remote: td.RemoteFile(
    id: '$id',
    uniqueId: '$id',
    isUploadingActive: uploaded > 0,
    isUploadingCompleted: false,
    uploadedSize: uploaded,
  ),
);

void main() {
  group('UploadTally', () {
    const watched = {10, 20};

    test('a file this post does not own changes nothing', () {
      const tally = UploadTally();
      final next = tally.apply(_file(id: 99, size: 100, uploaded: 50), watched);

      expect(identical(next, tally), isTrue);
      expect(next.fraction, isNull);
    });

    test('one file uploading gives its own fraction', () {
      final tally = const UploadTally().apply(
        _file(id: 10, size: 200, uploaded: 50),
        watched,
      );

      expect(tally.fraction, 0.25);
    });

    // TDLib reports `expectedSize` before it knows and `size` once it does. A
    // tally that read only one of them would have no denominator for half the
    // life of the upload.
    test('expectedSize stands in until size is known', () {
      final tally = const UploadTally().apply(
        _file(id: 10, expectedSize: 400, uploaded: 100),
        watched,
      );

      expect(tally.fraction, 0.25);
    });

    // Summed rather than averaged: three attachments of wildly different sizes
    // should move the bar by what they actually cost, not a third each.
    test('several files are weighted by size, not counted equally', () {
      final tally = const UploadTally()
          .apply(_file(id: 10, size: 900, uploaded: 0), watched)
          .apply(_file(id: 20, size: 100, uploaded: 100), watched);

      // The small one finished; that is a tenth of the work, not a half.
      expect(tally.fraction, 0.1);
    });

    test('a later update replaces the earlier one for the same file', () {
      final tally = const UploadTally()
          .apply(_file(id: 10, size: 100, uploaded: 10), watched)
          .apply(_file(id: 10, size: 100, uploaded: 90), watched);

      expect(tally.fraction, 0.9);
    });

    test('nothing sized yet has no fraction to show', () {
      final tally = const UploadTally().apply(
        _file(id: 10, uploaded: 0),
        watched,
      );

      expect(tally.fraction, isNull);
    });

    test('the fraction never leaves 0…1', () {
      final tally = const UploadTally().apply(
        _file(id: 10, size: 100, uploaded: 500),
        watched,
      );

      expect(tally.fraction, 1.0);
    });
  });

  group('ComposeMessages.uploadingFileIds', () {
    // The largest photo size is the one that takes the time; the smaller ones
    // are generated from it. Counting them all would average a thumbnail's
    // instant completion against the real upload.
    test('a photo contributes only its largest size', () {
      final message = TdFixtures.photoMessage(
        id: 1,
        chatId: -100,
        fileIds: [7, 8, 9],
      );

      expect(ComposeMessages.uploadingFileIds(message), [9]);
    });

    test('a video contributes its file', () {
      final message = TdFixtures.videoMessage(id: 1, chatId: -100, fileId: 42);

      expect(ComposeMessages.uploadingFileIds(message), [42]);
    });

    // A sticker is already on Telegram's servers, so nothing goes up for it
    // and the bar has nothing to measure — which is why it runs indeterminate.
    test('a text post uploads nothing', () {
      final message = TdFixtures.textMessage(id: 1, chatId: -100);

      expect(ComposeMessages.uploadingFileIds(message), isEmpty);
    });
  });

  group('ComposeSendResult', () {
    test('a refused send is not accepted and watches nothing', () {
      expect(ComposeSendResult.refused.accepted, isFalse);
      expect(ComposeSendResult.refused.hasUpload, isFalse);
    });

    test('a text post is accepted with nothing to measure', () {
      const result = ComposeSendResult(accepted: true, messageIds: [1]);

      expect(result.accepted, isTrue);
      expect(result.hasUpload, isFalse);
    });

    test('a post with media has something to watch', () {
      const result = ComposeSendResult(
        accepted: true,
        messageIds: [1],
        fileIds: [9],
      );

      expect(result.hasUpload, isTrue);
    });
  });

  group('PostSendProgress', () {
    test('copyWith keeps the target it is going to', () {
      const progress = PostSendProgress(
        status: PostSendStatus.uploading,
        targetLabel: 'ragoose_dumps',
        fraction: 0.2,
      );

      final next = progress.copyWith(status: PostSendStatus.sent);
      expect(next.targetLabel, 'ragoose_dumps');
      expect(next.fraction, 0.2);
    });
  });
}
