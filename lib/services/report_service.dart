import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../models/app_settings_model.dart';
import 'report_center_service.dart';

class ReportService {
  /// Generates a comprehensive Monthly Report PDF with Sales, Expenses, and Profit
  static Future<pw.Document> generateMonthlyReportPdf({
    required AppSettingsModel settings,
    required int year,
    required int month,
    required List<SaleModel> sales,
    required List<ExpenseModel> expenses,
  }) async {
    final pdf = pw.Document();

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final monthName = monthNames[month - 1];

    final clearedSales = sales.where((s) => s.isCleared).toList();

    // Calculate financial summaries (Cleared Sales)
    final double totalRevenue = clearedSales.fold(0.0, (sum, s) => sum + s.grandTotal);
    final double totalCostOfGoods = clearedSales.fold(0.0, (sum, s) => sum + s.totalCost);
    final int totalOrders = clearedSales.length;
    final double avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    final double totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final double grossProfit = totalRevenue - totalCostOfGoods;
    final double netProfit = grossProfit - totalExpenses;

    // Category-wise expense breakdown
    final Map<String, double> expenseByCategory = {};
    for (var e in expenses) {
      expenseByCategory[e.category] = (expenseByCategory[e.category] ?? 0.0) + e.amount;
    }

    // Top selling items from cleared sales
    final Map<String, int> productQtyMap = {};
    final Map<String, double> productRevenueMap = {};
    for (var sale in clearedSales) {
      for (var item in sale.items) {
        productQtyMap[item.productName] = (productQtyMap[item.productName] ?? 0) + item.quantity;
        productRevenueMap[item.productName] = (productRevenueMap[item.productName] ?? 0.0) + item.totalPrice;
      }
    }
    final topItems = productQtyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Payment method breakdown from cleared sales
    final Map<String, double> paymentBreakdown = {};
    for (var sale in clearedSales) {
      paymentBreakdown[sale.paymentMethod] = (paymentBreakdown[sale.paymentMethod] ?? 0.0) + sale.grandTotal;
    }

    final currency = settings.currencySymbol;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        settings.cafeName,
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                      ),
                      if (settings.address.isNotEmpty)
                        pw.Text(settings.address, style: const pw.TextStyle(fontSize: 10)),
                      if (settings.phone.isNotEmpty)
                        pw.Text('Ph: ${settings.phone}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'MONTHLY REPORT',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '$monthName $year',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1.5),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated: ${DateTime.now().toString().substring(0, 16)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // ─── FINANCIAL SUMMARY ───
            pw.Text('FINANCIAL SUMMARY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
              },
              children: [
                _buildTableRow('Total Revenue (Sales)', '$currency ${totalRevenue.toStringAsFixed(2)}', bold: true),
                _buildTableRow('Total Orders', '$totalOrders'),
                _buildTableRow('Average Order Value', '$currency ${avgOrderValue.toStringAsFixed(2)}'),
                _buildTableRow('Cost of Goods Sold', '$currency ${totalCostOfGoods.toStringAsFixed(2)}'),
                _buildTableRow('Gross Profit', '$currency ${grossProfit.toStringAsFixed(2)}', bold: true),
                _buildTableRow('Total Operational Expenses', '$currency ${totalExpenses.toStringAsFixed(2)}'),
                _buildTableRow('NET PROFIT', '$currency ${netProfit.toStringAsFixed(2)}', bold: true, highlight: true),
              ],
            ),

            pw.SizedBox(height: 20),

            // ─── PAYMENT METHOD BREAKDOWN ───
            if (paymentBreakdown.isNotEmpty) ...[
              pw.Text('PAYMENT METHOD BREAKDOWN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Payment Method', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                  ...paymentBreakdown.entries.map((e) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$currency ${e.value.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // ─── TOP SELLING ITEMS ───
            if (topItems.isNotEmpty) ...[
              pw.Text('TOP SELLING ITEMS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Product', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty Sold', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                  ...topItems.take(15).toList().asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final revenue = productRevenueMap[item.key] ?? 0.0;
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(item.key, style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${item.value}', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$currency ${revenue.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 10))),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // ─── EXPENSE BREAKDOWN ───
            if (expenseByCategory.isNotEmpty) ...[
              pw.Text('EXPENSE BREAKDOWN BY CATEGORY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                  ...expenseByCategory.entries.map((e) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$currency ${e.value.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))),
                    ],
                  )),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TOTAL EXPENSES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$currency ${totalExpenses.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // ─── DAILY SALES BREAKDOWN ───
            if (sales.isNotEmpty) ...[
              pw.Text('ALL SALES TRANSACTIONS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Invoice #', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Subtotal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Discount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Profit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    ],
                  ),
                  ...sales.map((s) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(s.invoiceNumber, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(s.dateTime.split('T').first, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('$currency ${s.subtotal.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('$currency ${s.discount.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('$currency ${s.grandTotal.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('$currency ${s.profit.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8))),
                    ],
                  )),
                ],
              ),
            ],
          ];
        },
      ),
    );

    return pdf;
  }

  /// Print/preview the monthly report
  static Future<void> printMonthlyReport({
    required AppSettingsModel settings,
    required int year,
    required int month,
    required List<SaleModel> sales,
    required List<ExpenseModel> expenses,
  }) async {
    final pdf = await generateMonthlyReportPdf(
      settings: settings,
      year: year,
      month: month,
      sales: sales,
      expenses: expenses,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Monthly_Report_${month}_$year',
    );
  }

  /// Generates a Category Performance & Stock Usage PDF Report
  static Future<pw.Document> generateCategoryReportPdf({
    required AppSettingsModel settings,
    required String categoryName,
    required String filterLabel,
    required int totalSold,
    required double totalRevenue,
    required List<ItemSalesRecord> products,
    required List<StockUsageRecord> ingredientsUsed,
  }) async {
    final pdf = pw.Document();
    final currency = settings.currencySymbol;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        settings.cafeName,
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                      ),
                      if (settings.address.isNotEmpty)
                        pw.Text(settings.address, style: const pw.TextStyle(fontSize: 10)),
                      if (settings.phone.isNotEmpty)
                        pw.Text('Ph: ${settings.phone}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blueGrey800,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'CATEGORY REPORT',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        categoryName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                      pw.Text(
                        'Filter: $filterLabel',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated via CafeFlow on ${DateTime.now().toString().substring(0, 16)}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // KPI Summary Highlights
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL REVENUE', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '$currency ${totalRevenue.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL SOLD (UNITS)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '$totalSold Items',
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('UNIQUE PRODUCTS', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${products.length} Products',
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Products Sold Table
            pw.Text(
              'PRODUCT SALES BREAKDOWN',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 6),
            if (products.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                alignment: pw.Alignment.center,
                child: pw.Text('No product sales recorded in this period for $categoryName.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(1.8),
                  3: const pw.FlexColumnWidth(1.8),
                  4: const pw.FlexColumnWidth(2.2),
                  5: const pw.FlexColumnWidth(1.4),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Product Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty Sold', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Share %', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  ...products.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final p = entry.value;
                    final share = totalRevenue > 0 ? (p.totalRevenue / totalRevenue) * 100 : 0.0;
                    return pw.TableRow(
                      decoration: idx % 2 == 0 ? const pw.BoxDecoration(color: PdfColors.grey50) : null,
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(p.productName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$currency ${p.avgPrice.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${p.totalSold}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$currency ${p.totalRevenue.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${share.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                      ],
                    );
                  }),
                  // Summary total row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$totalSold', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$currency ${totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('100.0%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                ],
              ),
            pw.SizedBox(height: 20),

            // Raw Material / Ingredients Used Table
            pw.Text(
              'INGREDIENTS & STOCK CONSUMED (FOR THIS CATEGORY)',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 6),
            if (ingredientsUsed.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                alignment: pw.Alignment.center,
                child: pw.Text('No specific recipe ingredients linked or deducted for this category.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(5),
                  2: const pw.FlexColumnWidth(2.5),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Ingredient / Stock Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Quantity Consumed', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Unit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    ],
                  ),
                  ...ingredientsUsed.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final ing = entry.value;
                    return pw.TableRow(
                      decoration: idx % 2 == 0 ? const pw.BoxDecoration(color: PdfColors.grey50) : null,
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(ing.stockName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            ing.totalQuantity % 1 == 0
                                ? ing.totalQuantity.toInt().toString()
                                : ing.totalQuantity.toStringAsFixed(2),
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(ing.unit, style: const pw.TextStyle(fontSize: 9))),
                      ],
                    );
                  }),
                ],
              ),
          ];
        },
      ),
    );

    return pdf;
  }

  /// Print or Preview Category Report PDF
  static Future<void> printCategoryReport({
    required AppSettingsModel settings,
    required String categoryName,
    required String filterLabel,
    required int totalSold,
    required double totalRevenue,
    required List<ItemSalesRecord> products,
    required List<StockUsageRecord> ingredientsUsed,
  }) async {
    final pdf = await generateCategoryReportPdf(
      settings: settings,
      categoryName: categoryName,
      filterLabel: filterLabel,
      totalSold: totalSold,
      totalRevenue: totalRevenue,
      products: products,
      ingredientsUsed: ingredientsUsed,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Category_Report_${categoryName.replaceAll(RegExp(r'\s+'), '_')}',
    );
  }

  /// Helper to build key-value table rows
  static pw.TableRow _buildTableRow(String label, String value, {bool bold = false, bool highlight = false}) {
    return pw.TableRow(
      decoration: highlight ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ],
    );
  }
}
