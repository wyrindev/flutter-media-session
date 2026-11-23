import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:flutter_media_session/flutter_media_session_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_media_session');
  const eventChannel = EventChannel('flutter_media_session_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
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

  test('setPauseWhenDucked is sent on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await platform.setPauseWhenDucked(true);
    await platform.setPauseWhenDucked(false);
    expect(calls.map((c) => (c.method, c.arguments)), [
      ('setPauseWhenDucked', true),
      ('setPauseWhenDucked', false),
    ]);
  });

  test('setPauseWhenDucked does nothing elsewhere', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await platform.setPauseWhenDucked(true);
    expect(calls, isEmpty);
  });

  Future<MediaAction> receive(Object event) {
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

  test('a pause caused by an interruption says so, and is still a pause',
      () async {
    final action = await receive({
      'action': 'pause',
      'args': {'reason': 'interruption'}
    });
    expect(action, MediaAction.pause);
    expect(action.isInterruption, isTrue);
  });

  test('a resume after an interruption says so', () async {
    final action = await receive({
      'action': 'play',
      'args': {'reason': 'interruption'}
    });
    expect(action, MediaAction.play);
    expect(action.isInterruption, isTrue);
  });

  test('a pause from the user is not an interruption', () async {
    final action = await receive('pause');
    expect(action, MediaAction.pause);
    expect(action.isInterruption, isFalse);
  });
}
