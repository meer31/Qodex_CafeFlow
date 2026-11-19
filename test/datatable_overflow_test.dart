import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test DataTable with Expanded + FittedBox prevents subpixel overflow', (tester) async {
    // Set a surface size
    await tester.binding.setSurfaceSize(const Size(800, 600));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowHeight: 48,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 46,
              columns: const [
                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))))),
                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))))),
                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Table', style: TextStyle(fontWeight: FontWeight.bold))))),
                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))))),
                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold))))),
                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Payment', style: TextStyle(fontWeight: FontWeight.bold))))),
                DataColumn(label: Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))))),
              ],
              rows: const [
                DataRow(cells: [
                  DataCell(Text('#1001')),
                  DataCell(Text('14:30')),
                  DataCell(Text('Table 4')),
                  DataCell(Text('CLEARED')),
                  DataCell(Text('Rs. 1,500')),
                  DataCell(Text('Cash')),
                  DataCell(Text('Actions')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Invoice #'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Table'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Grand Total'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Actions'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
