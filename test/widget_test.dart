import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_flow/main.dart';

void main() {
  testWidgets('App loads cleanly test', (WidgetTester tester) async {
    await tester.pumpWidget(const CafeFlowApp());
    expect(find.byType(CafeFlowApp), findsOneWidget);
  });
}
