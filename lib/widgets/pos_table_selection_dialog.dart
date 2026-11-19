import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/cafe_table_model.dart';
import '../models/sale_model.dart';
import '../models/waiter_model.dart';
import '../providers/pos_provider.dart';
import '../providers/table_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/waiter_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/sale_session_provider.dart';
import '../providers/stock_provider.dart';
import './swap_table_dialog.dart';
import './invoice_dialogs.dart';

/// Interactive modal dialog for selecting dining tables in POS.
/// Features a left sidebar with all sections (plus Takeaway option),
/// and a main grid displaying tables as square cards.
/// Reserved tables are colored in RED and Available tables in GREEN for intuitive visual cues.
class PosTableSelectionDialog extends StatefulWidget {
  final PosProvider posProvider;
  final TableProvider tableProvider;

  const PosTableSelectionDialog({
    super.key,
    required this.posProvider,
    required this.tableProvider,
  });

  /// Helper static method to open the dialog easily from any screen
  static Future<CafeTableModel?> show(
    BuildContext context, {
    required PosProvider posProvider,
    required TableProvider tableProvider,
  }) {
    return showDialog<CafeTableModel?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PosTableSelectionDialog(
        posProvider: posProvider,
        tableProvider: tableProvider,
      ),
    );
  }

  @override
  State<PosTableSelectionDialog> createState() => _PosTableSelectionDialogState();
}

class _PosTableSelectionDialogState extends State<PosTableSelectionDialog> {
  int? _selectedSectionId;
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // 'ALL', 'AVAILABLE', 'RESERVED', 'OCCUPIED'

  @override
  void initState() {
    super.initState();
    final sections = widget.tableProvider.sections;
    if (sections.isNotEmpty) {
      _selectedSectionId = sections.first.id;
    }
  }

  int _extractTableNumber(String name) {
    final match = RegExp(r'\d+').firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '') ?? 999999;
    }
    return 999999;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.tableProvider, widget.posProvider]),
      builder: (context, _) {
        final sections = widget.tableProvider.sections;
        final allTables = widget.tableProvider.tables;
        final selectedTable = widget.posProvider.selectedTable;

        // Ensure active section is selected by default
        if (sections.isNotEmpty) {
          if (_selectedSectionId == null || !sections.any((s) => s.id == _selectedSectionId)) {
            _selectedSectionId = sections.first.id;
          }
        } else {
          _selectedSectionId = null;
        }

        // STRICT FILTER: Strictly only tables belonging to the selected section
        final filteredTables = allTables.where((table) {
          final matchesSection = _selectedSectionId != null && table.sectionId == _selectedSectionId;
          final matchesSearch = _searchQuery.isEmpty ||
              table.tableName.toLowerCase().contains(_searchQuery.toLowerCase());
          final isCurSelected = widget.posProvider.selectedTable?.id == table.id;
          final tableCart = isCurSelected
              ? widget.posProvider.cart
              : (widget.posProvider.tableCarts[table.id] ?? []);
          final bool hasPendingCart = tableCart.isNotEmpty;
          final primarySale = widget.tableProvider.getPrimaryRemainingSaleForTable(
            table.id ?? 0,
            tableName: table.tableName,
            activeInvoiceNum: table.activeInvoiceNumber,
          );
          final statusUpper = table.status.toUpperCase();
          final bool isOccupiedNow = statusUpper == 'OCCUPIED' || hasPendingCart || primarySale != null;
          final matchesStatus = _statusFilter == 'ALL' ||
              (_statusFilter == 'AVAILABLE' && statusUpper == 'AVAILABLE' && !hasPendingCart && primarySale == null) ||
              (_statusFilter == 'RESERVED' && statusUpper == 'RESERVED') ||
              (_statusFilter == 'OCCUPIED' && isOccupiedNow);
          return matchesSection && matchesSearch && matchesStatus;
        }).toList();

        // SORT ASCENDING: Natural numerical order (Table 1, Table 2, Table 3... Table 10)
        filteredTables.sort((a, b) {
          final numA = _extractTableNumber(a.tableName);
          final numB = _extractTableNumber(b.tableName);
          if (numA != numB) {
            return numA.compareTo(numB);
          }
          return a.tableName.toLowerCase().compareTo(b.tableName.toLowerCase());
        });

        // Current section tables count
        final sectionTables = _selectedSectionId != null
            ? allTables.where((t) => t.sectionId == _selectedSectionId).toList()
            : allTables;
        final availableCount =
            sectionTables.where((t) => t.status.toUpperCase() == 'AVAILABLE').length;
        final reservedCount =
            sectionTables.where((t) => t.status.toUpperCase() == 'RESERVED').length;
        final occupiedCount =
            sectionTables.where((t) => t.status.toUpperCase() == 'OCCUPIED').length;

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isCompact = screenWidth < 700;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 28,
            vertical: isCompact ? 16 : 28,
          ),
          backgroundColor: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 980,
              maxHeight: screenHeight * 0.88,
              minHeight: 480,
            ),
            child: Column(
              children: [
                // Top Header Bar
                _buildDialogHeader(
                  context,
                  selectedTable: selectedTable,
                  availableCount: availableCount,
                  reservedCount: reservedCount,
                  occupiedCount: occupiedCount,
                ),
                const Divider(height: 1),

                // Content Area (Sidebar + Main Grid)
                Expanded(
                  child: isCompact
                      ? _buildCompactLayout(sections, allTables, filteredTables)
                      : _buildSplitLayout(sections, allTables, filteredTables),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Dialog Header with Title, Active Table, and Status Legend
  Widget _buildDialogHeader(
    BuildContext context, {
    required CafeTableModel? selectedTable,
    required int availableCount,
    required int reservedCount,
    required int occupiedCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeader = constraints.maxWidth < 780;

        final legendWidget = Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildLegendPill(
              label: 'Available ($availableCount)',
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
            ),
            _buildLegendPill(
              label: 'Reserved ($reservedCount)',
              color: const Color(0xFFEF4444),
              bgColor: const Color(0xFFFEF2F2),
            ),
            if (occupiedCount > 0)
              _buildLegendPill(
                label: 'Occupied ($occupiedCount)',
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFFF1F2),
              ),
          ],
        );

        final swapButton = OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
          label: const Text(
            'Swap Tables',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            SwapTableDialog.show(
              context,
              posProvider: widget.posProvider,
              tableProvider: widget.tableProvider,
              initialSourceTable: widget.posProvider.selectedTable,
            );
          },
        );

        final closeButton = IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        );

        if (isCompactHeader) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.cardBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.table_restaurant_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Dining Table',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            selectedTable != null
                                ? 'Current: ${selectedTable.tableName} (${selectedTable.sectionName})'
                                : 'Current: Takeaway / Counter Sale',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selectedTable != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    swapButton,
                    const SizedBox(width: 4),
                    closeButton,
                  ],
                ),
                const SizedBox(height: 8),
                legendWidget,
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: AppColors.cardBg,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.table_restaurant_rounded,
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
                      'Select Dining Table',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedTable != null
                          ? 'Current: ${selectedTable.tableName} (${selectedTable.sectionName})'
                          : 'Current: Takeaway / Counter Sale',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selectedTable != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: legendWidget,
              ),
              const SizedBox(width: 10),
              swapButton,
              const SizedBox(width: 4),
              closeButton,
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendPill({
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Split Layout: Left Sidebar + Right Main Grid (Desktop & Tablet)
  Widget _buildSplitLayout(
    List<TableSectionModel> sections,
    List<CafeTableModel> allTables,
    List<CafeTableModel> filteredTables,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT SIDEBAR: Sections List & Takeaway Option
        Container(
          width: 230,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: _buildSidebarContent(sections, allTables),
        ),

        // RIGHT MAIN SCREEN: Search, Status Filter & Square Tables Grid
        Expanded(
          child: Container(
            color: AppColors.background,
            padding: const EdgeInsets.all(18),
            child: _buildMainScreenContent(filteredTables, sections),
          ),
        ),
      ],
    );
  }

  /// Compact Layout: Top Horizontal Section Bar + Main Grid (Mobile)
  Widget _buildCompactLayout(
    List<TableSectionModel> sections,
    List<CafeTableModel> allTables,
    List<CafeTableModel> filteredTables,
  ) {
    return Column(
      children: [
        // Horizontal Sections Tab Bar
        Container(
          height: 48,
          color: AppColors.cardBg,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              // Takeaway Action Button
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.shopping_bag_outlined, size: 16, color: Color(0xFFEA580C)),
                  label: const Text('Takeaway / Counter'),
                  backgroundColor: const Color(0xFFFFF7ED),
                  side: const BorderSide(color: Color(0xFFFDBA74)),
                  onPressed: () => _selectTakeaway(),
                ),
              ),
              // Add Section Chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                  label: Text('+ Section', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  onPressed: () => _showAddSectionDialog(context),
                ),
              ),
              // Dynamic Section Chips (ONLY section-wise chips)
              ...sections.map((sec) {
                final count = allTables.where((t) => t.sectionId == sec.id).length;
                final isSelected = _selectedSectionId == sec.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${sec.name} ($count)'),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() => _selectedSectionId = sec.id),
                  ),
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1),

        // Main Grid Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildMainScreenContent(filteredTables, sections),
          ),
        ),
      ],
    );
  }

  /// Left Sidebar Content for Split Layout
  Widget _buildSidebarContent(
    List<TableSectionModel> sections,
    List<CafeTableModel> allTables,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Title with Add Section Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SECTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              InkWell(
                onTap: () => _showAddSectionDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 13, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Takeaway Option (Direct Selection)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Material(
            color: widget.posProvider.selectedTable == null
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => _selectTakeaway(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.posProvider.selectedTable == null
                        ? AppColors.primary
                        : AppColors.border,
                    width: widget.posProvider.selectedTable == null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Takeaway / Counter',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'No table required',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.posProvider.selectedTable == null)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFFEA580C),
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1),
        ),
        const SizedBox(height: 6),

        // Section list items (NO "All Sections"!)
        Expanded(
          child: sections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.meeting_room_outlined, size: 32, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No sections yet',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add Section', style: TextStyle(fontSize: 11)),
                          onPressed: () => _showAddSectionDialog(context),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: sections.map((sec) {
                    final sectionTables =
                        allTables.where((t) => t.sectionId == sec.id).toList();
                    final availableInSec = sectionTables
                        .where((t) => t.status.toUpperCase() == 'AVAILABLE')
                        .length;
                    final reservedInSec = sectionTables
                        .where((t) => t.status.toUpperCase() == 'RESERVED')
                        .length;

                    return _buildSidebarItem(
                      title: sec.name,
                      icon: Icons.meeting_room_outlined,
                      count: sectionTables.length,
                      availableCount: availableInSec,
                      reservedCount: reservedInSec,
                      isSelected: _selectedSectionId == sec.id,
                      onTap: () => setState(() => _selectedSectionId = sec.id),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required String title,
    required IconData icon,
    required int count,
    int? availableCount,
    int? reservedCount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (availableCount != null && availableCount > 0 && !isSelected) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$availableCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.25))
                        : AppColors.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Main Screen Content: Search Bar, Status Filter, and Square Tables Grid
  Widget _buildMainScreenContent(
    List<CafeTableModel> filteredTables,
    List<TableSectionModel> sections,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Row: Search Input & Status Filter Chips & Add Table Button
        Row(
          children: [
            // Search Input
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 38,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search table (e.g. Table 1)...',
                    hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.cardBg,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Status Filter Chips
            _buildStatusChip('ALL', 'All'),
            const SizedBox(width: 4),
            _buildStatusChip('AVAILABLE', 'Available', color: const Color(0xFF10B981)),
            const SizedBox(width: 4),
            _buildStatusChip('RESERVED', 'Reserved', color: const Color(0xFFEF4444)),
            const SizedBox(width: 4),
            _buildStatusChip('OCCUPIED', 'Occupied', color: const Color(0xFFDC2626)),
            const SizedBox(width: 8),

            // + Add Table Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Add Table',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showAddTableDialog(context, sections),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Square Tables Grid View
        Expanded(
          child: filteredTables.isEmpty
              ? _buildEmptyState(sections)
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    childAspectRatio: 1.0, // Guaranteed Square Shape
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: filteredTables.length,
                  itemBuilder: (context, index) {
                    final table = filteredTables[index];
                    return _buildSquareTableCard(table);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String key, String label, {Color? color}) {
    final isSelected = _statusFilter == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppColors.primary)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? (color ?? AppColors.primary)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (isDark && color == null ? const Color(0xFF0F172A) : Colors.white)
                : (color ?? AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  /// Square Table Card Component
  /// Reserved = RED
  /// Available = GREEN
  /// Square shape (1:1 aspect ratio) for easy, rapid touch selection
  Widget _buildSquareTableCard(CafeTableModel table) {
    final isCurrentSelected =
        widget.posProvider.selectedTable?.id == table.id;
    final cartForTable = isCurrentSelected
        ? widget.posProvider.cart
        : (widget.posProvider.tableCarts[table.id] ?? []);
    final bool hasPendingCart = cartForTable.isNotEmpty;
    final pendingItemCount = cartForTable.fold<int>(
        0, (sum, item) => sum + item.quantity);
    final double pendingCartTotal = cartForTable.fold<double>(
        0.0, (sum, item) => sum + item.totalPrice);

    final primarySale = widget.tableProvider.getPrimaryRemainingSaleForTable(
      table.id ?? 0,
      tableName: table.tableName,
      activeInvoiceNum: table.activeInvoiceNumber,
    );
    final statusUpper = table.status.toUpperCase();
    final bool isReserved = statusUpper == 'RESERVED';
    final bool hasDelayedBill = primarySale != null;
    final bool isOccupied = statusUpper == 'OCCUPIED' || hasPendingCart || hasDelayedBill;
    final bool isAvailable = statusUpper == 'AVAILABLE' && !hasPendingCart && !hasDelayedBill;
    final bool isDraftOccupied = hasPendingCart && !hasDelayedBill;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    String currency = 'Rs.';
    try {
      currency = Provider.of<SettingsProvider>(context, listen: false).settings.currencySymbol;
    } catch (_) {}

    // COLOR LOGIC:
    // Reserved = Bright Red (0xFFEF4444)
    // Delayed Bill = Orange (0xFFEA580C)
    // Items added without delayed/kitchen bill = Slightly Red / Soft Rose-Red (0xFFF43F5E)
    // Occupied = Crimson Red (0xFFDC2626)
    // Available = Bright Green (0xFF10B981)
    Color primaryColor;
    Color bgColor;
    Color badgeColor;
    Color textColor;

    if (isReserved) {
      primaryColor = const Color(0xFFEF4444); // Bright Red
      bgColor = isDark ? const Color(0xFF381216) : const Color(0xFFFEF2F2);
      badgeColor = const Color(0xFFEF4444);
      textColor = isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B);
    } else if (hasDelayedBill) {
      primaryColor = const Color(0xFFEA580C); // Orange Delayed Bill
      bgColor = isDark ? const Color(0xFF38180A) : const Color(0xFFFFF7ED);
      badgeColor = const Color(0xFFEA580C);
      textColor = isDark ? const Color(0xFFFED7AA) : const Color(0xFF9A3412);
    } else if (isDraftOccupied) {
      // User request: When items added and no delayed/kitchen bill yet, mark as Occupied with slightly red color
      primaryColor = const Color(0xFFF43F5E); // Soft Rose/Coral Red (slightly red)
      bgColor = isDark ? const Color(0xFF331118) : const Color(0xFFFFF1F2);
      badgeColor = const Color(0xFFF43F5E);
      textColor = isDark ? const Color(0xFFFECDD3) : const Color(0xFF9F1239);
    } else if (isOccupied) {
      primaryColor = const Color(0xFFDC2626); // Crimson / Occupied
      bgColor = isDark ? const Color(0xFF3B0F15) : const Color(0xFFFFF1F2);
      badgeColor = const Color(0xFFDC2626);
      textColor = isDark ? const Color(0xFFFECDD3) : const Color(0xFF9F1239);
    } else if (isAvailable) {
      primaryColor = const Color(0xFF10B981); // Bright Green
      bgColor = isDark ? const Color(0xFF063321) : const Color(0xFFF0FDF4);
      badgeColor = const Color(0xFF10B981);
      textColor = isDark ? const Color(0xFFA7F3D0) : const Color(0xFF166534);
    } else {
      // Cleaning or other
      primaryColor = const Color(0xFF3B82F6);
      bgColor = isDark ? const Color(0xFF10284E) : const Color(0xFFEFF6FF);
      badgeColor = const Color(0xFF3B82F6);
      textColor = isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E40AF);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTableTapped(table),
        borderRadius: BorderRadius.circular(12),
        splashColor: primaryColor.withValues(alpha: 0.2),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentSelected
                  ? AppColors.primary
                  : primaryColor,
              width: isCurrentSelected ? 2.5 : 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Current Selected indicator ring or badge
              if (isCurrentSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),

              // Square Card Interior
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top: Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasDelayedBill ? const Color(0xFFEA580C) : badgeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasDelayedBill
                            ? 'DELAYED BILL'
                            : (isOccupied ? 'OCCUPIED' : table.status.toUpperCase()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Center: Table Icon + Table Name
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isReserved
                              ? Icons.event_seat_rounded
                              : (hasDelayedBill ? Icons.hourglass_top_rounded : Icons.table_restaurant_rounded),
                          color: hasDelayedBill ? const Color(0xFFEA580C) : primaryColor,
                          size: 26,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          table.tableName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          table.sectionName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: primaryColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),

                    // Bottom: Capacity or Pending Cart Badge or Delayed Bill Badge
                    if (hasPendingCart)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        constraints: const BoxConstraints(maxWidth: 95),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF4C0519) : const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFF43F5E), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_cart_rounded, size: 9, color: Color(0xFFE11D48)),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                pendingCartTotal > 0
                                    ? '$pendingItemCount items • $currency${pendingCartTotal.toStringAsFixed(0)}'
                                    : '$pendingItemCount item${pendingItemCount > 1 ? 's' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFBE123C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (hasDelayedBill)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        constraints: const BoxConstraints(maxWidth: 95),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF431407) : const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFEA580C), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 9, color: Color(0xFFEA580C)),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                '$currency${(primarySale.grandTotal).toStringAsFixed(0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 11,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${table.capacity} Seats',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: textColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(List<TableSectionModel> sections) {
    TableSectionModel? currentSec;
    if (_selectedSectionId != null && sections.any((s) => s.id == _selectedSectionId)) {
      currentSec = sections.firstWhere((s) => s.id == _selectedSectionId);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.table_restaurant_outlined,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            currentSec != null ? 'No tables in "${currentSec.name}"' : 'No matching tables found',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add tables to this section or adjust your search filter',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              currentSec != null ? 'Add Table to ${currentSec.name}' : 'Add Table',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () => _showAddTableDialog(context, sections),
          ),
        ],
      ),
    );
  }

  /// Handles when a table card is tapped
  void _onTableTapped(CafeTableModel table) {
    final statusUpper = table.status.toUpperCase();
    final bool isCurrentSel = widget.posProvider.selectedTable?.id == table.id;
    final draftItems = isCurrentSel
        ? widget.posProvider.cart
        : (widget.posProvider.tableCarts[table.id] ?? []);
    final bool hasDraft = draftItems.isNotEmpty;
    final primarySale = widget.tableProvider.getPrimaryRemainingSaleForTable(
      table.id ?? 0,
      tableName: table.tableName,
      activeInvoiceNum: table.activeInvoiceNumber,
    );

    // If Reserved: confirm with user or seat directly
    if (statusUpper == 'RESERVED') {
      _showReservedTablePrompt(table);
      return;
    }

    // If Occupied (either marked Occupied, has remaining sale, or has draft items):
    if (statusUpper == 'OCCUPIED' || primarySale != null || hasDraft) {
      _showOccupiedTablePrompt(table);
      return;
    }

    // Available or Cleaning: Select immediately!
    _applyTableSelection(table);
  }

  void _showReservedTablePrompt(CafeTableModel table) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.bookmark_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text('Assign Reserved ${table.tableName}?'),
          ],
        ),
        content: Text(
          '${table.tableName} (${table.sectionName}) is currently marked as RESERVED.\n\nDo you want to assign this table to the current order now?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _applyTableSelection(table);
            },
            child: const Text('Seat & Assign Table'),
          ),
        ],
      ),
    );
  }

  void _showOccupiedTablePrompt(CafeTableModel table) {
    final primarySale = widget.tableProvider.getPrimaryRemainingSaleForTable(
      table.id ?? 0,
      tableName: table.tableName,
      activeInvoiceNum: table.activeInvoiceNumber,
    );
    final bool hasDelayedBill = primarySale != null;
    final bool isCurrentSel = widget.posProvider.selectedTable?.id == table.id;
    final draftItems = isCurrentSel
        ? widget.posProvider.cart
        : (widget.posProvider.tableCarts[table.id] ?? []);
    final bool hasDraft = draftItems.isNotEmpty;
    final double draftTotal = draftItems.fold<double>(0.0, (s, i) => s + i.totalPrice);
    final int draftQty = draftItems.fold<int>(0, (s, i) => s + i.quantity);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    String currency = 'Rs.';
    try {
      currency = Provider.of<SettingsProvider>(context, listen: false).settings.currencySymbol;
    } catch (_) {}

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasDelayedBill
                    ? Colors.orange.shade100
                    : (hasDraft
                        ? const Color(0xFFFFF1F2)
                        : const Color(0xFFDC2626).withValues(alpha: 0.12)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasDelayedBill
                    ? Icons.hourglass_top_rounded
                    : (hasDraft ? Icons.shopping_cart_rounded : Icons.warning_amber_rounded),
                color: hasDelayedBill
                    ? Colors.orange.shade900
                    : (hasDraft ? const Color(0xFFF43F5E) : const Color(0xFFDC2626)),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${table.tableName} (${table.sectionName})',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasDelayedBill
                              ? Colors.orange.shade100
                              : (hasDraft
                                  ? const Color(0xFFFFF1F2)
                                  : const Color(0xFFDC2626).withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: hasDelayedBill
                                ? Colors.orange.shade400
                                : (hasDraft
                                    ? const Color(0xFFF43F5E)
                                    : const Color(0xFFDC2626).withValues(alpha: 0.4)),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          hasDelayedBill ? 'DELAYED BILL' : 'OCCUPIED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasDelayedBill
                                ? Colors.orange.shade900
                                : (hasDraft ? const Color(0xFFE11D48) : const Color(0xFFDC2626)),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDelayedBill
                        ? 'Invoice #${primarySale.invoiceNumber} • Payment Pending'
                        : (hasDraft
                            ? 'Active Draft Order • $draftQty items ($currency${draftTotal.toStringAsFixed(0)})'
                            : '${table.tableName} currently has active dining activity'),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDelayedBill) ...[
                // Highlighted Bill Total & Status Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B1A08) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade300, width: 1.2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 18, color: Colors.orange.shade900),
                              const SizedBox(width: 6),
                              Text(
                                'Invoice #${primarySale.invoiceNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$currency ${primarySale.grandTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Due Amount: $currency ${primarySale.grandTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                            ),
                          ),
                          Text(
                            'Items: ${primarySale.items.fold<int>(0, (sum, i) => sum + i.quantity)}',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (primarySale.waiterName != null && primarySale.waiterName!.isNotEmpty)
                            Text(
                              'Waiter: ${primarySale.waiterName}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'ORDER ITEMS:',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
                ),
                const SizedBox(height: 5),
                Container(
                  constraints: const BoxConstraints(maxHeight: 110),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    itemCount: primarySale.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 6),
                    itemBuilder: (context, idx) {
                      final item = primarySale.items[idx];
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.quantity}x',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.productName,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$currency ${(item.unitPrice * item.quantity).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose an option below to view the invoice, clear the bill, switch & resume editing in POS, or swap table.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ] else if (hasDraft) ...[
                // Draft items preview
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF341118) : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 16, color: Color(0xFFF43F5E)),
                          const SizedBox(width: 6),
                          Text(
                            'Active Draft ($draftQty items)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFBE123C)),
                          ),
                        ],
                      ),
                      Text(
                        '$currency ${draftTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFBE123C)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ORDER ITEMS:',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
                ),
                const SizedBox(height: 5),
                Container(
                  constraints: const BoxConstraints(maxHeight: 110),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    itemCount: draftItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 6),
                    itemBuilder: (context, idx) {
                      final item = draftItems[idx];
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.quantity}x',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.productName,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$currency ${(item.unitPrice * item.quantity).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Switch to this table in POS to continue adding items or finalize the bill.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ] else ...[
                Text(
                  '${table.tableName} currently has active dining activity.\n\nDo you want to switch to this table to add items or manage its order?',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.border),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Swap Order'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  SwapTableDialog.show(
                    context,
                    posProvider: widget.posProvider,
                    tableProvider: widget.tableProvider,
                    initialSourceTable: table,
                  );
                },
              ),
              if (hasDelayedBill) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('See Invoice'),
                  onPressed: () {
                    InvoiceDialogs.showInvoiceDetailsDialog(
                      context: context,
                      sale: primarySale,
                      currencySymbol: currency,
                    );
                  },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Clear Bill'),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _handleClearBill(primarySale, table);
                  },
                ),
              ],
              if (hasDraft && !hasDelayedBill) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Clear Table'),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await widget.posProvider.clearTableDraft(table.id!);
                    await widget.tableProvider.loadTableData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Table ${table.tableName} draft cleared! Table is now Available.'),
                          backgroundColor: AppColors.accent,
                        ),
                      );
                    }
                  },
                ),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasDelayedBill ? AppColors.primary : const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                icon: Icon(hasDelayedBill ? Icons.edit_note_rounded : Icons.login_rounded, size: 16),
                label: Text(hasDelayedBill ? 'Switch to Table' : 'Switch to Table'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (hasDelayedBill) {
                    _resumeDelayedBillInPos(table, primarySale);
                  } else {
                    _applyTableSelection(table);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleClearBill(SaleModel sale, CafeTableModel table) async {
    await InvoiceDialogs.showClearBillDialog(
      context: context,
      sale: sale,
      onClear: (paymentMethod) async {
        try {
          final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
          await dashboardProvider.clearBill(sale.id!, paymentMethod: paymentMethod);
        } catch (_) {}
        if (!mounted) return;
        try {
          Provider.of<SaleSessionProvider>(context, listen: false).loadSessions();
        } catch (_) {}
        try {
          Provider.of<StockProvider>(context, listen: false).loadStockData();
        } catch (_) {}
        await widget.tableProvider.loadTableData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Table ${table.tableName} bill cleared! Table is now Available.'),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _resumeDelayedBillInPos(CafeTableModel table, SaleModel sale) {
    // 1. If currently active cart belongs to another table, park it cleanly
    if (widget.posProvider.selectedTable != null &&
        widget.posProvider.cart.isNotEmpty &&
        widget.posProvider.selectedTable!.id != table.id) {
      widget.posProvider.selectTable(null);
    }

    // 2. Find waiter if assigned
    WaiterModel? matchedWaiter;
    if (sale.waiterId != null) {
      try {
        final waiterProvider = Provider.of<WaiterProvider>(context, listen: false);
        matchedWaiter = waiterProvider.waiters.firstWhere((w) => w.id == sale.waiterId);
      } catch (_) {}
    }

    // 3. Load invoice into POS for editing
    widget.posProvider.loadInvoiceForEditing(
      sale,
      table: table,
      waiter: matchedWaiter,
    );

    // 4. Pop the PosTableSelectionDialog and return the table
    Navigator.of(context).pop(table);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Resumed Table ${table.tableName} (Invoice #${sale.invoiceNumber}). Items loaded into POS.',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyTableSelection(CafeTableModel table) {
    widget.posProvider.selectTable(table);
    Navigator.of(context).pop(table);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Selected Table: ${table.tableName} (${table.sectionName})'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectTakeaway() {
    widget.posProvider.selectTable(null);
    Navigator.of(context).pop(null);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Switched to Takeaway / Counter Sale'),
          ],
        ),
        backgroundColor: Color(0xFFEA580C),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddSectionDialog(BuildContext context) {
    final nameController = TextEditingController();
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Icon(Icons.meeting_room_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text('Add New Section', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter section name (e.g. Family Hall, VIP, Outdoor):',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Section Name',
                        errorText: errorText,
                        prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) {
                        if (errorText != null) {
                          setDialogState(() => errorText = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      setDialogState(() => errorText = 'Section name cannot be empty');
                      return;
                    }
                    final exists = widget.tableProvider.sections.any(
                      (s) => s.name.trim().toLowerCase() == name.toLowerCase(),
                    );
                    if (exists) {
                      setDialogState(() => errorText = 'Section "$name" already exists!');
                      return;
                    }

                    Navigator.of(dialogCtx).pop();
                    await widget.tableProvider.addSection(name);

                    // Automatically switch to the newly created section
                    final newSec = widget.tableProvider.sections.firstWhere(
                      (s) => s.name.trim().toLowerCase() == name.toLowerCase(),
                      orElse: () => widget.tableProvider.sections.last,
                    );
                    setState(() {
                      _selectedSectionId = newSec.id;
                    });

                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Section "$name" created successfully!'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Create Section'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTableDialog(BuildContext context, List<TableSectionModel> sections) {
    if (sections.isEmpty) {
      _showAddSectionDialog(context);
      return;
    }

    TableSectionModel currentSection;
    if (_selectedSectionId != null && sections.any((s) => s.id == _selectedSectionId)) {
      currentSection = sections.firstWhere((s) => s.id == _selectedSectionId);
    } else {
      currentSection = sections.first;
    }

    final numberController = TextEditingController();
    final capacityController = TextEditingController(text: '4');
    String? errorText;
    int selectedSecId = currentSection.id!;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final activeSec = sections.firstWhere(
              (s) => s.id == selectedSecId,
              orElse: () => currentSection,
            );
            final enteredNumber = numberController.text.trim();
            final previewName = enteredNumber.isNotEmpty ? 'Table $enteredNumber' : 'Table ...';
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Icon(Icons.table_restaurant_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add Table to ${activeSec.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Selector
                    Text('Section:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                        color: AppColors.cardBg,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedSecId,
                          items: sections.map((s) {
                            return DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedSecId = val;
                                final newSec = sections.firstWhere((s) => s.id == val, orElse: () => activeSec);
                                final trimmed = numberController.text.trim();
                                if (trimmed.isNotEmpty) {
                                  final prospectiveName = 'Table $trimmed';
                                  final isDup = widget.tableProvider.tables.any(
                                    (t) => t.sectionId == val && t.tableName.trim().toLowerCase() == prospectiveName.toLowerCase(),
                                  );
                                  errorText = isDup ? '$prospectiveName already exists in ${newSec.name}!' : null;
                                } else {
                                  errorText = null;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Table Number input
                    Text('Table Number (just enter number):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: numberController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Text(
                            'Table ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '1',
                        errorText: errorText,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          final trimmed = val.trim();
                          if (trimmed.isNotEmpty) {
                            final prospectiveName = 'Table $trimmed';
                            final isDup = widget.tableProvider.tables.any(
                              (t) => t.sectionId == selectedSecId && t.tableName.trim().toLowerCase() == prospectiveName.toLowerCase(),
                            );
                            if (isDup) {
                              errorText = '$prospectiveName already exists in ${activeSec.name}!';
                            } else {
                              errorText = null;
                            }
                          } else {
                            errorText = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    // Live preview / error banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: errorText == null
                            ? (isDark ? const Color(0xFF063321) : const Color(0xFFECFDF5))
                            : (isDark ? const Color(0xFF381216) : const Color(0xFFFEF2F2)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: errorText == null
                              ? (isDark ? const Color(0xFF10B981) : const Color(0xFFA7F3D0))
                              : (isDark ? const Color(0xFFEF4444) : const Color(0xFFFECACA)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            errorText == null ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                            size: 14,
                            color: errorText == null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errorText == null
                                  ? 'Table will be named "$previewName" in ${activeSec.name}'
                                  : errorText!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: errorText == null
                                    ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857))
                                    : (isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Capacity (Seats)
                    Text('Capacity (Seats):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '4',
                        prefixIcon: const Icon(Icons.people_outline_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final trimmed = numberController.text.trim();
                    if (trimmed.isEmpty) {
                      setDialogState(() => errorText = 'Please enter a table number');
                      return;
                    }
                    final numVal = int.tryParse(trimmed);
                    if (numVal == null || numVal <= 0) {
                      setDialogState(() => errorText = 'Please enter a valid positive number');
                      return;
                    }
                    final tableName = 'Table $numVal';
                    final isDup = widget.tableProvider.tables.any(
                      (t) => t.sectionId == activeSec.id && t.tableName.trim().toLowerCase() == tableName.toLowerCase(),
                    );
                    if (isDup) {
                      setDialogState(() => errorText = '$tableName already exists in ${activeSec.name}!');
                      return;
                    }

                    final capacity = int.tryParse(capacityController.text.trim()) ?? 4;
                    Navigator.of(dialogCtx).pop();

                    await widget.tableProvider.addTable(
                      CafeTableModel(
                        sectionId: activeSec.id!,
                        sectionName: activeSec.name,
                        tableName: tableName,
                        capacity: capacity,
                        status: 'Available',
                      ),
                    );

                    setState(() {
                      _selectedSectionId = activeSec.id;
                    });

                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('$tableName added successfully to ${activeSec.name}!'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Add Table'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}