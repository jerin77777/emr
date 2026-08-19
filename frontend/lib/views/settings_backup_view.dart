import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../services/sync_service.dart';
import '../services/backup_service.dart';
import '../utils/date_formatter.dart';
import '../main.dart';

class SettingsBackupView extends StatefulWidget {
  final User currentUser;
  const SettingsBackupView({super.key, required this.currentUser});

  @override
  State<SettingsBackupView> createState() => _SettingsBackupViewState();
}

class _SettingsBackupViewState extends State<SettingsBackupView> {
  final _formKey = GlobalKey<FormState>();
  final _projectController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _clinicController = TextEditingController();

  final _restoreProjectController = TextEditingController();
  final _restoreApiKeyController = TextEditingController();
  final _restoreClinicController = TextEditingController();

  bool _isSavingSettings = false;
  bool _isRestoring = false;
  double _restoreProgress = 0.0;
  String _restoreStatusMessage = '';
  String _connectionTestStatus = '';
  bool _isTestingConnection = false;

  String _lastLocalBackupTime = 'Never';
  String _lastLocalBackupPath = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLocalBackupSettings();
    SyncService.instance.onStatusChanged = _updateStatus;
  }

  @override
  void dispose() {
    SyncService.instance.onStatusChanged = null;
    _projectController.dispose();
    _apiKeyController.dispose();
    _clinicController.dispose();
    _restoreProjectController.dispose();
    _restoreApiKeyController.dispose();
    _restoreClinicController.dispose();
    super.dispose();
  }

  void _updateStatus() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    final proj = await DatabaseHelper.instance.getSetting('firebase_project_id');
    final key = await DatabaseHelper.instance.getSetting('firebase_api_key');
    final clinic = await DatabaseHelper.instance.getSetting('clinic_id');

    setState(() {
      _projectController.text = proj ?? '';
      _apiKeyController.text = key ?? '';
      _clinicController.text = clinic ?? '';
    });
  }

  Future<void> _loadLocalBackupSettings() async {
    final timeVal = await DatabaseHelper.instance.getSetting('last_local_backup_time');
    final pathVal = await DatabaseHelper.instance.getSetting('last_local_backup_path');
    setState(() {
      if (timeVal != null) {
        _lastLocalBackupTime = '${DateFormatter.formatDate(timeVal)} ${timeVal.split('T')[1].substring(0, 5)}';
      } else {
        _lastLocalBackupTime = 'Never';
      }
      _lastLocalBackupPath = pathVal ?? '';
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSavingSettings = true);
    try {
      final projectId = _projectController.text.trim();
      final apiKey = _apiKeyController.text.trim();
      final clinicId = _clinicController.text.trim();

      // Always persist entered settings first
      await DatabaseHelper.instance.saveSetting('firebase_project_id', projectId);
      await DatabaseHelper.instance.saveSetting('firebase_api_key', apiKey);
      await DatabaseHelper.instance.saveSetting('clinic_id', clinicId);

      // Verify connection with Firebase
      final testResult = await SyncService.instance.testConnection(
        projectId: projectId,
        apiKey: apiKey,
        clinicId: clinicId,
      );

      setState(() {
        _connectionTestStatus = testResult;
      });

      if (!testResult.startsWith('Connected')) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Settings saved, but connection failed:\n$testResult'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        if (testResult.contains('Note:') || testResult.contains('Warning')) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(testResult),
              backgroundColor: Colors.amber.shade900,
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () => messenger.hideCurrentSnackBar(),
              ),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Firebase settings saved & verified! Starting backup...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
      final backupError = await SyncService.instance.triggerManualBackup();
      if (backupError != null && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Backup notice: $backupError'),
            backgroundColor: backupError.contains('warning') || backupError.contains('notice')
                ? Colors.amber.shade900
                : Colors.red.shade700,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () => messenger.hideCurrentSnackBar(),
            ),
          ),
        );
      }
    } catch (e) {
      final cleanError = SyncService.extractErrorMessage(e);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $cleanError'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingSettings = false);
      }
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isTestingConnection = true;
      _connectionTestStatus = 'Testing connection...';
    });
    
    final result = await SyncService.instance.testConnection(
      projectId: _projectController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      clinicId: _clinicController.text.trim(),
    );

    setState(() {
      _isTestingConnection = false;
      _connectionTestStatus = result;
    });

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      if (result.contains('Note:') || result.contains('Warning')) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: Colors.amber.shade900,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () => messenger.hideCurrentSnackBar(),
            ),
          ),
        );
      } else if (result.startsWith('Connected')) {
        messenger.showSnackBar(
          SnackBar(content: Text(result), backgroundColor: Colors.green),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () => messenger.hideCurrentSnackBar(),
            ),
          ),
        );
      }
    }
  }

  // --- Local Backup Action ---
  Future<void> _createLocalBackup() async {
    try {
      final selectedPath = await FilePicker.getDirectoryPath();
      if (selectedPath == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final finalPath = await BackupService.instance.createLocalBackup(selectedPath);
      
      final nowStr = DateTime.now().toIso8601String();
      await DatabaseHelper.instance.saveSetting('last_local_backup_time', nowStr);
      await DatabaseHelper.instance.saveSetting('last_local_backup_path', finalPath);

      if (mounted) {
        Navigator.pop(context); // close loader
        _loadLocalBackupSettings();
        
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text('Backup Completed'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backup completed successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Time: ${DateFormatter.formatDate(nowStr)} ${DateTime.now().hour.toString().padLeft(2, "0")}:${DateTime.now().minute.toString().padLeft(2, "0")}'),
                  const SizedBox(height: 6),
                  Text('Location: $finalPath', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                  child: const Text('Continue'),
                )
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Backup Failed'),
              ],
            ),
            content: Text('Backup failed\nReason: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    }
  }

  // --- Local Restore Action ---
  Future<void> _restoreLocalBackup() async {
    try {
      final selectedPath = await FilePicker.getDirectoryPath();
      if (selectedPath == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final metadata = await BackupService.instance.validateBackup(selectedPath);
      
      if (mounted) {
        Navigator.pop(context); // close loader
      }

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Restore Backup'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Are you sure you want to restore this backup? Current clinic data will be replaced.', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Text('Clinic Name: ${metadata.clinicIdentifier}'),
                  const SizedBox(height: 6),
                  Text('Backup Date: ${DateFormatter.formatDate(metadata.backupTimestamp.split("T")[0])}'),
                  const SizedBox(height: 6),
                  Text('Patients: ${metadata.patientCount}'),
                  const SizedBox(height: 6),
                  Text('Consultations: ${metadata.visitCount}'),
                  const SizedBox(height: 6),
                  Text('Bills: ${metadata.billCount}'),
                  const SizedBox(height: 6),
                  Text('Documents: ${metadata.documentCount}'),
                  const SizedBox(height: 6),
                  Text('Application Version: ${metadata.applicationVersion}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  const Text('Note: A safety backup will be created automatically before restoration.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blue)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Restore'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await BackupService.instance.restoreLocalBackup(selectedPath);

      if (mounted) {
        Navigator.pop(context); // close loader
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Restore Successful'),
              ],
            ),
            content: const Text('The clinic database and documents have been successfully restored. The application will now reload to activate the restored database.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Restore Failed'),
              ],
            ),
            content: Text('Restoration failed\nReason: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _runCloudRestore() {
    final proj = _restoreProjectController.text.trim();
    final key = _restoreApiKeyController.text.trim();
    final clinic = _restoreClinicController.text.trim();

    if (proj.isEmpty || key.isEmpty || clinic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all credentials to restore.'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!_isRestoring) {
              _isRestoring = true;
              _restoreProgress = 0.0;
              _restoreStatusMessage = 'Initializing cloud restore connection...';

              SyncService.instance.restoreFromCloud(
                projectId: proj,
                apiKey: key,
                clinicId: clinic,
                onProgress: (progress, message) {
                  setDialogState(() {
                    _restoreProgress = progress;
                    _restoreStatusMessage = message;
                  });
                },
              ).then((_) {
                if (!context.mounted) return;
                setDialogState(() {
                  _isRestoring = false;
                });
                Navigator.pop(context); // Close progress dialog
                _showRestoreSuccess();
              }).catchError((err) {
                if (!context.mounted) return;
                setDialogState(() {
                  _isRestoring = false;
                });
                Navigator.pop(context); // Close progress dialog
                _showRestoreError(err.toString());
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Restoring Clinic Data'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    CircularProgressIndicator(value: _restoreProgress),
                    const SizedBox(height: 24),
                    Text(
                      _restoreStatusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _restoreProgress),
                    const SizedBox(height: 12),
                    Text('${(_restoreProgress * 100).toStringAsFixed(0)}% Complete', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        _isRestoring = false;
      });
    });
  }

  void _showRestoreSuccess() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Restore Successful'),
            ],
          ),
          content: const Text(
            'All clinical records, patients, consultations, bills, roles, and doctor profiles have been successfully restored and verified from the cloud. The local database index has been rebuilt.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _restoreProjectController.clear();
                _restoreApiKeyController.clear();
                _restoreClinicController.clear();
                _loadSettings();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              child: const Text('Continue'),
            )
          ],
        );
      },
    );
  }

  void _showRestoreError(String error) {
    final cleanError = SyncService.extractErrorMessage(error);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Restore Failed'),
            ],
          ),
          content: Text('An error occurred during restoration:\n\n$cleanError'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              child: const Text('Dismiss'),
            )
          ],
        );
      },
    );
  }

  void _confirmRestore() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Cloud Restoration'),
          content: const Text(
            'WARNING: Restoring data from the cloud will merge or overwrite your current local records based on the conflict resolution timestamps. This action is irreversible. Are you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close confirm dialog
                _runCloudRestore();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Proceed with Restore'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleResetDatabaseDialog() async {
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isValid = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Text('Destructive Action!'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WARNING: This will permanently delete all clinical records, patients, visits, bills, audit logs, and uploaded documents from this device.',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Before resetting the database, create a backup to protect your clinic data.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This action cannot be undone. To confirm, please type RESET in the box below:',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmController,
                        decoration: const InputDecoration(
                          labelText: 'Confirmation Word',
                          hintText: 'RESET',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val != 'RESET' ? 'Please type RESET to confirm' : null,
                        onChanged: (val) {
                          setStateDialog(() {
                            isValid = val == 'RESET';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context, false);
                    _createLocalBackup();
                  },
                  child: const Text('Backup & Reset', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context, true);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reset Anyway'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await DatabaseHelper.instance.resetAndSeedDatabase();
      if (mounted) {
        navigator.pop(); // close spinner
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Database reset and seeded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        navigator.pop(); // close spinner
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error resetting database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = SyncService.instance.syncStatus;
    final isSyncing = SyncService.instance.isSyncing;

    IconData statusIcon = Icons.cloud_done;
    Color statusColor = Colors.green;
    if (status.contains('Waiting for Internet')) {
      statusIcon = Icons.cloud_off;
      statusColor = Colors.orange;
    } else if (status.contains('Syncing')) {
      statusIcon = Icons.sync;
      statusColor = Colors.teal;
    } else if (status.contains('Never')) {
      statusIcon = Icons.cloud_upload;
      statusColor = Colors.grey;
    } else if (status.contains('Failed')) {
      statusIcon = Icons.error;
      statusColor = Colors.red;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Sync status & config
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // WhatsApp Style Backup Status Panel
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Database Cloud Backup Status',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      status,
                                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSyncing)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final err = await SyncService.instance.triggerManualBackup();
                                    if (!mounted) return;
                                    messenger.hideCurrentSnackBar();
                                    if (err != null) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Backup Failed: $err'),
                                          backgroundColor: Colors.red.shade700,
                                          duration: const Duration(seconds: 8),
                                          action: SnackBarAction(
                                            label: 'Dismiss',
                                            textColor: Colors.white,
                                            onPressed: () => messenger.hideCurrentSnackBar(),
                                          ),
                                        ),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Backup completed successfully!'),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.backup),
                                  label: const Text('Backup to Cloud Now'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Your clinical database changes are queued and backed up incrementally to secure cloud vaults in the background. It functions entirely offline and syncs automatically when internet becomes available.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Firebase Configuration Form
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Firebase Cloud Settings',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.teal.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Configure cloud credentials to secure backups and enable disaster recovery restoration. Data is encrypted end-to-end.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const Divider(height: 24),

                            TextFormField(
                              controller: _projectController,
                              decoration: const InputDecoration(
                                labelText: 'Firebase Project ID',
                                border: OutlineInputBorder(),
                                hintText: 'e.g. my-clinic-emr-project',
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Project ID is required' : null,
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _apiKeyController,
                              decoration: const InputDecoration(
                                labelText: 'Firebase Web API Key',
                                border: OutlineInputBorder(),
                                hintText: 'AIzaSy...',
                              ),
                              obscureText: true,
                              validator: (v) => v == null || v.isEmpty ? 'API Key is required' : null,
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _clinicController,
                              decoration: const InputDecoration(
                                labelText: 'Clinic Namespace Identifier',
                                border: OutlineInputBorder(),
                                hintText: 'e.g. clinic-branch-1',
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Clinic Identifier is required' : null,
                            ),
                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _isSavingSettings ? null : _saveSettings,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal.shade700,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: _isSavingSettings
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : const Text('Save Cloud Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: _isTestingConnection ? null : _testConnection,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.teal.shade900,
                                        side: BorderSide(color: Colors.teal.shade300),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: _isTestingConnection
                                          ? const CircularProgressIndicator()
                                          : const Text('Test Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_connectionTestStatus.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Builder(
                                builder: (context) {
                                  final hasWarning = _connectionTestStatus.contains('Note:') || _connectionTestStatus.contains('Warning');
                                  final isSuccess = _connectionTestStatus.startsWith('Connected') && !hasWarning;
                                  final isTesting = _connectionTestStatus.startsWith('Testing');

                                  final bgColor = isSuccess
                                      ? Colors.green.shade50
                                      : hasWarning
                                          ? Colors.amber.shade50
                                          : isTesting
                                              ? Colors.blue.shade50
                                              : Colors.red.shade50;

                                  final borderColor = isSuccess
                                      ? Colors.green.shade300
                                      : hasWarning
                                          ? Colors.amber.shade400
                                          : isTesting
                                              ? Colors.blue.shade300
                                              : Colors.red.shade200;

                                  final iconColor = isSuccess
                                      ? Colors.green.shade800
                                      : hasWarning
                                          ? Colors.amber.shade900
                                          : isTesting
                                              ? Colors.blue.shade800
                                              : Colors.red.shade800;

                                  final textColor = isSuccess
                                      ? Colors.green.shade900
                                      : hasWarning
                                          ? Colors.brown.shade900
                                          : isTesting
                                              ? Colors.blue.shade900
                                              : Colors.red.shade900;

                                  final icon = isSuccess
                                      ? Icons.check_circle
                                      : hasWarning
                                          ? Icons.warning_amber_rounded
                                          : isTesting
                                              ? Icons.sync
                                              : Icons.error_outline;

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2.0),
                                          child: Icon(icon, color: iconColor, size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _connectionTestStatus,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // Right Column: Local Backup & Cloud disaster restore
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // NEW: Local Backup & Restore panel
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Local Backup & Restore',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.teal.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Secure your data locally to an internal drive, external hard disk, or USB key.',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const Divider(height: 24),
                            Text(
                              'Last Local Backup:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _lastLocalBackupTime,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            if (_lastLocalBackupPath.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                _lastLocalBackupPath,
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: _createLocalBackup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.drive_file_move),
                                label: const Text('Create Local Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _restoreLocalBackup,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.teal.shade900,
                                  side: BorderSide(color: Colors.teal.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.settings_backup_restore),
                                label: const Text('Restore from Local Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cloud Disaster Recovery',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.teal.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Restore clinic records onto a new server or device from your cloud vault.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const Divider(height: 24),

                            TextFormField(
                              controller: _restoreProjectController,
                              decoration: const InputDecoration(
                                labelText: 'Cloud Project ID',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _restoreApiKeyController,
                              decoration: const InputDecoration(
                                labelText: 'Cloud Web API Key',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _restoreClinicController,
                              decoration: const InputDecoration(
                                labelText: 'Clinic Identifier Key',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _confirmRestore,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade900,
                                  side: BorderSide(color: Colors.red.shade200),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.cloud_download),
                                label: const Text('Restore Clinic Data', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // NEW: Documentation Information card
                    Card(
                      color: Colors.teal.shade50,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.teal.shade100)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backup & Restore Help',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal.shade900),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Cloud Backup',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text(
                              'Automatically keeps your clinic data backed up when internet access is available.',
                              style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Local Backup',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text(
                              'Creates a complete backup that can be stored on a hard drive or USB drive.',
                              style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Restore',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text(
                              'Restoring replaces the current clinic data with the selected backup. A safety backup is created automatically before restoration.',
                              style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Database Maintenance Card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Database Maintenance',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.teal.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Perform destructive database actions. Be extremely cautious, as these actions cannot be undone.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const Divider(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _handleResetDatabaseDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Reset Database', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
