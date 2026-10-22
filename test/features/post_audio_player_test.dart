import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/presentation/widgets/post_audio_player.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

const int _fileId = 77;

const _track = MediaItem(
  id: 'track',
  type: MediaType.audio,
  fileId: _fileId,
  mimeType: 'audio/mpeg',
  duration: 200,
);

/// A file TDLib hasn't started downloading.
class _NotDownloaded implements TdlibService {
  @override
  Stream<td.UpdateFile> get fileUpdates => const Stream.empty();

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (function is td.GetFile) {
      return const td.File(
        id: _fileId,
        size: 4000000,
        expectedSize: 4000000,
        local: td.LocalFile(
          path: '',
          canBeDownloaded: true,
          canBeDeleted: false,
          isDownloadingActive: false,
          isDownloadingCompleted: false,
          downloadOffset: 0,
          downloadedPrefixSize: 0,
          downloadedSize: 0,
        ),
        remote: td.RemoteFile(
          id: 'remote',
          uniqueId: 'unique',
          isUploadingActive: false,
          isUploadingCompleted: true,
          uploadedSize: 0,
        ),
      );
    }
    return const td.Ok();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _RecordingSync implements SyncService {
  final List<int> downloads = [];

  @override
  Future<void> downloadFileWithPriority(int fileId, {int priority = 32}) async {
    downloads.add(fileId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Widget _host(MediaItem item, _RecordingSync sync) => ProviderScope(
  overrides: [
    tdlibServiceProvider.overrideWithValue(_NotDownloaded()),
    syncServiceProvider.overrideWithValue(sync),
  ],
  child: MaterialApp(
    home: Scaffold(body: PostAudioPlayer(item: item)),
  ),
);

void main() {
  // Music plays as it downloads, so its first tap is Play, not Download.
  testWidgets('a music track offers to play before it is downloaded', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_track, _RecordingSync()));
    await tester.pump();

    expect(find.byTooltip(AppStrings.audioPlay), findsOneWidget);
  });

  // Play streams, so saving a track without playing it needs its own button.
  testWidgets('a music track can be downloaded without playing it', (
    tester,
  ) async {
    final sync = _RecordingSync();
    await tester.pumpWidget(_host(_track, sync));
    await tester.pump();

    await tester.tap(find.byTooltip(AppStrings.audioDownload));
    await tester.pump();

    expect(sync.downloads, [_fileId]);
    expect(find.byTooltip(AppStrings.audioPlay), findsOneWidget);
  });

  // A voice message is small and is fetched whole. The tap that fetches it
  // also plays it once it lands.
  testWidgets('a voice message downloads on the first tap', (tester) async {
    final sync = _RecordingSync();
    await tester.pumpWidget(
      _host(
        const MediaItem(
          id: 'voice',
          type: MediaType.voice,
          fileId: _fileId,
          mimeType: 'audio/ogg',
          duration: 12,
        ),
        sync,
      ),
    );
    await tester.pump();

    expect(find.byTooltip(AppStrings.audioDownload), findsOneWidget);
    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pump();

    expect(sync.downloads, [_fileId]);
  });
}
