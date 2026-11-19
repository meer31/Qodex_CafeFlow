import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/app_settings_model.dart';
import '../providers/settings_provider.dart';
import '../providers/category_provider.dart';
import '../providers/product_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/table_provider.dart';
import '../providers/waiter_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/dashboard_provider.dart';
import '../database/database_helper.dart';
import '../widgets/milk_ratio_dialog.dart';
import '../services/backup_service.dart';
import '../services/invoice_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _footerController;
  late TextEditingController _taxController;
  late TextEditingController _currencyController;
  late TextEditingController _milkRatioController;
  String _dbPathDisplay = 'Loading...';

  @override
  void initState() {
    super.initState();
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    _nameController = TextEditingController(text: s.cafeName);
    _addressController = TextEditingController(text: s.address);
    _phoneController = TextEditingController(text: s.phone);
    _footerController = TextEditingController(text: s.receiptFooter);
    _taxController = TextEditingController(text: s.taxPercent.toString());
    _currencyController = TextEditingController(text: s.currencySymbol);
    _milkRatioController = TextEditingController(text: s.milkCupsPerKg.toString());
    _loadDbPath();
  }

  Future<void> _loadDbPath() async {
    final path = await DatabaseHelper.instance.getDatabasePath();
    if (mounted) {
      setState(() => _dbPathDisplay = path);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerController.dispose();
    _taxController.dispose();
    _currencyController.dispose();
    _milkRatioController.dispose();
    super.dispose();
  }

  Future<void> _reloadSettings() async {
    final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
    await settingsProv.loadSettings();
    final s = settingsProv.settings;
    _nameController.text = s.cafeName;
    _addressController.text = s.address;
    _phoneController.text = s.phone;
    _footerController.text = s.receiptFooter;
    _taxController.text = s.taxPercent.toString();
    _currencyController.text = s.currencySymbol;
    _milkRatioController.text = s.milkCupsPerKg.toString();
    await _loadDbPath();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings reloaded from database.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProv = Provider.of<SettingsProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 680;
        final padding = isNarrow ? 12.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Settings & Preferences',
                          style: TextStyle(fontSize: isNarrow ? 20 : 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Configure cafe information, receipt layouts, taxes, currency, milk engine ratios, and database backup (.db)',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Reload Settings',
                    onPressed: _reloadSettings,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // THEME & APPEARANCE CARD (5 SELECTABLE THEMES)
              Container(
                padding: EdgeInsets.all(isNarrow ? 16 : 24),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.palette_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'APPEARANCE & THEME PREFERENCES',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                'Select your preferred visual style. 5 curated themes available, including 3 restaurant-tailored Dark Modes for evening & night shifts.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 5 Interactive Theme Cards in Responsive Wrap
                    LayoutBuilder(
                      builder: (context, boxConstraints) {
                        final currentThemeKey = settingsProv.settings.appTheme;
                        final double totalWidth = boxConstraints.maxWidth;
                        final int columns = totalWidth > 1050 ? 3 : (totalWidth > 640 ? 2 : 1);
                        final double cardWidth = (totalWidth - (columns - 1) * 14) / columns;

                        final cards = AppTheme.availableThemes.map((palette) {
                          final isSelected = currentThemeKey == palette.key;

                          return InkWell(
                            onTap: () async {
                              await settingsProv.updateTheme(palette.key);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        Text('App theme updated to "${palette.name}"'),
                                      ],
                                    ),
                                    backgroundColor: palette.primary,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? palette.primary.withValues(alpha: 0.12)
                                    : palette.cardBg,
                                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                                border: Border.all(
                                  color: isSelected ? palette.primary : palette.border,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: palette.primary.withValues(alpha: 0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          palette.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                            color: palette.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: palette.primary,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_rounded,
                                                color: palette.isDark ? const Color(0xFF0F172A) : Colors.white,
                                                size: 13,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'ACTIVE',
                                                style: TextStyle(
                                                  color: palette.isDark ? const Color(0xFF0F172A) : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.radio_button_unchecked_rounded,
                                          color: palette.textMuted,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    palette.subtitle,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: palette.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 14),

                                  // Swatches
                                  Row(
                                    children: [
                                      _buildColorSwatch('Primary', palette.primary),
                                      const SizedBox(width: 8),
                                      _buildColorSwatch('Accent', palette.accent),
                                      const SizedBox(width: 8),
                                      _buildColorSwatch('Sidebar', palette.sidebarBg),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: palette.isDark
                                              ? palette.primary.withValues(alpha: 0.15)
                                              : Colors.black.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          palette.isDark ? 'Dark Mode' : 'Light Mode',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: palette.isDark ? palette.primary : palette.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList();

                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: cards
                              .map((c) => SizedBox(
                                    width: cardWidth,
                                    child: c,
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // GENERAL & TAX SETTINGS CARD
              Container(
                padding: EdgeInsets.all(isNarrow ? 16 : 24),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GENERAL CAFE INFORMATION', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 16),

                    if (isNarrow) ...[
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Cafe Name'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Contact Phone'),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Cafe Name'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              decoration: const InputDecoration(labelText: 'Contact Phone'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Store Address'),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _footerController,
                      decoration: const InputDecoration(
                        labelText: 'Receipt Footer Message',
                        helperText: 'Text only (emojis removed automatically for clean paper printing)',
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Divider(),
                    const SizedBox(height: 16),

                    Text('CURRENCY & TAX SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 16),

                    if (isNarrow) ...[
                      TextField(
                        controller: _currencyController,
                        decoration: const InputDecoration(labelText: 'Currency Symbol (e.g. Rs. or \$)'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _taxController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Sales Tax Percentage (%)'),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _currencyController,
                              decoration: const InputDecoration(labelText: 'Currency Symbol (e.g. Rs. or \$)'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _taxController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Sales Tax Percentage (%)'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    const Divider(),
                    const SizedBox(height: 16),

                    // MILK RATIO SETTINGS CARD
                    if (isNarrow) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SPECIAL MILK CONVERSION ENGINE', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          Text('Dynamic calculation: 1 KG Milk = N Full Tea Cups', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calculate_rounded),
                        label: const Text('Open Ratio Simulator'),
                        onPressed: () {
                          showDialog(context: context, builder: (_) => const MilkRatioDialog());
                        },
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SPECIAL MILK CONVERSION ENGINE', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                Text('Dynamic calculation: 1 KG Milk = N Full Tea Cups', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calculate_rounded),
                            label: const Text('Open Ratio Simulator'),
                            onPressed: () {
                              showDialog(context: context, builder: (_) => const MilkRatioDialog());
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    TextField(
                      controller: _milkRatioController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Base Milk Ratio (1 KG Milk = N Full Cups)',
                        hintText: 'e.g. 5.0 or 6.0',
                      ),
                    ),

                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save General Settings'),
                        onPressed: () async {
                          final cleanFooter = InvoiceService.sanitizeForThermal(_footerController.text.trim());
                          _footerController.text = cleanFooter;
                          final newSettings = AppSettingsModel(
                            cafeName: _nameController.text.trim(),
                            address: _addressController.text.trim(),
                            phone: _phoneController.text.trim(),
                            receiptFooter: cleanFooter,
                            currencySymbol: _currencyController.text.trim(),
                            taxPercent: double.tryParse(_taxController.text) ?? 0.0,
                            milkCupsPerKg: double.tryParse(_milkRatioController.text) ?? 5.0,
                            appTheme: settingsProv.settings.appTheme,
                          );

                          await settingsProv.updateSettings(newSettings);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Settings saved successfully!'), backgroundColor: AppColors.accent),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // DEDICATED DATABASE MANAGEMENT CARD (.DB FILE)
              Container(
                padding: EdgeInsets.all(isNarrow ? 16 : 24),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.storage_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DATABASE BACKUP & RESTORE (.DB FILE)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                              Text('Export your active database file, or import an existing .db file to back up & restore cafe data.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Active Database Location Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_open_rounded, color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Active Application Database File Path:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                const SizedBox(height: 2),
                                SelectableText(_dbPathDisplay, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Responsive Export / Import Cards
                    if (isNarrow) ...[
                      _buildExportCard(context),
                      const SizedBox(height: 16),
                      _buildImportCard(context),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildExportCard(context)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildImportCard(context)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_rounded, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text('Export Backup (.db)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Saves a backup copy of your current database to any folder (USB drive, Desktop, Cloud).', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            icon: const Icon(Icons.backup_rounded, size: 18),
            label: const Text('Export / Backup Database'),
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selecting destination folder for database backup...'), backgroundColor: AppColors.primary),
                );
                final backupPath = await BackupService.createBackup();
                if (backupPath != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Database backup saved successfully to: $backupPath'),
                      backgroundColor: AppColors.accent,
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup failed: ${e.toString()}'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upload_file_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Import / Restore (.db)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Select an existing .db database file. Replaces current data and backs it up into the application.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('Import / Restore .db File'),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Restore Database File?'),
                  content: const Text(
                    'WARNING: Importing a .db file will replace all current tables, products, categories, sales, invoices, and settings.\n\nAn automated safety backup of your current database will be created first before replacing.\n\nDo you want to proceed?',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Yes, Import Database'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                try {
                  final restored = await BackupService.restoreBackup();
                  if (restored && mounted) {
                    final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
                    await settingsProv.loadSettings();
                    final s = settingsProv.settings;
                    _nameController.text = s.cafeName;
                    _addressController.text = s.address;
                    _phoneController.text = s.phone;
                    _footerController.text = s.receiptFooter;
                    _taxController.text = s.taxPercent.toString();
                    _currencyController.text = s.currencySymbol;
                    _milkRatioController.text = s.milkCupsPerKg.toString();

                    if (mounted) {
                      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
                      Provider.of<ProductProvider>(context, listen: false).loadProducts();
                      Provider.of<StockProvider>(context, listen: false).loadStockData();
                      Provider.of<TableProvider>(context, listen: false).loadTableData();
                      Provider.of<WaiterProvider>(context, listen: false).loadWaiters();
                      Provider.of<ExpenseProvider>(context, listen: false).loadExpenses();
                      Provider.of<DashboardProvider>(context, listen: false).loadDashboardData();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Database (.db) imported and backed up into CafeFlow successfully! All system data updated.'),
                          backgroundColor: AppColors.accent,
                          duration: Duration(seconds: 6),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Database import failed: ${e.toString()}'), backgroundColor: AppColors.error),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(String label, Color color) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}