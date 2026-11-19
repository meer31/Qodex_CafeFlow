import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/cafe_table_model.dart';
import '../models/sale_model.dart';
import '../providers/pos_provider.dart';
import '../providers/table_provider.dart';

/// Modal dialog allowing cashiers to swap or transfer orders between two tables.
class SwapTableDialog extends StatefulWidget {
  final PosProvider posProvider;
  final TableProvider tableProvider;
  final CafeTableModel? initialSourceTable;

  const SwapTableDialog({
    super.key,
    required this.posProvider,
    required this.tableProvider,
    this.initialSourceTable,
  });

  static Future<void> show(
    BuildContext context, {
    required PosProvider posProvider,
    required TableProvider tableProvider,
    CafeTableModel? initialSourceTable,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SwapTableDialog(
        posProvider: posProvider,
        tableProvider: tableProvider,
        initialSourceTable: initialSourceTable,
      ),
    );
  }

  @override
  State<SwapTableDialog> createState() => _SwapTableDialogState();
}

class _SwapTableDialogState extends State<SwapTableDialog> {
  CafeTableModel? _sourceTable;
  CafeTableModel? _targetTable;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final tables = widget.tableProvider.tables;

    // Default source table: initialSourceTable -> or currently selected in POS -> or first occupied/pending table -> or first table
    if (widget.initialSourceTable != null) {
      _sourceTable = tables.firstWhere(
        (t) => t.id == widget.initialSourceTable!.id,
        orElse: () => widget.initialSourceTable!,
      );
    } else if (widget.posProvider.selectedTable != null) {
      _sourceTable = tables.firstWhere(
        (t) => t.id == widget.posProvider.selectedTable!.id,
        orElse: () => widget.posProvider.selectedTable!,
      );
    } else {
      final occupiedOrPending = tables.where((t) {
        final hasCart = widget.posProvider.tableCarts.containsKey(t.id) &&
            widget.posProvider.tableCarts[t.id]!.isNotEmpty;
        final isBusy = t.status.toUpperCase() == 'OCCUPIED' ||
            t.status.toUpperCase() == 'RESERVED';
        return hasCart || isBusy;
      });
      if (occupiedOrPending.isNotEmpty) {
        _sourceTable = occupiedOrPending.first;
      } else if (tables.isNotEmpty) {
        _sourceTable = tables.first;
      }
    }

    // Default target table: first available table different from source
    final availableTargets = tables.where((t) => t.id != _sourceTable?.id).toList();
    final firstAvailable = availableTargets.firstWhere(
      (t) => t.status.toUpperCase() == 'AVAILABLE',
      orElse: () => availableTargets.isNotEmpty ? availableTargets.first : tables.first,
    );
    if (availableTargets.isNotEmpty) {
      _targetTable = firstAvailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTables = widget.tableProvider.tables;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 620;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.cardBg,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Swap Table Orders',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Move an order to another table or swap between two tables',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),

                // Table Selector Row / Column
                if (isCompact) ...[
                  _buildTableSelectCard(
                    label: 'FROM TABLE (SOURCE)',
                    selectedTable: _sourceTable,
                    allTables: allTables,
                    onChanged: (newTable) {
                      setState(() {
                        _sourceTable = newTable;
                        if (_targetTable?.id == newTable?.id) {
                          _targetTable = allTables.firstWhere(
                            (t) => t.id != newTable?.id,
                            orElse: () => newTable!,
                          );
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        foregroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.swap_vert_rounded),
                      tooltip: 'Switch tables',
                      onPressed: _swapSelections,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTableSelectCard(
                    label: 'TO TABLE (DESTINATION)',
                    selectedTable: _targetTable,
                    allTables: allTables.where((t) => t.id != _sourceTable?.id).toList(),
                    onChanged: (newTable) => setState(() => _targetTable = newTable),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Source Table Box
                      Expanded(
                        child: _buildTableSelectCard(
                          label: 'FROM TABLE (SOURCE)',
                          selectedTable: _sourceTable,
                          allTables: allTables,
                          onChanged: (newTable) {
                            setState(() {
                              _sourceTable = newTable;
                              if (_targetTable?.id == newTable?.id) {
                                _targetTable = allTables.firstWhere(
                                  (t) => t.id != newTable?.id,
                                  orElse: () => newTable!,
                                );
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Interactive Swap Arrow in Middle
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Tooltip(
                          message: 'Invert From & To',
                          child: InkWell(
                            onTap: _swapSelections,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                              ),
                              child: Icon(
                                Icons.swap_horiz_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Target Table Box
                      Expanded(
                        child: _buildTableSelectCard(
                          label: 'TO TABLE (DESTINATION)',
                          selectedTable: _targetTable,
                          allTables: allTables.where((t) => t.id != _sourceTable?.id).toList(),
                          onChanged: (newTable) => setState(() => _targetTable = newTable),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),

                // Explanation Banner
                _buildSwapSummaryBanner(),
                const SizedBox(height: 22),

                // Bottom Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.swap_horiz_rounded, size: 20),
                      label: Text(
                        _isProcessing ? 'Swapping...' : 'Confirm Swap Orders',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: (_sourceTable == null || _targetTable == null || _sourceTable!.id == _targetTable!.id || _isProcessing)
                          ? null
                          : _performSwap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _swapSelections() {
    setState(() {
      final temp = _sourceTable;
      _sourceTable = _targetTable;
      _targetTable = temp;
    });
  }

  Widget _buildTableSelectCard({
    required String label,
    required CafeTableModel? selectedTable,
    required List<CafeTableModel> allTables,
    required ValueChanged<CafeTableModel?> onChanged,
  }) {
    final isCurSelected = widget.posProvider.selectedTable?.id == selectedTable?.id;
    final tableCart = isCurSelected
        ? widget.posProvider.cart
        : (selectedTable != null ? (widget.posProvider.tableCarts[selectedTable.id] ?? []) : <SaleItemModel>[]);
    final hasPendingCart = tableCart.isNotEmpty;
    final cartItemCount = tableCart.fold<int>(0, (sum, i) => sum + i.quantity);

    final statusUpper = selectedTable?.status.toUpperCase() ?? '';
    final isReserved = statusUpper == 'RESERVED';
    final isOccupied = statusUpper == 'OCCUPIED' || hasPendingCart;
    final isAvailable = statusUpper == 'AVAILABLE' && !hasPendingCart;

    Color statusColor;
    Color statusBgColor;
    if (isReserved) {
      statusColor = const Color(0xFFEF4444);
      statusBgColor = const Color(0xFFFEF2F2);
    } else if (hasPendingCart) {
      statusColor = const Color(0xFFF43F5E); // Soft Rose-Red for draft occupied
      statusBgColor = const Color(0xFFFFF1F2);
    } else if (isOccupied) {
      statusColor = const Color(0xFFDC2626);
      statusBgColor = const Color(0xFFFFF1F2);
    } else if (isAvailable) {
      statusColor = const Color(0xFF10B981);
      statusBgColor = const Color(0xFFF0FDF4);
    } else {
      statusColor = const Color(0xFF3B82F6);
      statusBgColor = const Color(0xFFEFF6FF);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          // Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedTable?.id,
                isExpanded: true,
                hint: const Text('Select Table', style: TextStyle(fontSize: 13)),
                items: allTables.map((t) {
                  return DropdownMenuItem<int>(
                    value: t.id,
                    child: Text(
                      '${t.tableName} (${t.sectionName})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final found = allTables.firstWhere((t) => t.id == val);
                    onChanged(found);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Status & Details Indicator
          if (selectedTable != null)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    selectedTable.status.toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                if (hasPendingCart)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade200,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade700, width: 0.8),
                    ),
                    child: Text(
                      'Cart: $cartItemCount items',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  )
                else
                  Text(
                    '${selectedTable.capacity} Seats',
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSwapSummaryBanner() {
    if (_sourceTable == null || _targetTable == null) {
      return const SizedBox.shrink();
    }

    final targetIsAvailable = _targetTable!.status.toUpperCase() == 'AVAILABLE';
    final sourceName = _sourceTable!.tableName;
    final targetName = _targetTable!.tableName;

    String explanation;
    IconData icon;
    Color color;

    if (targetIsAvailable) {
      explanation = 'Order from $sourceName will be transferred to $targetName. $sourceName will become Available.';
      icon = Icons.move_up_rounded;
      color = const Color(0xFF10B981);
    } else {
      explanation = 'Both $sourceName and $targetName have orders. Active bills and items will be completely swapped between both tables.';
      icon = Icons.swap_horiz_rounded;
      color = const Color(0xFF2563EB);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              explanation,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performSwap() async {
    if (_sourceTable == null || _targetTable == null) return;
    setState(() => _isProcessing = true);

    try {
      final s = _sourceTable!;
      final t = _targetTable!;

      // 1. Swap in-memory POS carts and tables
      widget.posProvider.swapTableOrders(s, t);

      // 2. Swap database records and active invoices
      await widget.tableProvider.swapTables(s, t);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Successfully swapped orders between ${s.tableName} and ${t.tableName}!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to swap tables: $err'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}