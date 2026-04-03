import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_media_session/flutter_media_session.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('activate test', (WidgetTester tester) async {
    final FlutterMediaSession plugin = FlutterMediaSession();
    // Verify that activate completes without error
    await plugin.activate();
    await plugin.deactivate();
  });
}
