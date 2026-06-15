import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthy_home_foods/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HealthyHomeFoodsApp()));
    expect(find.byType(HealthyHomeFoodsApp), findsOneWidget);
  });
}
