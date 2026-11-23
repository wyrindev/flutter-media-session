import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:flutter_media_session/flutter_media_session_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A platform whose actions a test can send, and which records the library provider.
class _ActionPlatform extends FlutterMediaSessionPlatform
    with MockPlatformInterfaceMixin {
  final actions = StreamController<MediaAction>.broadcast();
  MediaLibraryChildrenProvider? library;
  var activated = false;
  var permissionFails = false;

  @override
  Future<bool> requestNotificationPermission() async {
    if (permissionFails) {
      throw PlatformException(code: 'NO_ACTIVITY', message: 'no screen');
    }
    return true;
  }

  @override
  Future<void> activate() async => activated = true;

  @override
  Stream<MediaAction> get onMediaAction => actions.stream;

  @override
  Future<void> setMediaLibrary(
      MediaLibraryChildrenProvider? getChildren) async {
    library = getChildren;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_media_session');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('MediaLibraryItem', () {
    test('defaults to a playable item, not a folder; optional fields left out',
        () {
      const item = MediaLibraryItem(id: 'n1', title: 'Novel');
      expect(item.isPlayable, isTrue);
      expect(item.isBrowsable, isFalse);
      expect(item.toJson(), {
        'id': 'n1',
        'title': 'Novel',
        'isBrowsable': false,
        'isPlayable': true,
      });
    });

    test('a folder with a subtitle and artwork', () {
      const item = MediaLibraryItem(
        id: 'f',
        title: 'Continue reading',
        subtitle: '3 novels',
        artworkUri: 'https://example.com/a.png',
        isBrowsable: true,
        isPlayable: false,
      );
      expect(item.toJson(), {
        'id': 'f',
        'title': 'Continue reading',
        'subtitle': '3 novels',
        'artworkUri': 'https://example.com/a.png',
        'isBrowsable': true,
        'isPlayable': false,
      });
      expect(
          item,
          const MediaLibraryItem(
              id: 'f',
              title: 'Continue reading',
              subtitle: '3 novels',
              artworkUri: 'https://example.com/a.png',
              isBrowsable: true,
              isPlayable: false));
    });
  });

  group('method channel', () {
    late MethodChannelFlutterMediaSession platform;
    late List<MethodCall> calls;

    setUp(() {
      platform = MethodChannelFlutterMediaSession();
      calls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    /// The platform side asking Dart for a node's children, as the Android plugin does.
    Future<dynamic> askChildren(String parentId) async {
      final completer = Completer<dynamic>();
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
            MethodCall('getMediaLibraryChildren', {'parentId': parentId})),
        (data) {
          if (data == null) {
            completer.complete(null); // nothing answered
          } else {
            completer.complete(channel.codec.decodeEnvelope(data));
          }
        },
      );
      return completer.future;
    }

    test(
        'on Android, opting in tells the platform and answers requests for children',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final asked = <String>[];
      await platform.setMediaLibrary((parentId) async {
        asked.add(parentId);
        return parentId == MediaLibraryItem.rootId
            ? const [
                MediaLibraryItem(
                    id: 'continue',
                    title: 'Continue reading',
                    isBrowsable: true,
                    isPlayable: false)
              ]
            : const [MediaLibraryItem(id: 'n1', title: 'Novel 1')];
      });
      expect(calls.single.method, 'setMediaLibraryEnabled');
      expect(calls.single.arguments, isTrue);

      expect(await askChildren('root'), [
        {
          'id': 'continue',
          'title': 'Continue reading',
          'isBrowsable': true,
          'isPlayable': false
        }
      ]);
      expect(await askChildren('continue'), [
        {
          'id': 'n1',
          'title': 'Novel 1',
          'isBrowsable': false,
          'isPlayable': true
        }
      ]);
      expect(asked, ['root', 'continue']);
    });

    test('opting out tells the platform and stops answering', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await platform.setMediaLibrary((_) async => const []);
      await platform.setMediaLibrary(null);
      expect(calls.map((c) => (c.method, c.arguments)), [
        ('setMediaLibraryEnabled', true),
        ('setMediaLibraryEnabled', false),
      ]);
      expect(await askChildren('root'), isNull);
    });

    test('setResumptionItem sends the item and position on Android only',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await platform.setResumptionItem(
        const MediaLibraryItem(id: 'track-2', title: 'Song 3'),
        const Duration(seconds: 42),
      );
      await platform.setResumptionItem(null, Duration.zero);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await platform.setResumptionItem(
          const MediaLibraryItem(id: 'x', title: 'X'), Duration.zero);
      expect(calls.map((c) => c.method),
          ['setResumptionItem', 'setResumptionItem']);
      final saved = calls.first.arguments as Map;
      expect((saved['item'] as Map)['id'], 'track-2');
      expect(saved['positionMs'], 42000);
      expect((calls.last.arguments as Map)['item'], isNull);
    });

    test('wasStartedInBackground asks the platform on Android, false elsewhere',
        () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'wasStartedInBackground' ? true : null;
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await platform.wasStartedInBackground(), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(await platform.wasStartedInBackground(), isFalse);
      expect(calls.map((c) => c.method), ['wasStartedInBackground']);
    });

    test('elsewhere it does nothing (no media browsers)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await platform.setMediaLibrary((_) async => const []);
      expect(calls, isEmpty);
    });

    group('play requests from a browser or a voice command', () {
      const eventChannel = EventChannel('flutter_media_session_events');

      Future<MediaAction> receive(Object event) async {
        messenger.setMockMethodCallHandler(
          MethodChannel(eventChannel.name, eventChannel.codec),
          (call) async {
            if (call.method == 'listen') {
              await messenger.handlePlatformMessage(eventChannel.name,
                  eventChannel.codec.encodeSuccessEnvelope(event), (_) {});
            }
            return null;
          },
        );
        return platform.onMediaAction.first;
      }

      test('playFromMediaId carries the item id', () async {
        final action = await receive({
          'action': 'playFromMediaId',
          'args': {'mediaId': 'n1'}
        });
        expect(action, MediaAction.playFromMediaId);
        expect(action.mediaId, 'n1');
      });

      test('a resumed playFromMediaId carries its flag and position', () async {
        final resumed = await receive({
          'action': 'playFromMediaId',
          'args': {'mediaId': 'n1', 'resumed': true, 'positionMs': 177958}
        });
        expect(resumed.mediaId, 'n1');
        expect(resumed.isResumption, isTrue);
        expect(resumed.startPosition, const Duration(milliseconds: 177958));
      });

      test('a picked playFromMediaId is not a resumption', () async {
        final picked = await receive({
          'action': 'playFromMediaId',
          'args': {'mediaId': 'n1'}
        });
        expect(picked.isResumption, isFalse);
        expect(picked.startPosition, isNull);
      });

      test('playFromSearch carries the spoken query', () async {
        final action = await receive({
          'action': 'playFromSearch',
          'args': {'query': 'slow life'}
        });
        expect(action, MediaAction.playFromSearch);
        expect(action.query, 'slow life');
      });
    });
  });

  group('FlutterMediaSession', () {
    late _ActionPlatform fake;
    late FlutterMediaSessionPlatform original;

    setUp(() {
      original = FlutterMediaSessionPlatform.instance;
      fake = _ActionPlatform();
      FlutterMediaSessionPlatform.instance = fake;
    });

    tearDown(() {
      FlutterMediaSession().clearActionHandler();
      FlutterMediaSessionPlatform.instance = original;
    });

    test('setMediaLibrary and clearMediaLibrary pass the provider through',
        () async {
      Future<List<MediaLibraryItem>> provider(String _) async => const [];
      await FlutterMediaSession().setMediaLibrary(getChildren: provider);
      expect(fake.library, same(provider));
      await FlutterMediaSession().clearMediaLibrary();
      expect(fake.library, isNull);
    });

    test(
        'activate goes ahead when there is no screen to ask for notification permission from (started in the background)',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      fake.permissionFails = true;
      await FlutterMediaSession().activate();
      expect(fake.activated, isTrue);
    });

    test('setActionHandler routes playFromMediaId and playFromSearch',
        () async {
      final played = <String>[];
      final searched = <String>[];
      FlutterMediaSession().setActionHandler(
        onPlayFromMediaId: (id, resumeFrom) =>
            played.add(resumeFrom == null ? id : '$id@${resumeFrom.inSeconds}'),
        onPlayFromSearch: searched.add,
      );
      fake.actions.add(const MediaAction('playFromMediaId',
          customExtras: {'mediaId': 'n1'}));
      fake.actions.add(const MediaAction('playFromSearch',
          customExtras: {'query': 'continue reading'}));
      fake.actions.add(MediaAction.playFromMediaId); // no id: ignored
      fake.actions.add(const MediaAction('playFromMediaId', customExtras: {
        'mediaId': 'n2',
        'resumed': true,
        'positionMs': 42000
      }));
      fake.actions.add(const MediaAction('playFromMediaId',
          customExtras: {'mediaId': 'n3', 'resumed': true}));
      await Future<void>.delayed(Duration.zero);
      expect(played, ['n1', 'n2@42', 'n3@0']);
      expect(searched, ['continue reading']);
    });
  });
}
