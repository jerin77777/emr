import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  Timer? _syncTimer;
  bool _isSyncing = false;
  String _syncStatus = 'Waiting for configuration...';
  DateTime? _lastBackupTime;
  
  // Callback for UI elements to listen to status changes
  VoidCallback? onStatusChanged;

  String get syncStatus => _syncStatus;
  bool get isSyncing => _isSyncing;
  DateTime? get lastBackupTime => _lastBackupTime;

  void startSyncLoop() {
    _syncTimer?.cancel();
    // Run sync cycle every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _runSyncCycle();
    });
    // Run immediately on start
    _runSyncCycle();
  }

  void stopSyncLoop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> triggerManualBackup() async {
    if (_isSyncing) return;
    _setSyncStatus('Syncing...');
    await _runSyncCycle(manual: true);
  }

  void _setSyncStatus(String status) {
    _syncStatus = status;
    onStatusChanged?.call();
  }

  Future<bool> checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _runSyncCycle({bool manual = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final projectId = await DatabaseHelper.instance.getSetting('firebase_project_id');
      final apiKey = await DatabaseHelper.instance.getSetting('firebase_api_key');
      final clinicId = await DatabaseHelper.instance.getSetting('clinic_id');

      if (projectId == null || apiKey == null || clinicId == null ||
          projectId.isEmpty || apiKey.isEmpty || clinicId.isEmpty) {
        _setSyncStatus('Last Backup: Never (Not Configured)');
        _isSyncing = false;
        return;
      }

      final isOnline = await checkInternet();
      if (!isOnline) {
        _setSyncStatus('Waiting for Internet...');
        _isSyncing = false;
        return;
      }

      _setSyncStatus('Syncing...');
      final db = await DatabaseHelper.instance.database;
      final httpClient = HttpClient();

      // 1. Sync Roles
      await _syncTable(db, httpClient, projectId, apiKey, clinicId, 'roles', (row) => row['id'].toString());

      // 2. Sync Users
      await _syncTable(db, httpClient, projectId, apiKey, clinicId, 'users', (row) => row['id'].toString());

      // 3. Sync Patients
      await _syncTable(db, httpClient, projectId, apiKey, clinicId, 'patients', (row) => row['id'].toString());

      // 4. Sync Patient Visits
      await _syncTable(db, httpClient, projectId, apiKey, clinicId, 'patient_visits', (row) => row['id'].toString());

      // 5. Sync Bills (with nested line items)
      await _syncBillsTable(db, httpClient, projectId, apiKey, clinicId);

      // 6. Sync Investigation Reports (with Firebase Storage bucket upload)
      await _syncInvestigationReportsTable(db, httpClient, projectId, apiKey, clinicId);

      httpClient.close();

      // Update backup metadata
      _lastBackupTime = DateTime.now();
      await DatabaseHelper.instance.saveSetting('last_backup_time', _lastBackupTime!.toIso8601String());
      _setSyncStatus(_formatLastBackupStatus(_lastBackupTime!));
    } catch (e) {
      debugPrint('Sync cycle failed: $e');
      if (manual) {
        _setSyncStatus('Backup Failed: $e');
      } else {
        // Silent retry fallback: update status based on last successful backup if available
        final lastBackupStr = await DatabaseHelper.instance.getSetting('last_backup_time');
        if (lastBackupStr != null) {
          final lastTime = DateTime.tryParse(lastBackupStr);
          if (lastTime != null) {
            _lastBackupTime = lastTime;
            _setSyncStatus(_formatLastBackupStatus(lastTime));
          } else {
            _setSyncStatus('Last Backup: Never');
          }
        } else {
          _setSyncStatus('Last Backup: Never');
        }
      }
    } finally {
      _isSyncing = false;
      onStatusChanged?.call();
    }
  }

  String _formatLastBackupStatus(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    String timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    if (diff.inDays == 0 && now.day == time.day) {
      return 'Last Backup: Today at $timeStr';
    } else if (diff.inDays <= 1 && now.day - time.day == 1) {
      return 'Last Backup: Yesterday at $timeStr';
    } else {
      return 'Last Backup: ${time.day}/${time.month}/${time.year} at $timeStr';
    }
  }

  Future<void> _syncTable(
    Database db,
    HttpClient httpClient,
    String projectId,
    String apiKey,
    String clinicId,
    String tableName,
    String Function(Map<String, dynamic> row) getDocId,
  ) async {
    final pendingRows = await db.query(tableName, where: "sync_status != 'synced' OR sync_status IS NULL", limit: 20);
    
    for (final row in pendingRows) {
      final docId = getDocId(row);
      final payload = Map<String, dynamic>.from(row);
      // Clean internal DB status fields not needed as primary data in cloud
      payload.remove('sync_status');

      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/${clinicId}_$tableName/$docId?key=$apiKey';
      final request = await httpClient.patchUrl(Uri.parse(url));
      request.headers.contentType = ContentType.json;
      request.write(json.encode(toFirestoreJson(payload)));
      
      final response = await request.close();
      if (response.statusCode == 200 || response.statusCode == 201) {
        await db.update(
          tableName,
          {
            'sync_status': 'synced',
            'last_synced_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } else {
        final body = await response.transform(utf8.decoder).join();
        debugPrint('Failed to sync $tableName doc $docId: ${response.statusCode} - $body');
        await db.update(
          tableName,
          {'sync_status': 'failed'},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        throw Exception('HTTP ${response.statusCode}: $body');
      }
    }
  }

  Future<void> _syncBillsTable(
    Database db,
    HttpClient httpClient,
    String projectId,
    String apiKey,
    String clinicId,
  ) async {
    final pendingBills = await db.query('bills', where: "sync_status != 'synced' OR sync_status IS NULL", limit: 10);

    for (final billRow in pendingBills) {
      final billId = billRow['id'];
      
      // Query items for this bill to bundle them
      final items = await db.query('bill_items', where: 'bill_id = ?', whereArgs: [billId]);
      
      final payload = Map<String, dynamic>.from(billRow);
      payload.remove('sync_status');
      payload['line_items'] = items.map((item) => {
        'item_description': item['item_description'],
        'amount': item['amount'],
      }).toList();

      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/${clinicId}_bills/$billId?key=$apiKey';
      final request = await httpClient.patchUrl(Uri.parse(url));
      request.headers.contentType = ContentType.json;
      request.write(json.encode(toFirestoreJson(payload)));

      final response = await request.close();
      if (response.statusCode == 200 || response.statusCode == 201) {
        await db.update(
          'bills',
          {
            'sync_status': 'synced',
            'last_synced_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [billId],
        );
      } else {
        final body = await response.transform(utf8.decoder).join();
        await db.update(
          'bills',
          {'sync_status': 'failed'},
          where: 'id = ?',
          whereArgs: [billId],
        );
        throw Exception('HTTP ${response.statusCode}: $body');
      }
    }
  }

  Future<void> _syncInvestigationReportsTable(
    Database db,
    HttpClient httpClient,
    String projectId,
    String apiKey,
    String clinicId,
  ) async {
    try {
      final pendingRows = await db.query('investigation_reports', where: "sync_status != 'synced' OR sync_status IS NULL", limit: 10);
      
      for (final row in pendingRows) {
        final docId = row['id'].toString();
        final payload = Map<String, dynamic>.from(row);
        payload.remove('sync_status');

        String? fileUrl = row['file_url'] as String?;
        final localFilePath = row['file_path'] as String?;

        if ((fileUrl == null || fileUrl.isEmpty) && localFilePath != null && localFilePath.isNotEmpty) {
          final localFile = File(localFilePath);
          if (await localFile.exists()) {
            final uuid = row['report_uuid'] ?? 'rep-${row['id']}';
            final fname = row['file_name'] ?? 'document';
            final remoteName = 'investigations/${uuid}_$fname';
            final uploadedUrl = await uploadFileToFirebaseBucket(
              file: localFile,
              projectId: projectId,
              apiKey: apiKey,
              remoteName: remoteName,
            );
            if (uploadedUrl != null) {
              fileUrl = uploadedUrl;
              payload['file_url'] = uploadedUrl;
              await db.update('investigation_reports', {'file_url': uploadedUrl}, where: 'id = ?', whereArgs: [row['id']]);
            }
          }
        }

        final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/${clinicId}_investigation_reports/$docId?key=$apiKey';
        final request = await httpClient.patchUrl(Uri.parse(url));
        request.headers.contentType = ContentType.json;
        request.write(json.encode(toFirestoreJson(payload)));
        
        final response = await request.close();
        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.update(
            'investigation_reports',
            {
              'sync_status': 'synced',
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to sync investigation reports: $e');
    }
  }

  Future<String?> uploadFileToFirebaseBucket({
    required File file,
    required String projectId,
    required String apiKey,
    required String remoteName,
  }) async {
    try {
      final encodedName = Uri.encodeComponent(remoteName);
      final url = 'https://firebasestorage.googleapis.com/v1/b/$projectId.appspot.com/o?name=$encodedName&key=$apiKey';
      final httpClient = HttpClient();
      final request = await httpClient.postUrl(Uri.parse(url));
      
      final ext = file.path.split('.').last.toLowerCase();
      if (ext == 'pdf') {
        request.headers.contentType = ContentType('application', 'pdf');
      } else if (ext == 'jpg' || ext == 'jpeg') {
        request.headers.contentType = ContentType('image', 'jpeg');
      } else if (ext == 'png') {
        request.headers.contentType = ContentType('image', 'png');
      } else {
        request.headers.contentType = ContentType('application', 'octet-stream');
      }

      final bytes = await file.readAsBytes();
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      httpClient.close();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonMap = json.decode(body) as Map<String, dynamic>;
        final downloadToken = jsonMap['downloadTokens'];
        if (downloadToken != null && downloadToken.toString().isNotEmpty) {
          return 'https://firebasestorage.googleapis.com/v1/b/$projectId.appspot.com/o/$encodedName?alt=media&token=$downloadToken';
        }
        return 'https://firebasestorage.googleapis.com/v1/b/$projectId.appspot.com/o/$encodedName?alt=media';
      }
    } catch (e) {
      debugPrint('Firebase Storage upload failed: $e');
    }
    return null;
  }

  // --- Disaster Recovery Restore Engine ---
  Future<void> restoreFromCloud({
    required String projectId,
    required String apiKey,
    required String clinicId,
    required Function(double progress, String message) onProgress,
  }) async {
    onProgress(0.0, 'Checking internet connectivity...');
    final isOnline = await checkInternet();
    if (!isOnline) {
      throw Exception('No internet connectivity. Please check your network and try again.');
    }

    final httpClient = HttpClient();
    final db = await DatabaseHelper.instance.database;

    // We disable foreign keys temporarily to allow bulk tables seeding without ordering blockages
    await db.execute('PRAGMA foreign_keys = OFF;');

    final tables = ['roles', 'users', 'patients', 'patient_visits', 'bills'];
    double stepSize = 1.0 / tables.length;

    try {
      for (int i = 0; i < tables.length; i++) {
        final tableName = tables[i];
        onProgress(i * stepSize, 'Downloading cloud records for $tableName...');

        List<Map<String, dynamic>> documents = [];
        String? nextPageToken;
        
        do {
          var url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/${clinicId}_$tableName?key=$apiKey';
          if (nextPageToken != null) {
            url += '&pageToken=$nextPageToken';
          }

          final request = await httpClient.getUrl(Uri.parse(url));
          final response = await request.close();

          if (response.statusCode != 200) {
            final errBody = await response.transform(utf8.decoder).join();
            throw Exception('Firestore fetch failed for $tableName: ${response.statusCode} - $errBody');
          }

          final bodyStr = await response.transform(utf8.decoder).join();
          final data = json.decode(bodyStr) as Map<String, dynamic>;

          if (data.containsKey('documents')) {
            final docsList = data['documents'] as List<dynamic>;
            for (final doc in docsList) {
              final parsed = fromFirestoreJson(doc as Map<String, dynamic>);
              documents.add(parsed);
            }
          }
          nextPageToken = data['nextPageToken'] as String?;
        } while (nextPageToken != null);

        onProgress((i * stepSize) + (stepSize * 0.5), 'Restoring $tableName into local database...');
        
        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final doc in documents) {
            // Check for conflict resolution: latest updated_at wins
            final localId = doc['id'];
            final cloudUpdatedAt = doc['updated_at'] ?? doc['created_at'] ?? doc['registration_date'] ?? '';

            final existing = await txn.query(tableName, where: 'id = ?', whereArgs: [localId]);
            
            if (existing.isEmpty) {
              // Extract line items if bills
              if (tableName == 'bills' && doc.containsKey('line_items')) {
                final lineItems = doc['line_items'] as List<dynamic>? ?? [];
                doc.remove('line_items');
                doc['sync_status'] = 'synced';
                batch.insert('bills', doc, conflictAlgorithm: ConflictAlgorithm.replace);
                
                // Clear existing items and insert new ones
                txn.delete('bill_items', where: 'bill_id = ?', whereArgs: [localId]);
                for (final item in lineItems) {
                  final mapItem = Map<String, dynamic>.from(item as Map);
                  mapItem['bill_id'] = localId;
                  txn.insert('bill_items', mapItem);
                }
              } else {
                doc['sync_status'] = 'synced';
                batch.insert(tableName, doc, conflictAlgorithm: ConflictAlgorithm.replace);
              }
            } else {
              // Record exists: check conflict resolution timestamp
              final localRow = existing.first;
              final localUpdatedAt = localRow['updated_at'] ?? localRow['created_at'] ?? localRow['registration_date'] ?? '';
              
              if (cloudUpdatedAt.compareTo(localUpdatedAt) >= 0) {
                if (tableName == 'bills' && doc.containsKey('line_items')) {
                  final lineItems = doc['line_items'] as List<dynamic>? ?? [];
                  doc.remove('line_items');
                  doc['sync_status'] = 'synced';
                  batch.update('bills', doc, where: 'id = ?', whereArgs: [localId]);
                  
                  txn.delete('bill_items', where: 'bill_id = ?', whereArgs: [localId]);
                  for (final item in lineItems) {
                    final mapItem = Map<String, dynamic>.from(item as Map);
                    mapItem['bill_id'] = localId;
                    txn.insert('bill_items', mapItem);
                  }
                } else {
                  doc['sync_status'] = 'synced';
                  batch.update(tableName, doc, where: 'id = ?', whereArgs: [localId]);
                }
              }
            }
          }
          await batch.commit(noResult: true);
        });
      }

      onProgress(1.0, 'Restoration complete! Rebuilding database indexes...');
      await DatabaseHelper.instance.saveSetting('firebase_project_id', projectId);
      await DatabaseHelper.instance.saveSetting('firebase_api_key', apiKey);
      await DatabaseHelper.instance.saveSetting('clinic_id', clinicId);
      await DatabaseHelper.instance.saveSetting('last_backup_time', DateTime.now().toIso8601String());
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
      httpClient.close();
    }
  }

  Future<String> testConnection({
    required String projectId,
    required String apiKey,
    required String clinicId,
  }) async {
    final isOnline = await checkInternet();
    if (!isOnline) {
      return 'Offline: No internet connectivity.';
    }

    final httpClient = HttpClient();
    try {
      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/test_connection?key=$apiKey&pageSize=1';
      final request = await httpClient.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 8));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        return 'Connected: Credentials verified successfully.';
      } else {
        final body = await response.transform(utf8.decoder).join();
        try {
          final errJson = json.decode(body);
          final msg = errJson['error']['message'] ?? body;
          return 'Connection Failed: HTTP ${response.statusCode} - $msg';
        } catch (_) {
          return 'Connection Failed: HTTP ${response.statusCode} - $body';
        }
      }
    } catch (e) {
      return 'Connection Failed: $e';
    } finally {
      httpClient.close();
    }
  }

  // --- Firestore Payload Mappers (REST JSON Spec) ---
  Map<String, dynamic> toFirestoreJson(Map<String, dynamic> map) {
    final fields = <String, dynamic>{};
    map.forEach((key, val) {
      if (val == null) {
        fields[key] = {'nullValue': null};
      } else if (val is int) {
        fields[key] = {'integerValue': val.toString()};
      } else if (val is double) {
        fields[key] = {'doubleValue': val};
      } else if (val is bool) {
        fields[key] = {'booleanValue': val};
      } else if (val is List) {
        fields[key] = {
          'arrayValue': {
            'values': val.map((item) => {'mapValue': toFirestoreJson(Map<String, dynamic>.from(item as Map))}).toList()
          }
        };
      } else if (val is Map) {
        fields[key] = {'mapValue': toFirestoreJson(Map<String, dynamic>.from(val))};
      } else {
        fields[key] = {'stringValue': val.toString()};
      }
    });
    return {'fields': fields};
  }

  Map<String, dynamic> fromFirestoreJson(Map<String, dynamic> firestoreDoc) {
    final fields = firestoreDoc['fields'] as Map<String, dynamic>? ?? {};
    final result = <String, dynamic>{};
    
    fields.forEach((key, val) {
      result[key] = _parseFirestoreValue(val as Map<String, dynamic>);
    });

    // Extract the final document segment name as ID if not in fields
    if (!result.containsKey('id') && firestoreDoc.containsKey('name')) {
      final name = firestoreDoc['name'] as String;
      final docName = name.split('/').last;
      result['id'] = int.tryParse(docName);
    }
    return result;
  }

  dynamic _parseFirestoreValue(Map<String, dynamic> valMap) {
    if (valMap.containsKey('stringValue')) {
      return valMap['stringValue'];
    } else if (valMap.containsKey('integerValue')) {
      return int.tryParse(valMap['integerValue'].toString());
    } else if (valMap.containsKey('doubleValue')) {
      return (valMap['doubleValue'] as num).toDouble();
    } else if (valMap.containsKey('booleanValue')) {
      return valMap['booleanValue'] as bool;
    } else if (valMap.containsKey('nullValue')) {
      return null;
    } else if (valMap.containsKey('arrayValue')) {
      final values = (valMap['arrayValue'] as Map)['values'] as List<dynamic>? ?? [];
      return values.map((v) => _parseFirestoreValue(v as Map<String, dynamic>)).toList();
    } else if (valMap.containsKey('mapValue')) {
      final fields = (valMap['mapValue'] as Map)['fields'] as Map<String, dynamic>? ?? {};
      final mapResult = <String, dynamic>{};
      fields.forEach((k, v) {
        mapResult[k] = _parseFirestoreValue(v as Map<String, dynamic>);
      });
      return mapResult;
    } else {
      return valMap.values.isNotEmpty ? valMap.values.first : null;
    }
  }
}
