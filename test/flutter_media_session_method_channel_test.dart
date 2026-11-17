import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_media_session/flutter_media_session_method_channel.dart';
import 'package:flutter_media_session/flutter_media_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterMediaSession platform =
      MethodChannelFlutterMediaSession();
  const MethodChannel channel = MethodChannel('flutter_media_session');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('activate', () async {
    await platform.activate();
  });

  test('updateAvailableActions maps shuffle/repeat', () async {
    final List<MethodCall> calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls.add(methodCall);
      return null;
    });

    final shuffle = MediaAction.custom(
        name: 'shuffle',
        customLabel: 'Shuffle',
        customIconResource: 'ic_shuffle');
    final repeat = MediaAction.custom(
        name: 'repeat', customLabel: 'Repeat', customIconResource: 'ic_repeat');

    await platform.updateAvailableActions({shuffle, repeat});

    expect(calls.length, 1);
    expect(calls.first.method, 'updateAvailableActions');
    final List args = calls.first.arguments;
    expect(args.any((a) => a['name'] == 'shuffle'), isTrue);
    expect(args.any((a) => a['name'] == 'repeat'), isTrue);
  });

  test('setActionLayout invokes setActionLayout on Android', () async {
    final List<MethodCall> calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls.add(methodCall);
      return null;
    });

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final shuffle = MediaAction.custom(
          name: 'shuffle',
          customLabel: 'Shuffle',
          customIconResource: 'ic_shuffle');
      final layout = ActionSlotLayout.symmetrical(
        left: shuffle,
        skipPrevious: MediaAction.skipToPrevious,
        playPause: MediaAction.play,
        skipNext: MediaAction.skipToNext,
      );

      await platform.setActionLayout(layout);

      expect(calls.length, 1);
      expect(calls.first.method, 'setActionLayout');
      final Map<dynamic, dynamic> args = calls.first.arguments;
      expect(args['compactIndices'], [1, 2, 3]);
      final List slots = args['slots'];
      expect(slots.length, 4);
      expect(slots[0]['name'], 'shuffle');
      expect(slots[1]['name'], 'skipToPrevious');
      expect(slots[2]['name'], 'play');
      expect(slots[3]['name'], 'skipToNext');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('setActionLayout is a no-op on non-Android platforms', () async {
    final List<MethodCall> calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls.add(methodCall);
      return null;
    });

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final layout = ActionSlotLayout.symmetrical(
        skipPrevious: MediaAction.skipToPrevious,
        playPause: MediaAction.play,
        skipNext: MediaAction.skipToNext,
      );

      await platform.setActionLayout(layout);

      expect(calls, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('onMediaAction', () {
    const eventChannel = EventChannel('flutter_media_session_events');

    test('parses seekTo action with args', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(eventChannel.name, eventChannel.codec),
        (MethodCall methodCall) async {
          if (methodCall.method == 'listen') {
            await TestDefaultBinaryMessengerBinding
                .instance.defaultBinaryMessenger
                .handlePlatformMessage(
              eventChannel.name,
              eventChannel.codec.encodeSuccessEnvelope({
                'action': 'seekTo',
                'args': 5000,
              }),
              (data) {},
            );
          }
          return null;
        },
      );

      final action = await platform.onMediaAction.first;
      expect(action.name, 'seekTo');
      expect(action.seekPosition, const Duration(milliseconds: 5000));
    });

    test('parses seekTo action with positionMs fallback (Linux MPRIS)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(eventChannel.name, eventChannel.codec),
        (MethodCall methodCall) async {
          if (methodCall.method == 'listen') {
            await TestDefaultBinaryMessengerBinding
                .instance.defaultBinaryMessenger
                .handlePlatformMessage(
              eventChannel.name,
              eventChannel.codec.encodeSuccessEnvelope({
                'action': 'seekTo',
                'positionMs': 60000,
              }),
              (data) {},
            );
          }
          return null;
        },
      );

      final action = await platform.onMediaAction.first;
      expect(action.name, 'seekTo');
      expect(action.seekPosition, const Duration(milliseconds: 60000));
    });

    test('parses plain string action', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(eventChannel.name, eventChannel.codec),
        (MethodCall methodCall) async {
          if (methodCall.method == 'listen') {
            await TestDefaultBinaryMessengerBinding
                .instance.defaultBinaryMessenger
                .handlePlatformMessage(
              eventChannel.name,
              eventChannel.codec.encodeSuccessEnvelope('play'),
              (data) {},
            );
          }
          return null;
        },
      );

      final action = await platform.onMediaAction.first;
      expect(action.name, 'play');
      expect(action.seekPosition, isNull);
    });
  });
}
