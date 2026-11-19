import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/theme/app_theme.dart';
import '../models/sale_session_model.dart';
import '../providers/sale_session_provider.dart';
import '../providers/settings_provider.dart';
import '../repositories/sale_session_repository.dart';
import '../services/invoice_service.dart';

class SaleSessionDialogs {
  /// Shows the dialog to Start a new daily sale session (Shift)
  static Future<bool?> showStartSaleDialog(BuildContext context) async {
    final cashController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:${now.minute.toString().padLeft(2, '0')} $amPm';
    final dateStr = '${now.day}-${now.month}-${now.year}';

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start Sale (Open Shift)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Open register for today\'s cafe sales', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            width: 460,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shift Opening Time Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Starting Time & Date:', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                              Text('$timeStr ($dateStr)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Important Note explaining cross-midnight functionality
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All sales created until you click "End Sale" will be saved under today\'s starting date. For this new shift, invoice numbers start fresh from #1.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Opening Counter Cash for Change
                  Text(
                    'CASH ADDED ON COUNTER FOR CHANGE (OPENING FLOAT):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: cashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.payments_rounded, color: AppColors.accent),
                      hintText: 'e.g. 5000',
                      helperText: 'This amount is added to your cash sales so money counting is never confusing.',
                      helperMaxLines: 2,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter opening counter cash.';
                      final parsed = double.tryParse(val.trim());
                      if (parsed == null || parsed < 0) return 'Please enter a valid positive amount.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Shift Notes (Optional)
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Shift Notes (Optional)',
                      hintText: 'e.g. Evening shift, opened by Cashier',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: const Text('Start Today\'s Sale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final openingCash = double.tryParse(cashController.text.trim()) ?? 0.0;
                final notes = notesController.text.trim().isNotEmpty ? notesController.text.trim() : null;

                final sessionProvider = Provider.of<SaleSessionProvider>(context, listen: false);
                await sessionProvider.startSaleSession(openingCash, notes: notes);

                if (context.mounted) {
                  Navigator.pop(ctx, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sale session started! Opening cash float: Rs. ${openingCash.toStringAsFixed(0)}'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Shows the dialog to End the active daily sale session (Shift Reconciliation & Z-Report)
  static Future<bool?> showEndSaleDialog(BuildContext context) async {
    final sessionProvider = Provider.of<SaleSessionProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;

    // Refresh live figures before showing end dialog
    await sessionProvider.refreshActiveSessionFinancials();
    if (!context.mounted) return false;
    final activeSession = sessionProvider.activeSession;

    if (activeSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active sale session to end.')),
      );
      return false;
    }

    final countedCashController = TextEditingController();
    final notesController = TextEditingController();

    // Fetch shift selling items breakdown
    final soldItems = await sessionProvider.getSessionSoldItems(activeSession.id!);
    if (!context.mounted) return false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final now = DateTime.now();
        final currency = settings.currencySymbol;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.stop_circle_rounded, color: AppColors.error, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End Sale (Close Shift)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Review totals and close today\'s register', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shift Duration Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shift: ${activeSession.sessionName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          'Started: ${activeSession.startTime.replaceFirst('T', ' ').substring(0, 16)}  ->  Closing: ${now.toString().substring(0, 16)}',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Financial Breakdown Grid
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          'Total Sales Revenue:',
                          '$currency ${activeSession.totalSales.toStringAsFixed(2)}',
                          isBold: true,
                          color: AppColors.primary,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('• Cash: $currency ${activeSession.cashSales.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text('• Card: $currency ${activeSession.cardSales.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text('• Online: $currency ${activeSession.onlineSales.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Divider(),

                        _buildSummaryRow(
                          'Opening Cash Added on Counter (Change):',
                          '+ $currency ${activeSession.openingCash.toStringAsFixed(2)}',
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 6),

                        // TOTAL COUNTER CASH - Highlighted to prevent confusion!
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: _buildSummaryRow(
                            'TOTAL COUNTER CASH TO COUNT:\n(Opening Cash + Cash Sales)',
                            '$currency ${activeSession.totalCounterCash.toStringAsFixed(2)}',
                            isBold: true,
                            color: AppColors.accent,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _buildSummaryRow(
                          'Total Shift Expenses Paid Out:',
                          '- $currency ${activeSession.totalExpenses.toStringAsFixed(2)}',
                          color: AppColors.error,
                        ),
                        const Divider(),

                        _buildSummaryRow(
                          'Expected Cash in Drawer:\n(Counter Cash - Expenses)',
                          '$currency ${activeSession.expectedDrawerCash.toStringAsFixed(2)}',
                          isBold: true,
                          fontSize: 13,
                        ),
                        const SizedBox(height: 4),

                        _buildSummaryRow(
                          'Net Shift Profit (Sales - Expenses):',
                          '$currency ${activeSession.netProfit.toStringAsFixed(2)}',
                          isBold: true,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Shift Selling Items Breakdown Accordion
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      title: Row(
                        children: [
                          Icon(Icons.local_cafe_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selling Items of this Shift (${soldItems.length} items)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Total: ${soldItems.fold<int>(0, (s, i) => s + i.quantity)} cups/items sold',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      children: [
                        if (soldItems.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No items sold in this shift yet.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          )
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: soldItems.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final item = soldItems[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Text(
                                          item.productName,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${item.quantity}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '$currency ${item.unitPrice.toStringAsFixed(0)}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '$currency ${item.totalRevenue.toStringAsFixed(0)}',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Actual Physical Cash Counted
                  TextField(
                    controller: countedCashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Actual Physical Cash Counted (Optional)',
                      hintText: 'Enter physical cash in drawer',
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Closing Notes
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Closing Remarks (Optional)',
                      hintText: 'Any discrepancy or cash notes',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Print Shift Summary'),
              onPressed: () async {
                await printShiftZReport(
                  session: activeSession,
                  currency: currency,
                  cafeName: settings.cafeName,
                );
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: const Text('Confirm & End Sale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final counted = double.tryParse(countedCashController.text.trim());
                final notes = notesController.text.trim().isNotEmpty ? notesController.text.trim() : null;

                final closed = await sessionProvider.endSaleSession(
                  closingCash: counted,
                  notes: notes,
                );

                if (context.mounted) {
                  Navigator.pop(ctx, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sale session closed! Total Sales: $currency ${closed.totalSales.toStringAsFixed(0)}'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  static Widget _buildSummaryRow(
    String title,
    String value, {
    bool isBold = false,
    Color? color,
    double fontSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Prints a thermal 80mm Shift Summary (Z-Report)
  static Future<void> printShiftZReport({
    required SaleSessionModel session,
    required String currency,
    required String cafeName,
  }) async {
    final pdf = pw.Document();
    final cleanCurrency = InvoiceService.sanitizeForThermal(currency.isNotEmpty ? currency : 'Rs');
    final cleanCafe = InvoiceService.sanitizeForThermal(cafeName.isNotEmpty ? cafeName : 'Cafe Flow');
    final cleanSessionName = InvoiceService.sanitizeForThermal(session.sessionName);

    // Fetch shift selling items for printout
    final soldItems = session.id != null
        ? await SaleSessionRepository().getSessionSoldItems(session.id!)
        : <SessionSoldItem>[];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      cleanCafe,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'DAILY SHIFT SUMMARY (Z-REPORT)',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Divider(thickness: 1),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              pw.Text('Shift: $cleanSessionName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text('Start: ${session.startTime.replaceFirst('T', ' ').substring(0, 16)}', style: const pw.TextStyle(fontSize: 8)),
              if (session.endTime != null)
                pw.Text('End:   ${session.endTime!.replaceFirst('T', ' ').substring(0, 16)}', style: const pw.TextStyle(fontSize: 8)),
              pw.Divider(thickness: 0.5),

              _buildPdfRow('Opening Counter Cash:', '$cleanCurrency ${session.openingCash.toStringAsFixed(0)}'),
              _buildPdfRow('Total Sales Revenue:', '$cleanCurrency ${session.totalSales.toStringAsFixed(2)}', bold: true),
              _buildPdfRow('  - Cash Sales:', '$cleanCurrency ${session.cashSales.toStringAsFixed(0)}'),
              _buildPdfRow('  - Card Sales:', '$cleanCurrency ${session.cardSales.toStringAsFixed(0)}'),
              _buildPdfRow('  - Online Sales:', '$cleanCurrency ${session.onlineSales.toStringAsFixed(0)}'),
              pw.Divider(thickness: 0.5),

              _buildPdfRow('TOTAL COUNTER MONEY:', '$cleanCurrency ${session.totalCounterCash.toStringAsFixed(2)}', bold: true),
              _buildPdfRow('(Opening Cash + Cash Sales)', '', fontSize: 7),
              pw.Divider(thickness: 0.5),

              _buildPdfRow('Total Expenses Paid:', '- $cleanCurrency ${session.totalExpenses.toStringAsFixed(2)}'),
              _buildPdfRow('Expected Drawer Cash:', '$cleanCurrency ${session.expectedDrawerCash.toStringAsFixed(2)}', bold: true),
              if (session.closingCash != null)
                _buildPdfRow('Actual Counted Cash:', '$cleanCurrency ${session.closingCash!.toStringAsFixed(2)}', bold: true),
              pw.Divider(thickness: 1),

              _buildPdfRow('NET PROFIT:', '$cleanCurrency ${session.netProfit.toStringAsFixed(2)}', bold: true),
              pw.SizedBox(height: 6),

              // Shift Selling Items Breakdown Section in Thermal Printout
              if (session.id != null) ...[
                pw.Divider(thickness: 1),
                pw.Center(
                  child: pw.Text('ITEMS SOLD IN THIS SHIFT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Item', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                pw.Divider(thickness: 0.5),
                ...soldItems.map((item) {
                  final cleanName = InvoiceService.sanitizeForThermal(item.productName);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1),
                    child: pw.Row(
                      children: [
                        pw.Expanded(flex: 4, child: pw.Text(cleanName, style: const pw.TextStyle(fontSize: 7))),
                        pw.Expanded(flex: 2, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
                        pw.Expanded(flex: 2, child: pw.Text(item.unitPrice.toStringAsFixed(0), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
                        pw.Expanded(flex: 2, child: pw.Text(item.totalRevenue.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                  );
                }),
                pw.Divider(thickness: 0.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Items Sold:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${soldItems.fold<int>(0, (sum, i) => sum + i.quantity)}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('*** END OF SHIFT REPORT ***', style: const pw.TextStyle(fontSize: 8)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Shift_Summary_${session.id ?? 1}',
    );
  }

  static pw.Widget _buildPdfRow(String label, String value, {bool bold = false, double fontSize = 8}) {
    final cleanLabel = InvoiceService.sanitizeForThermal(label);
    final cleanValue = InvoiceService.sanitizeForThermal(value);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(cleanLabel, style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(cleanValue, style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}