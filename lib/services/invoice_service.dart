import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sale_model.dart';
import '../models/app_settings_model.dart';
import '../models/meat_purchase_model.dart';

class InvoiceService {
  /// Strips emojis and converts non-ASCII symbols (bullets, em-dashes) to safe ASCII for thermal paper printing
  static String sanitizeForThermal(String text) {
    if (text.isEmpty) return text;

    // 1. Replace common non-ASCII punctuation with standard safe ASCII
    var cleaned = text
        .replaceAll('—', '-') // em dash
        .replaceAll('–', '-') // en dash
        .replaceAll('•', '|') // bullet
        .replaceAll('·', '.') // middle dot
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('™', 'TM')
        .replaceAll('©', '(C)')
        .replaceAll('®', '(R)')
        .replaceAll('₨', 'Rs.')
        .replaceAll('₹', 'Rs.')
        .replaceAll('€', 'EUR')
        .replaceAll('£', 'GBP');

    // 2. Remove emojis and unicode symbols that thermal printers cannot render
    final emojiRegex = RegExp(
      r'[\u{1F000}-\u{1FAFF}' // All Symbols, Pictographs, Emoticons, Transport, Flags, Extended
      r'\u{2600}-\u{27BF}'   // Misc symbols (coffee, heart, etc.) & Dingbats
      r'\u{203C}-\u{2049}'   // Punctuation marks (‼️, ⁉️)
      r'\u{2122}-\u{2139}'   // TM, etc.
      r'\u{2194}-\u{21AA}'   // Symbol arrows
      r'\u{2300}-\u{23FF}'   // Misc Technical (watches, clocks, timers)
      r'\u{25AA}-\u{25FE}'   // Geometric shapes
      r'\u{2B00}-\u{2BFF}'   // Misc symbols and arrows (stars, circles)
      r'\u{3030}-\u{303D}'   // CJK symbols
      r'\u{3297}-\u{3299}'   // Circled ideographs
      r'\u{FE00}-\u{FE0F}'   // Variation Selectors
      r'\u{200D}'            // Zero Width Joiner
      r']+',
      unicode: true,
    );

    cleaned = cleaned.replaceAll(emojiRegex, '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    // Remove awkward space before punctuation left after emoji removal
    cleaned = cleaned.replaceAllMapped(RegExp(r'\s+([!?,.:;])'), (match) => match.group(1)!);
    return cleaned.trim();
  }

  /// Branding footer - printed on customer-facing & purchase invoices
  static pw.Widget _buildBrandingFooter() {
    return pw.Column(
      children: [
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'POWERED BY INNOVATION',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'QODEX SOFTWARE - CODE THE FUTURE',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '+92 311 0233091 | +92 309 3946832',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'www.qodex-software.com',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Generates a PDF Document for thermal/A4 printing of a CUSTOMER RECEIPT
  static Future<pw.Document> generatePdf({
    required SaleModel sale,
    required AppSettingsModel settings,
    bool isAdditionalOnly = false,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Thermal 80mm receipt format
        margin: const pw.EdgeInsets.only(left: 8, right: 24, top: 10, bottom: 10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cafe Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      settings.cafeName.trim().isNotEmpty
                          ? sanitizeForThermal(settings.cafeName)
                          : 'Cafe Indus',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (settings.address.trim().isNotEmpty)
                      pw.Text(
                        sanitizeForThermal(settings.address),
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    if (settings.phone.trim().isNotEmpty)
                      pw.Text(
                        'Ph: ${sanitizeForThermal(settings.phone)}',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      isAdditionalOnly ? 'RECEIPT / TAX INVOICE (ADD-ON)' : 'RECEIPT / TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (isAdditionalOnly) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'SUPPLEMENTARY BILL - ADDITIONAL ITEMS',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                    pw.Divider(thickness: 0.5),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // Invoice Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isAdditionalOnly ? 'Invoice #: #${sale.invoiceNumber} (Add-on)' : 'Invoice #: #${sale.invoiceNumber}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    sale.dateTime.contains('T')
                        ? sale.dateTime.split('T').first
                        : sale.dateTime,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              if (sale.tableName != null && sale.tableName!.isNotEmpty)
                pw.Text('Table: ${sanitizeForThermal(sale.tableName!)}', style: const pw.TextStyle(fontSize: 8)),
              if (sale.waiterName != null && sale.waiterName!.isNotEmpty)
                pw.Text('Waiter: ${sanitizeForThermal(sale.waiterName!)}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Cashier: ${sanitizeForThermal(sale.cashierName)}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Payment: ${sale.paymentMethod}', style: const pw.TextStyle(fontSize: 8)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill Status:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    sale.isRemaining ? 'REMAINING (UNPAID)' : 'CLEARED / PAID',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              // Item Table Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 4, child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: pw.Text('Price', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 2, child: pw.Text('Total', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items List
              ...sale.items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text(
                            sanitizeForThermal(item.productName),
                            style: const pw.TextStyle(fontSize: 8),
                            maxLines: 1,
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            isAdditionalOnly ? '+${item.quantity}' : '${item.quantity}',
                            style: pw.TextStyle(fontSize: 8, fontWeight: isAdditionalOnly ? pw.FontWeight.bold : pw.FontWeight.normal),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            item.unitPrice.toStringAsFixed(0),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            item.totalPrice.toStringAsFixed(0),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 4),
                        child: pw.Text(
                          'Note: ${sanitizeForThermal(item.notes!)}',
                          style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              )),

              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Calculation Totals
              _buildRow('Subtotal', '${settings.currencySymbol} ${sale.subtotal.toStringAsFixed(2)}'),
              if (sale.discount > 0)
                _buildRow('Discount', '- ${settings.currencySymbol} ${sale.discount.toStringAsFixed(2)}'),
              if (sale.tax > 0)
                _buildRow('Tax', '${settings.currencySymbol} ${sale.tax.toStringAsFixed(2)}'),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isAdditionalOnly ? 'ADD-ON TOTAL:' : 'GRAND TOTAL:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${settings.currencySymbol} ${sale.grandTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              if (sale.isRemaining) ...[
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '*** REMAINING BILL DUE: ${settings.currencySymbol} ${sale.grandTotal.toStringAsFixed(2)} ***',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              ],
              pw.SizedBox(height: 6),

              // Footer Note (emojis and non-ASCII stripped for thermal paper printing)
              if (settings.receiptFooter.trim().isNotEmpty) ...[
                if (sanitizeForThermal(settings.receiptFooter).isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      sanitizeForThermal(settings.receiptFooter),
                      style: const pw.TextStyle(fontSize: 7),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
              ],

              // Powered by branding
              _buildBrandingFooter(),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildRow(String title, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  /// Triggers direct print preview / printing dialog for CUSTOMER RECEIPT
  static Future<void> printInvoice({
    required SaleModel sale,
    required AppSettingsModel settings,
    bool isAdditionalOnly = false,
  }) async {
    final pdf = await generatePdf(sale: sale, settings: settings, isAdditionalOnly: isAdditionalOnly);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${sale.invoiceNumber}${isAdditionalOnly ? '_Addon' : ''}',
    );
  }

  // -------------------------------------------------
  // KITCHEN SLIP - items only, no prices, no branding
  // -------------------------------------------------

  /// Generates a simplified Kitchen Slip PDF (items + quantities + notes only, no prices)
  static Future<pw.Document> generateKitchenSlipPdf({
    required SaleModel sale,
    required AppSettingsModel settings,
    bool isAdditionalOnly = false,
    int? totalOrderItemsCount,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.only(left: 8, right: 24, top: 10, bottom: 10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Kitchen Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      isAdditionalOnly ? '*** KITCHEN ORDER (ADD-ON) ***' : '*** KITCHEN ORDER ***',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (isAdditionalOnly) ...[
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 1),
                        ),
                        child: pw.Text(
                          '** ADDITIONAL ITEMS ONLY - COOK THESE NOW **',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                    pw.Divider(thickness: 1),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // Order Context
              pw.Text('TOKEN / INVOICE #: #${sale.invoiceNumber}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                'Time: ${sale.dateTime.replaceFirst('T', ' ').substring(0, sale.dateTime.length >= 16 ? 16 : sale.dateTime.length)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              if (sale.tableName != null && sale.tableName!.isNotEmpty)
                pw.Text('Table: ${sanitizeForThermal(sale.tableName!)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              if (sale.waiterName != null && sale.waiterName!.isNotEmpty)
                pw.Text('Waiter: ${sanitizeForThermal(sale.waiterName!)}', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),

              // Item Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 5, child: pw.Text('Item', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      isAdditionalOnly ? 'New Qty' : 'Qty',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items - larger font for kitchen readability
              ...sale.items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Text(
                            sanitizeForThermal(item.productName),
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            isAdditionalOnly ? '+${item.quantity}' : 'x${item.quantity}',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 8, top: 2),
                        child: pw.Text(
                          '-> ${sanitizeForThermal(item.notes!)}',
                          style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              )),

              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      isAdditionalOnly
                          ? 'Additional Items to Cook: ${sale.items.fold(0, (sum, item) => sum + item.quantity)}'
                          : 'Total Items: ${sale.items.fold(0, (sum, item) => sum + item.quantity)}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    if (isAdditionalOnly && totalOrderItemsCount != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '(Total items in full table order: $totalOrderItemsCount)',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ],
                ),
              ),
              // No branding footer on kitchen slip
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Prints the kitchen slip
  static Future<void> printKitchenSlip({
    required SaleModel sale,
    required AppSettingsModel settings,
    bool isAdditionalOnly = false,
    int? totalOrderItemsCount,
  }) async {
    final pdf = await generateKitchenSlipPdf(
      sale: sale,
      settings: settings,
      isAdditionalOnly: isAdditionalOnly,
      totalOrderItemsCount: totalOrderItemsCount,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Kitchen_${sale.invoiceNumber}${isAdditionalOnly ? '_Addon' : ''}',
    );
  }

  // ---------------------------------------------------
  // MEAT PURCHASE INVOICE
  // ---------------------------------------------------

  /// Generates a Meat Purchase Invoice PDF
  static Future<pw.Document> generateMeatPurchasePdf({
    required MeatPurchaseModel purchase,
    required AppSettingsModel settings,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.only(left: 8, right: 24, top: 10, bottom: 10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      settings.cafeName.trim().isNotEmpty ? sanitizeForThermal(settings.cafeName) : 'Cafe Indus',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (settings.address.trim().isNotEmpty)
                      pw.Text(
                        sanitizeForThermal(settings.address),
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    if (settings.phone.trim().isNotEmpty)
                      pw.Text(
                        'Ph: ${sanitizeForThermal(settings.phone)}',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'MEAT PURCHASE INVOICE',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Divider(thickness: 0.5),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // Invoice Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice #: ${purchase.invoiceNumber}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    purchase.dateTime.replaceFirst('T', ' ').substring(0, purchase.dateTime.length >= 16 ? 16 : purchase.dateTime.length),
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              // Items Table Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Category', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty (KG)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: pw.Text('Rate/KG', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 2, child: pw.Text('Total', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Item Rows
              ...purchase.items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text(sanitizeForThermal(item.meatType), style: const pw.TextStyle(fontSize: 8.5))),
                    pw.Expanded(flex: 2, child: pw.Text(item.quantityKg.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8.5), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text('${settings.currencySymbol} ${item.ratePerKg.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text('${settings.currencySymbol} ${item.totalAmount.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                  ],
                ),
              )),

              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Grand Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${settings.currencySymbol} ${purchase.grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),

              // Branding Footer
              _buildBrandingFooter(),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Prints the meat purchase invoice
  static Future<void> printMeatPurchaseInvoice({
    required MeatPurchaseModel purchase,
    required AppSettingsModel settings,
  }) async {
    final pdf = await generateMeatPurchasePdf(purchase: purchase, settings: settings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'MeatInvoice_${purchase.invoiceNumber}',
    );
  }
}
