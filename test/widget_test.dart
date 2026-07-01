import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:simpay/main.dart';
import 'package:simpay/providers/transaction_provider.dart';

void main() {
  testWidgets('App renders correctly and finds SimPay', (WidgetTester tester) async {
    // Initialize localization formatting for test context
    await initializeDateFormatting('id_ID', null);

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(),
        child: const MyApp(),
      ),
    );

    // Verify that our app renders and has brand title.
    expect(find.text('SimPay'), findsAtLeastNWidgets(1));
  });
}
