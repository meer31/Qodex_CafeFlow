import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/waiter_model.dart';
import '../providers/pos_provider.dart';
import '../providers/waiter_provider.dart';

/// Interactive modal dialog for selecting a waiter / staff member for POS orders.
class PosWaiterSelectionDialog extends StatefulWidget {
  final PosProvider posProvider;
  final WaiterProvider waiterProvider;

  const PosWaiterSelectionDialog({
    super.key,
    required this.posProvider,
    required this.waiterProvider,
  });

  static Future<WaiterModel?> show(
    BuildContext context, {
    required PosProvider posProvider,
    required WaiterProvider waiterProvider,
  }) {
    return showDialog<WaiterModel?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PosWaiterSelectionDialog(
        posProvider: posProvider,
        waiterProvider: waiterProvider,
      ),
    );
  }

  @override
  State<PosWaiterSelectionDialog> createState() => _PosWaiterSelectionDialogState();
}

class _PosWaiterSelectionDialogState extends State<PosWaiterSelectionDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final activeWaiters = widget.waiterProvider.waiters
        .where((w) => w.status.toLowerCase() == 'active')
        .toList();

    final filteredWaiters = activeWaiters.where((w) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return w.name.toLowerCase().contains(q) || w.phone.contains(q);
    }).toList();

    final selectedWaiter = widget.posProvider.selectedWaiter;
    final selectedTable = widget.posProvider.selectedTable;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: screenHeight * 0.85,
          minHeight: 360,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.badge_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Waiter / Server',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedTable != null
                              ? 'Order for Table: ${selectedTable.tableName} (${selectedTable.sectionName})'
                              : 'Select staff member or choose Self Service',
                          style: TextStyle(
                            fontSize: 12,
                            color: selectedTable != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: selectedTable != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search Bar & Options
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search waiter by name or phone...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),

            // Waiters List / Grid
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // Self-service / No Waiter Card
                  _buildNoWaiterCard(selectedWaiter == null),
                  const SizedBox(height: 10),

                  if (filteredWaiters.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          'No active waiters found.\nYou can select "No Waiter / Self Service".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...filteredWaiters.map((w) {
                      final isSelected = selectedWaiter?.id == w.id;
                      return _buildWaiterCard(w, isSelected);
                    }),
                ],
              ),
            ),

            // Footer info / Skip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 15, color: AppColors.textMuted),
                      SizedBox(width: 6),
                      Text(
                        'Waiter can be changed anytime before checkout',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      widget.posProvider.selectWaiter(null);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Skip / None'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoWaiterCard(bool isSelected) {
    return InkWell(
      onTap: () {
        widget.posProvider.selectWaiter(null);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order set to Self Service / Counter (No Waiter)'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_off_rounded, color: AppColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Waiter / Self Service',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Customer orders at counter without assigned staff',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiterCard(WaiterModel waiter, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          widget.posProvider.selectWaiter(waiter);
          Navigator.of(context).pop(waiter);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assigned Waiter: ${waiter.name}'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isSelected ? AppColors.primary : AppColors.secondary,
                child: Text(
                  waiter.name.isNotEmpty ? waiter.name.substring(0, 1).toUpperCase() : 'W',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiter.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (waiter.phone.isNotEmpty) ...[
                          Icon(Icons.phone_rounded, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            waiter.phone,
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
              else
                Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}