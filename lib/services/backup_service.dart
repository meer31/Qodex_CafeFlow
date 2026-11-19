import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class BackupService {
  static final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Creates a backup of the database file to a user-selected directory.
  /// Returns the backup file path on success, or null on cancel/failure.
  static Future<String?> createBackup() async {
    try {
      final dbPath = await _dbHelper.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('Database file not found at: $dbPath');
      }

      // Let user pick a directory to save the backup
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Backup Destination Folder',
      );

      if (selectedDirectory == null) {
        return null; // User cancelled
      }

      // Create backup filename with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      final backupFileName = 'CafeFlow_Backup_$timestamp.db';
      final backupPath = '$selectedDirectory${Platform.pathSeparator}$backupFileName';

      // Copy database file to backup location
      await dbFile.copy(backupPath);

      return backupPath;
    } catch (e) {
      throw Exception('Backup failed: ${e.toString()}');
    }
  }

  /// Restores the database from a user-selected .db backup file.
  /// Returns true on success, false on cancel.
  static Future<bool> restoreBackup() async {
    try {
      // Let user pick a .db file
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select CafeFlow Backup File (.db)',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result == null || result.files.isEmpty) {
        return false; // User cancelled
      }

      final selectedFilePath = result.files.single.path;
      if (selectedFilePath == null) {
        return false;
      }

      final backupFile = File(selectedFilePath);
      if (!await backupFile.exists()) {
        throw Exception('Selected backup file does not exist.');
      }

      // Get current database path
      final dbPath = await _dbHelper.getDatabasePath();

      // Close the current database connection
      await _dbHelper.close();

      // Replace the current database with the backup
      await backupFile.copy(dbPath);

      // Restart database connection
      await _dbHelper.restartDatabase();

      return true;
    } catch (e) {
      // Try to restart database even on failure
      try {
        await _dbHelper.restartDatabase();
      } catch (_) {}
      throw Exception('Restore failed: ${e.toString()}');
    }
  }
}
