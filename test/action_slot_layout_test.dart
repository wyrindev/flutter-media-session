import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_media_session/flutter_media_session.dart';

class MockPlatform extends FlutterMediaSessionPlatform {
  ActionSlotLayout? lastLayout;

  @override
  Future<void> setActionLayout(ActionSlotLayout layout) async {
    lastLayout = layout;
  }
}

void main() {
  group('ActionSlotLayout Tests', () {
    final custom1 = MediaAction.custom(
      name: 'like',
      customLabel: 'Like',
      customIconResource: 'ic_like',
    );
    final custom2 = MediaAction.custom(
      name: 'dislike',
      customLabel: 'Dislike',
      customIconResource: 'ic_dislike',
    );

    test('symmetrical preset produces balanced slot ordering and compact indices', () {
      final layout = ActionSlotLayout.symmetrical(
        left: custom1,
        right: custom2,
      );

      expect(layout.slots, [
        custom1,
        MediaAction.skipToPrevious,
        MediaAction.play,
        MediaAction.skipToNext,
        custom2,
      ]);
      expect(layout.compactActionIndices, [1, 2, 3]);
      expect(layout.allActions, containsAll([
        custom1,
        MediaAction.skipToPrevious,
        MediaAction.play,
        MediaAction.skipToNext,
        custom2,
      ]));
    });

    test('symmetrical preset with omitted custom actions', () {
      final layout = ActionSlotLayout.symmetrical(
        left: custom1,
      );

      expect(layout.slots, [
        custom1,
        MediaAction.skipToPrevious,
        MediaAction.play,
        MediaAction.skipToNext,
      ]);
      expect(layout.compactActionIndices, [1, 2, 3]);
    });

    test('sequential preset produces sequential slot ordering and compact indices', () {
      final layout = ActionSlotLayout.sequential(
        custom1: custom1,
        custom2: custom2,
      );

      expect(layout.slots, [
        MediaAction.skipToPrevious,
        MediaAction.play,
        MediaAction.skipToNext,
        custom1,
        custom2,
      ]);
      expect(layout.compactActionIndices, [0, 1, 2]);
    });

    test('fromMap and toMap correctly convert slot lists', () {
      final map = {
        0: custom1,
        1: MediaAction.skipToPrevious,
        2: MediaAction.play,
        3: MediaAction.skipToNext,
        4: custom2,
      };

      final layout = ActionSlotLayout.fromMap(map, compactActionIndices: [1, 2, 3]);
      expect(layout.slots.length, 5);
      expect(layout.slots[0], custom1);
      expect(layout.slots[4], custom2);
      expect(layout.toMap(), map);
    });

    test('toJson serializes correctly for platform transmission', () {
      final layout = ActionSlotLayout.symmetrical(
        left: custom1,
        right: custom2,
      );
      final json = layout.toJson();

      expect(json['compactIndices'], [1, 2, 3]);
      final slotsJson = json['slots'] as List;
      expect(slotsJson.length, 5);
      expect(slotsJson[0]['name'], 'like');
      expect(slotsJson[0]['customLabel'], 'Like');
      expect(slotsJson[1]['name'], 'skipToPrevious');
      expect(slotsJson[2]['name'], 'play');
      expect(slotsJson[3]['name'], 'skipToNext');
      expect(slotsJson[4]['name'], 'dislike');
    });

    test('FlutterMediaSession.setActionLayout calls platform instance', () async {
      final mock = MockPlatform();
      FlutterMediaSessionPlatform.instance = mock;

      final session = FlutterMediaSession();
      final layout = ActionSlotLayout.symmetrical(left: custom1);
      await session.setActionLayout(layout);

      expect(mock.lastLayout, layout);
    });
  });
}
