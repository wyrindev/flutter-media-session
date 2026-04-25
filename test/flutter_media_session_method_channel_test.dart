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
        name: 'repeat',
        customLabel: 'Repeat',
        customIconResource: 'ic_repeat');

    await platform.updateAvailableActions({shuffle, repeat});

    expect(calls.length, 1);
    expect(calls.first.method, 'updateAvailableActions');
    final List args = calls.first.arguments;
    expect(args.any((a) => a['name'] == 'shuffle'), isTrue);
    expect(args.any((a) => a['name'] == 'repeat'), isTrue);
  });
}
