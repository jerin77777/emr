import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../services/sync_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
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

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSavingSettings = true);
    try {
      await DatabaseHelper.instance.saveSetting('firebase_project_id', _projectController.text.trim());
      await DatabaseHelper.instance.saveSetting('firebase_api_key', _apiKeyController.text.trim());
      await DatabaseHelper.instance.saveSetting('clinic_id', _clinicController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firebase backup settings saved!'), backgroundColor: Colors.green),
        );
      }
      
      // Trigger background sync immediately to verify new config
      SyncService.instance.triggerManualBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSavingSettings = false);
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
              // Trigger actual restore
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
      // Clean up local restore states
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
                // Trigger a full app reload if needed, or clear credentials text
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
          content: Text('An error occurred during restoration:\n\n$error'),
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
                                  onPressed: SyncService.instance.triggerManualBackup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.backup),
                                  label: const Text('Backup Now'),
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
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: _connectionTestStatus.startsWith('Connected')
                                      ? Colors.green.shade50
                                      : _connectionTestStatus.startsWith('Testing')
                                          ? Colors.blue.shade50
                                          : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _connectionTestStatus.startsWith('Connected')
                                        ? Colors.green.shade300
                                        : _connectionTestStatus.startsWith('Testing')
                                            ? Colors.blue.shade300
                                            : Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _connectionTestStatus.startsWith('Connected')
                                          ? Icons.check_circle
                                          : _connectionTestStatus.startsWith('Testing')
                                              ? Icons.sync
                                              : Icons.error_outline,
                                      color: _connectionTestStatus.startsWith('Connected')
                                          ? Colors.green.shade800
                                          : _connectionTestStatus.startsWith('Testing')
                                              ? Colors.blue.shade800
                                              : Colors.red.shade800,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _connectionTestStatus,
                                        style: TextStyle(
                                          color: _connectionTestStatus.startsWith('Connected')
                                              ? Colors.green.shade900
                                              : _connectionTestStatus.startsWith('Testing')
                                                  ? Colors.blue.shade900
                                                  : Colors.red.shade900,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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

            // Right Column: Restore credentials
            Expanded(
              flex: 3,
              child: Card(
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
            ),
          ],
        ),
      ),
    );
  }
}
