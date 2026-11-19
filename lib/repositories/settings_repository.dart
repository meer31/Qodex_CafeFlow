import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/app_settings_model.dart';

class SettingsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<AppSettingsModel> getSettings() async {
    final db = await _dbHelper.database;
    final maps = await db.query('settings');
    final Map<String, String> resultMap = {};
    for (var m in maps) {
      resultMap[m['key'] as String] = m['value'] as String;
    }
    return AppSettingsModel.fromMap(resultMap);
  }

  Future<void> saveSettings(AppSettingsModel settings) async {
    final db = await _dbHelper.database;
    final map = settings.toMap();
    final batch = db.batch();

    for (var entry in map.entries) {
      batch.insert(
        'settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }
}
