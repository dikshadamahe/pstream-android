import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pstream_android/main.dart';

void main() {
  testWidgets('app bootstrap smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VeilApp()));
    expect(find.byType(VeilApp), findsOneWidget);
  });
}
