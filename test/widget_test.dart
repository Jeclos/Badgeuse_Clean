import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:badgeuse_auto/main.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for sqflite in tests
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Badgeuse app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BadgeuseApp());

    // Verify that the title is present.
    expect(find.text('Badgeuse Auto (Android & iOS)'), findsOneWidget);
  });
}
