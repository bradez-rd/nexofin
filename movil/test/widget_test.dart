import 'package:flutter_test/flutter_test.dart';
import 'package:nexofin/main.dart';

void main() {
  testWidgets('NexoFinApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NexoFinApp());
    expect(find.byType(NexoFinApp), findsOneWidget);
  });
}
