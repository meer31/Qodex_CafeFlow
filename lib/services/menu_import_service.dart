import 'dart:io';
import 'package:excel/excel.dart';

/// Represents a single row parsed from an imported menu file.
class ImportedMenuRow {
  final String categoryName;
  final String productName;
  final double sellingPrice;
  final double costPrice;

  ImportedMenuRow({
    required this.categoryName,
    required this.productName,
    required this.sellingPrice,
    required this.costPrice,
  });
}

/// Result returned after parsing a menu file.
class MenuImportResult {
  final List<ImportedMenuRow> rows;
  final List<String> errors;

  MenuImportResult({required this.rows, required this.errors});

  bool get hasData => rows.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

class MenuImportService {
  /// Parses an Excel (.xls / .xlsx) file.
  /// Expected columns (case-insensitive, any order):
  ///   Category | Product Name | Price (Selling Price) | Cost Price (optional)
  static MenuImportResult parseExcelFile(String filePath) {
    final List<ImportedMenuRow> rows = [];
    final List<String> errors = [];

    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Use the first non-empty sheet
      Sheet? sheet;
      for (final sheetName in excel.tables.keys) {
        final s = excel.tables[sheetName]!;
        if (s.maxRows > 0) {
          sheet = s;
          break;
        }
      }

      if (sheet == null) {
        errors.add('No data found in the Excel file.');
        return MenuImportResult(rows: rows, errors: errors);
      }

      final sheetRows = sheet.rows;
      if (sheetRows.isEmpty) {
        errors.add('The sheet is empty.');
        return MenuImportResult(rows: rows, errors: errors);
      }

      // Detect header row (first row)
      final headerRow = sheetRows[0];
      final headers = headerRow
          .map((cell) => (cell?.value?.toString() ?? '').toLowerCase().trim())
          .toList();

      // Find column indices
      int catIdx = _findColumn(headers, ['category', 'category name', 'cat']);
      int nameIdx = _findColumn(headers, ['product name', 'product', 'name', 'item', 'item name', 'menu item']);
      int priceIdx = _findColumn(headers, ['price', 'selling price', 'sell price', 'sale price', 'amount']);
      int costIdx = _findColumn(headers, ['cost price', 'cost', 'cost per unit', 'purchase price']);

      if (catIdx == -1) errors.add('Could not find a "Category" column. Using "General" for all rows.');
      if (nameIdx == -1) {
        errors.add('Could not find a "Product Name" column. Import aborted.');
        return MenuImportResult(rows: rows, errors: errors);
      }
      if (priceIdx == -1) {
        errors.add('Could not find a "Price" column. Import aborted.');
        return MenuImportResult(rows: rows, errors: errors);
      }

      // Parse data rows (skip header row 0)
      for (int i = 1; i < sheetRows.length; i++) {
        final row = sheetRows[i];

        final categoryName = catIdx != -1
            ? (row.length > catIdx ? (row[catIdx]?.value?.toString() ?? '').trim() : '')
            : '';
        final productName = row.length > nameIdx
            ? (row[nameIdx]?.value?.toString() ?? '').trim()
            : '';
        final priceRaw = row.length > priceIdx
            ? (row[priceIdx]?.value?.toString() ?? '').trim()
            : '';
        final costRaw = costIdx != -1 && row.length > costIdx
            ? (row[costIdx]?.value?.toString() ?? '').trim()
            : '';

        // Skip empty rows
        if (productName.isEmpty && priceRaw.isEmpty) continue;

        if (productName.isEmpty) {
          errors.add('Row ${i + 1}: Product name is empty — skipped.');
          continue;
        }

        final sellingPrice = double.tryParse(priceRaw.replaceAll(RegExp(r'[^\d.]'), ''));
        if (sellingPrice == null) {
          errors.add('Row ${i + 1} ("$productName"): Invalid price "$priceRaw" — skipped.');
          continue;
        }

        final costPrice = double.tryParse(costRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

        rows.add(ImportedMenuRow(
          categoryName: categoryName.isEmpty ? 'General' : categoryName,
          productName: productName,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
        ));
      }
    } catch (e) {
      errors.add('Failed to read file: $e');
    }

    return MenuImportResult(rows: rows, errors: errors);
  }

  /// Parses a CSV file.
  /// Expected columns (same as Excel, comma-separated).
  static MenuImportResult parseCsvFile(String filePath) {
    final List<ImportedMenuRow> rows = [];
    final List<String> errors = [];

    try {
      final lines = File(filePath).readAsLinesSync();
      if (lines.isEmpty) {
        errors.add('CSV file is empty.');
        return MenuImportResult(rows: rows, errors: errors);
      }

      final headers = _splitCsvLine(lines[0])
          .map((h) => h.toLowerCase().trim())
          .toList();

      int catIdx = _findColumn(headers, ['category', 'category name', 'cat']);
      int nameIdx = _findColumn(headers, ['product name', 'product', 'name', 'item', 'item name', 'menu item']);
      int priceIdx = _findColumn(headers, ['price', 'selling price', 'sell price', 'sale price', 'amount']);
      int costIdx = _findColumn(headers, ['cost price', 'cost', 'cost per unit', 'purchase price']);

      if (catIdx == -1) errors.add('Could not find a "Category" column. Using "General" for all rows.');
      if (nameIdx == -1) {
        errors.add('Could not find a "Product Name" column. Import aborted.');
        return MenuImportResult(rows: rows, errors: errors);
      }
      if (priceIdx == -1) {
        errors.add('Could not find a "Price" column. Import aborted.');
        return MenuImportResult(rows: rows, errors: errors);
      }

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final cols = _splitCsvLine(line);

        final categoryName = catIdx != -1 && cols.length > catIdx ? cols[catIdx].trim() : '';
        final productName = cols.length > nameIdx ? cols[nameIdx].trim() : '';
        final priceRaw = cols.length > priceIdx ? cols[priceIdx].trim() : '';
        final costRaw = costIdx != -1 && cols.length > costIdx ? cols[costIdx].trim() : '';

        if (productName.isEmpty && priceRaw.isEmpty) continue;
        if (productName.isEmpty) {
          errors.add('Row ${i + 1}: Product name is empty — skipped.');
          continue;
        }

        final sellingPrice = double.tryParse(priceRaw.replaceAll(RegExp(r'[^\d.]'), ''));
        if (sellingPrice == null) {
          errors.add('Row ${i + 1} ("$productName"): Invalid price "$priceRaw" — skipped.');
          continue;
        }

        final costPrice = double.tryParse(costRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

        rows.add(ImportedMenuRow(
          categoryName: categoryName.isEmpty ? 'General' : categoryName,
          productName: productName,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
        ));
      }
    } catch (e) {
      errors.add('Failed to read CSV: $e');
    }

    return MenuImportResult(rows: rows, errors: errors);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static int _findColumn(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final idx = headers.indexOf(candidate);
      if (idx != -1) return idx;
    }
    return -1;
  }

  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final buf = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(char);
      }
    }
    result.add(buf.toString());
    return result;
  }
}
