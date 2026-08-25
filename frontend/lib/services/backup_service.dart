import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database_helper.dart';

class BackupMetadata {
  final int backupFormatVersion;
  final int databaseSchemaVersion;
  final String applicationVersion;
  final String backupTimestamp;
  final String clinicIdentifier;
  final int patientCount;
  final int visitCount;
  final int billCount;
  final int documentCount;

  const BackupMetadata({
    required this.backupFormatVersion,
    required this.databaseSchemaVersion,
    required this.applicationVersion,
    required this.backupTimestamp,
    required this.clinicIdentifier,
    required this.patientCount,
    required this.visitCount,
    required this.billCount,
    required this.documentCount,
  });

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      backupFormatVersion: json['backup_format_version'] as int? ?? 1,
      databaseSchemaVersion: json['database_schema_version'] as int? ?? 1,
      applicationVersion: json['application_version'] as String? ?? '1.0.0',
      backupTimestamp: json['backup_timestamp'] as String? ?? '',
      clinicIdentifier: json['clinic_identifier'] as String? ?? 'Unknown Clinic',
      patientCount: json['patient_count'] as int? ?? 0,
      visitCount: json['visit_count'] as int? ?? 0,
      billCount: json['bill_count'] as int? ?? 0,
      documentCount: json['document_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backup_format_version': backupFormatVersion,
      'database_schema_version': databaseSchemaVersion,
      'application_version': applicationVersion,
      'backup_timestamp': backupTimestamp,
      'clinic_identifier': clinicIdentifier,
      'patient_count': patientCount,
      'visit_count': visitCount,
      'bill_count': billCount,
      'document_count': documentCount,
    };
  }
}

class BackupService {
  static final BackupService instance = BackupService._internal();
  BackupService._internal();

  // Create an atomic local backup
  Future<String> createLocalBackup(String destParentPath) async {
    final appDir = await DatabaseHelper.getAppDirectoryPath();
    final dbFile = File(join(appDir, 'emr.db'));
    final docsDir = Directory(join(appDir, 'ClinicData', 'documents'));
    final usersDir = Directory(join(appDir, 'ClinicData', 'users'));
    final reportsDir = Directory(join(appDir, 'investigation_reports'));

    // Check if database exists
    if (!await dbFile.exists()) {
      throw Exception('Active database emr.db not found on disk.');
    }

    // Flush any pending WAL pages / transactions to disk before copying
    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final backupFolderName = 'EMR_Backup_${timestamp.split('T')[0]}_${DateTime.now().hour.toString().padLeft(2, '0')}${DateTime.now().minute.toString().padLeft(2, '0')}';
    final tempDirPath = join(destParentPath, 'EMR_Backup_TEMP');
    final tempDir = Directory(tempDirPath);

    // 1. Delete previous temp backup if any
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }

    // 2. Create structure
    await tempDir.create(recursive: true);
    final tempDbDir = Directory(join(tempDirPath, 'database'));
    final tempDocsDir = Directory(join(tempDirPath, 'documents'));
    final tempUsersDir = Directory(join(tempDirPath, 'users'));
    final tempReportsDir = Directory(join(tempDirPath, 'investigation_reports'));
    await tempDbDir.create();
    await tempDocsDir.create();
    await tempUsersDir.create();

    try {
      // 3. Copy database
      final backupDbPath = join(tempDbDir.path, 'emr.db');
      await dbFile.copy(backupDbPath);

      // 4. Copy documents recursively
      if (await docsDir.exists()) {
        await _copyDirectory(docsDir, tempDocsDir);
      }

      // Copy users (signatures) recursively
      if (await usersDir.exists()) {
        await _copyDirectory(usersDir, tempUsersDir);
      }

      // Copy investigation reports recursively if present
      if (await reportsDir.exists()) {
        await tempReportsDir.create();
        await _copyDirectory(reportsDir, tempReportsDir);
      }

      // 5. Open backup database to count records and verify integrity
      final tempDb = await openDatabase(backupDbPath);
      final integrity = await tempDb.rawQuery('PRAGMA integrity_check;');
      if (integrity.isEmpty || integrity.first['integrity_check'] != 'ok') {
        await tempDb.close();
        throw Exception('Database integrity check failed for backup.');
      }

      // Query counts
      final patientsRes = await tempDb.rawQuery('SELECT COUNT(*) as count FROM patients');
      final visitsRes = await tempDb.rawQuery('SELECT COUNT(*) as count FROM patient_visits');
      final billsRes = await tempDb.rawQuery('SELECT COUNT(*) as count FROM bills');
      final docsRes = await tempDb.rawQuery('SELECT COUNT(*) as count FROM investigation_reports');
      
      final patientCount = (patientsRes.first['count'] as num?)?.toInt() ?? 0;
      final visitCount = (visitsRes.first['count'] as num?)?.toInt() ?? 0;
      final billCount = (billsRes.first['count'] as num?)?.toInt() ?? 0;
      final documentCount = (docsRes.first['count'] as num?)?.toInt() ?? 0;

      // Query clinic name setting
      final settingsRes = await tempDb.rawQuery("SELECT value FROM settings WHERE key = 'clinic_name'");
      final clinicName = settingsRes.isNotEmpty ? settingsRes.first['value'] as String? ?? 'Neuron - The Clinic' : 'Neuron - The Clinic';

      await tempDb.close();

      // 6. Write manifest.json
      final manifestFile = File(join(tempDirPath, 'manifest.json'));
      final metadata = BackupMetadata(
        backupFormatVersion: 1,
        databaseSchemaVersion: 1,
        applicationVersion: '4.0.0',
        backupTimestamp: DateTime.now().toIso8601String(),
        clinicIdentifier: clinicName,
        patientCount: patientCount,
        visitCount: visitCount,
        billCount: billCount,
        documentCount: documentCount,
      );

      await manifestFile.writeAsString(json.encode(metadata.toJson()));

      // 7. Atomically rename folder
      final finalDestPath = join(destParentPath, backupFolderName);
      final finalDestDir = Directory(finalDestPath);
      if (await finalDestDir.exists()) {
        await finalDestDir.delete(recursive: true);
      }
      await tempDir.rename(finalDestPath);

      return finalDestPath;
    } catch (e) {
      // Clean up temp
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      throw Exception('Backup failed: $e');
    }
  }

  // Validate backup format and return metadata
  Future<BackupMetadata> validateBackup(String backupPath) async {
    final manifestFile = File(join(backupPath, 'manifest.json'));
    final dbFile = File(join(backupPath, 'database', 'emr.db'));

    if (!await manifestFile.exists()) {
      throw Exception('Invalid backup: manifest.json is missing.');
    }
    if (!await dbFile.exists()) {
      throw Exception('Invalid backup: database/emr.db is missing.');
    }

    try {
      // 1. Read manifest
      final content = await manifestFile.readAsString();
      final decoded = json.decode(content);
      final metadata = BackupMetadata.fromJson(decoded);

      // 2. Verify restored database connection integrity
      final tempDb = await openDatabase(dbFile.path);
      final integrity = await tempDb.rawQuery('PRAGMA integrity_check;');
      await tempDb.close();

      if (integrity.isEmpty || integrity.first['integrity_check'] != 'ok') {
        throw Exception('Backup database is corrupted (Integrity check failed).');
      }

      return metadata;
    } catch (e) {
      throw Exception('Validation failed: $e');
    }
  }

  // Restore from local backup with safety snapshots and rolls
  Future<void> restoreLocalBackup(String backupPath) async {
    final appDir = await DatabaseHelper.getAppDirectoryPath();
    final activeDbFile = File(join(appDir, 'emr.db'));
    final activeDocsDir = Directory(join(appDir, 'ClinicData', 'documents'));
    final activeUsersDir = Directory(join(appDir, 'ClinicData', 'users'));
    final activeReportsDir = Directory(join(appDir, 'investigation_reports'));

    final backupDbFile = File(join(backupPath, 'database', 'emr.db'));
    final backupDocsDir = Directory(join(backupPath, 'documents'));
    final backupUsersDir = Directory(join(backupPath, 'users'));
    final backupReportsDir = Directory(join(backupPath, 'investigation_reports'));

    // Validate first
    await validateBackup(backupPath);

    // 1. Create PreRestore Safety Backup Folder
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final safetyBackupPath = join(appDir, 'PreRestore_Backup_${timestamp.split('T')[0]}_${DateTime.now().hour.toString().padLeft(2, '0')}${DateTime.now().minute.toString().padLeft(2, '0')}');
    final safetyDir = Directory(safetyBackupPath);
    await safetyDir.create(recursive: true);

    final safetyDbDir = Directory(join(safetyBackupPath, 'database'));
    final safetyDocsDir = Directory(join(safetyBackupPath, 'documents'));
    final safetyUsersDir = Directory(join(safetyBackupPath, 'users'));
    final safetyReportsDir = Directory(join(safetyBackupPath, 'investigation_reports'));
    await safetyDbDir.create();
    await safetyDocsDir.create();
    await safetyUsersDir.create();

    try {
      if (await activeDbFile.exists()) {
        await activeDbFile.copy(join(safetyDbDir.path, 'emr.db'));
      }
      if (await activeDocsDir.exists()) {
        await _copyDirectory(activeDocsDir, safetyDocsDir);
      }
      if (await activeUsersDir.exists()) {
        await _copyDirectory(activeUsersDir, safetyUsersDir);
      }
      if (await activeReportsDir.exists()) {
        await safetyReportsDir.create();
        await _copyDirectory(activeReportsDir, safetyReportsDir);
      }
    } catch (e) {
      throw Exception('Failed to create safety backup: $e. Restore aborted.');
    }

    // 2. Perform Restore Transactionally
    try {
      // Close active database connections
      await DatabaseHelper.instance.closeDatabase();

      // Delete active database and documents and user signatures
      if (await activeDbFile.exists()) {
        await activeDbFile.delete();
      }
      if (await activeDocsDir.exists()) {
        await activeDocsDir.delete(recursive: true);
      }
      if (await activeUsersDir.exists()) {
        await activeUsersDir.delete(recursive: true);
      }
      if (await activeReportsDir.exists()) {
        await activeReportsDir.delete(recursive: true);
      }

      // Copy database from backup to active
      await backupDbFile.copy(activeDbFile.path);

      // Copy documents from backup to active
      if (await backupDocsDir.exists()) {
        await activeDocsDir.create(recursive: true);
        await _copyDirectory(backupDocsDir, activeDocsDir);
      }

      // Copy users (signatures) from backup to active
      if (await backupUsersDir.exists()) {
        await activeUsersDir.create(recursive: true);
        await _copyDirectory(backupUsersDir, activeUsersDir);
      }

      // Copy investigation reports from backup to active if present
      if (await backupReportsDir.exists()) {
        await activeReportsDir.create(recursive: true);
        await _copyDirectory(backupReportsDir, activeReportsDir);
      }

      // Reopen database and verify
      await DatabaseHelper.instance.reopenDatabase();

      // Notify all UI listeners to refresh data
      DatabaseHelper.notifyDatabaseChanged();

      // Cleanup safety backup on absolute success
      if (await safetyDir.exists()) {
        await safetyDir.delete(recursive: true);
      }
    } catch (e) {
      // ROLLBACK: Revert to safety backup
      debugPrint('Restore failed! Rolling back from safety backup... Error: $e');
      try {
        await DatabaseHelper.instance.closeDatabase();
        
        if (await activeDbFile.exists()) {
          await activeDbFile.delete();
        }
        if (await activeDocsDir.exists()) {
          await activeDocsDir.delete(recursive: true);
        }
        if (await activeUsersDir.exists()) {
          await activeUsersDir.delete(recursive: true);
        }
        if (await activeReportsDir.exists()) {
          await activeReportsDir.delete(recursive: true);
        }

        final safetyDbFile = File(join(safetyDbDir.path, 'emr.db'));
        if (await safetyDbFile.exists()) {
          await safetyDbFile.copy(activeDbFile.path);
        }
        if (await safetyDocsDir.exists()) {
          await activeDocsDir.create(recursive: true);
          await _copyDirectory(safetyDocsDir, activeDocsDir);
        }
        if (await safetyUsersDir.exists()) {
          await activeUsersDir.create(recursive: true);
          await _copyDirectory(safetyUsersDir, activeUsersDir);
        }
        if (await safetyReportsDir.exists()) {
          await activeReportsDir.create(recursive: true);
          await _copyDirectory(safetyReportsDir, activeReportsDir);
        }

        await DatabaseHelper.instance.reopenDatabase();
        DatabaseHelper.notifyDatabaseChanged();
      } catch (rollbackErr) {
        debugPrint('CRITICAL: Rollback failed! EMR state may be corrupted: $rollbackErr');
      }

      throw Exception('Restoration failed. Rolled back to previous state. Error: $e');
    }
  }

  // Recursive directory copier helper
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (var entity in source.list(recursive: true)) {
      if (entity is File) {
        final rel = relative(entity.path, from: source.path);
        final newPath = join(destination.path, rel);
        final newFile = File(newPath);
        await newFile.parent.create(recursive: true);
        await entity.copy(newFile.path);
      }
    }
  }
}
