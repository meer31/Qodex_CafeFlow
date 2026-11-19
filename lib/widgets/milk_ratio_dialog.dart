import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/milk_conversion_service.dart';

class MilkRatioDialog extends StatefulWidget {
  const MilkRatioDialog({super.key});

  @override
  State<MilkRatioDialog> createState() => _MilkRatioDialogState();
}

class _MilkRatioDialogState extends State<MilkRatioDialog> {
  late TextEditingController _ratioController;
  double _currentRatio = 5.0;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    _currentRatio = settings.milkCupsPerKg;
    _ratioController = TextEditingController(text: _currentRatio.toString());
  }

  @override
  void dispose() {
    _ratioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    // Live Calculation Simulation
    final double fullDeductionKg = MilkConversionService.calculateMilkDeductionKg(
      milkCupsPerKg: _currentRatio,
      teaTypeRatioKey: 'Full Tea',
    );
    final double halfDeductionKg = MilkConversionService.calculateMilkDeductionKg(
      milkCupsPerKg: _currentRatio,
      teaTypeRatioKey: 'Half Tea',
    );
    final double largeDeductionKg = MilkConversionService.calculateMilkDeductionKg(
      milkCupsPerKg: _currentRatio,
      teaTypeRatioKey: 'Large Tea',
    );
    final double specialDeductionKg = MilkConversionService.calculateMilkDeductionKg(
      milkCupsPerKg: _currentRatio,
      teaTypeRatioKey: 'Special Tea',
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.local_cafe_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Special Milk Conversion Engine',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Configure dynamic milk deduction ratio',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'Base Conversion Setting (1 KG Milk = N Full Cups)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ratioController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'e.g. 5 or 6',
                      suffixText: 'Full Cups / KG',
                    ),
                    onChanged: (val) {
                      final double? parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setState(() {
                          _currentRatio = parsed;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Simulation Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE SIMULATED DEDUCTION PER CUP:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSimRow('Full Tea (100% dose)', fullDeductionKg),
                  const SizedBox(height: 6),
                  _buildSimRow('Half Tea (50% dose)', halfDeductionKg),
                  const SizedBox(height: 6),
                  _buildSimRow('Large Tea (125% dose)', largeDeductionKg),
                  const SizedBox(height: 6),
                  _buildSimRow('Special Tea (150% dose)', specialDeductionKg),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Save Settings'),
                  onPressed: () async {
                    if (_currentRatio <= 0) return;
                    await settingsProvider.updateMilkRatio(_currentRatio);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Milk conversion updated: 1 KG Milk = $_currentRatio Full Cups'),
                          backgroundColor: AppColors.accent,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimRow(String title, double kgVal) {
    final double mlVal = MilkConversionService.convertKgToMl(kgVal);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        Text(
          '${kgVal.toStringAsFixed(3)} KG (${mlVal.toStringAsFixed(0)} ml)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
        ),
      ],
    );
  }
}