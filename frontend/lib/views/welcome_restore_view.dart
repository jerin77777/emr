import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../services/backup_service.dart';
import '../services/sync_service.dart';
import '../utils/date_formatter.dart';
import '../main.dart';

class WelcomeRestoreScreen extends StatefulWidget {
  const WelcomeRestoreScreen({super.key});

  @override
  State<WelcomeRestoreScreen> createState() => _WelcomeRestoreScreenState();
}

class _WelcomeRestoreScreenState extends State<WelcomeRestoreScreen> {
  bool _isLoading = false;
  
  // Cloud restore states
  final _projController = TextEditingController();
  final _keyController = TextEditingController();
  final _clinicController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isCloudRestoring = false;
  double _cloudRestoreProgress = 0.0;
  String _cloudRestoreMessage = '';

  @override
  void dispose() {
    _projController.dispose();
    _keyController.dispose();
    _clinicController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen(showSetupDialog: false)),
      );
    }
  }

  // Option 1: Local Restore
  Future<void> _restoreFromLocal() async {
    try {
      final selectedPath = await FilePicker.getDirectoryPath();
      if (selectedPath == null) return;

      setState(() => _isLoading = true);

      // Validate the backup
      final metadata = await BackupService.instance.validateBackup(selectedPath);
      
      setState(() => _isLoading = false);

      if (!mounted) return;

      // Ask for confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Confirm Restore'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Are you sure you want to restore this clinic backup?', style: TextStyle(fontWeight: FontWeight.bold)),
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                child: const Text('Restore Backup'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);

      // Restore it
      await BackupService.instance.restoreLocalBackup(selectedPath);

      setState(() => _isLoading = false);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Restore Successful'),
            content: const Text('Your clinic data has been successfully restored. You can now login using your credentials.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToLogin();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Restore Failed'),
              ],
            ),
            content: Text('Reason: $e'),
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

  // Option 2: Cloud Restore
  void _restoreFromCloud() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cloud Restore Credentials'),
          content: Form(
            key: _formKey,
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter your Firebase cloud configurations to fetch the latest backup:'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _projController,
                    decoration: const InputDecoration(labelText: 'Firebase Project ID', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _keyController,
                    decoration: const InputDecoration(labelText: 'Firebase Web API Key', border: OutlineInputBorder()),
                    obscureText: true,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clinicController,
                    decoration: const InputDecoration(labelText: 'Clinic Namespace ID', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  _runCloudRestore();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              child: const Text('Connect & Restore'),
            ),
          ],
        );
      },
    );
  }

  void _runCloudRestore() {
    final proj = _projController.text.trim();
    final key = _keyController.text.trim();
    final clinic = _clinicController.text.trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!_isCloudRestoring) {
              _isCloudRestoring = true;
              _cloudRestoreProgress = 0.0;
              _cloudRestoreMessage = 'Connecting to Firebase...';

              SyncService.instance.restoreFromCloud(
                projectId: proj,
                apiKey: key,
                clinicId: clinic,
                onProgress: (progress, message) {
                  setDialogState(() {
                    _cloudRestoreProgress = progress;
                    _cloudRestoreMessage = message;
                  });
                },
              ).then((_) async {
                // Save settings locally
                await DatabaseHelper.instance.saveSetting('firebase_project_id', proj);
                await DatabaseHelper.instance.saveSetting('firebase_api_key', key);
                await DatabaseHelper.instance.saveSetting('clinic_id', clinic);

                if (!context.mounted) return;
                setDialogState(() {
                  _isCloudRestoring = false;
                });
                Navigator.pop(context); // Close progress dialog
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Restore Successful'),
                    content: const Text('Clinic data restored successfully from cloud!'),
                    actions: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToLogin();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );
              }).catchError((err) {
                if (!context.mounted) return;
                setDialogState(() {
                  _isCloudRestoring = false;
                });
                Navigator.pop(context); // Close progress dialog
                
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Row(
                      children: const [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Restore Failed'),
                      ],
                    ),
                    content: Text('Error: ${SyncService.extractErrorMessage(err)}'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                );
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Restoring from Cloud'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    CircularProgressIndicator(value: _cloudRestoreProgress),
                    const SizedBox(height: 20),
                    Text(_cloudRestoreMessage, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _cloudRestoreProgress),
                    const SizedBox(height: 12),
                    Text('${(_cloudRestoreProgress * 100).toStringAsFixed(0)}% Complete', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        _isCloudRestoring = false;
      });
    });
  }

  // Option 3: Start Fresh
  Future<void> _startAsNewClinic() async {
    setState(() => _isLoading = true);
    try {
      // Accessing database getter triggers file creation & seeding default admin/doctor users
      await DatabaseHelper.instance.database;
      
      setState(() => _isLoading = false);
      _navigateToLogin();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing database: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRestoreOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Select Restore Source', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How would you like to restore your clinic database?', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              
              // Local Hard Drive
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _restoreFromLocal();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.teal.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.teal.shade50,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.drive_file_move, color: Colors.teal.shade800, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Local Hard Drive Backup', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 14)),
                            const SizedBox(height: 2),
                            const Text('Select and browse a backup folder from your local drive.', style: TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Cloud Backup
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _restoreFromCloud();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.teal.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.teal.shade50,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_download, color: Colors.teal.shade800, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Firebase Cloud Backup', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 14)),
                            const SizedBox(height: 2),
                            const Text('Enter project credentials to pull and restore from the cloud.', style: TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade900,
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_hospital, color: Colors.teal.shade800, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Setup Your Clinic EMR',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose how you want to configure this new installation:',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const Divider(height: 32),
                        
                        // Option A: Restore Clinic Data
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _showRestoreOptionsDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.history),
                            label: const Text('Restore Clinic Data', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Option B: Start Fresh
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _startAsNewClinic,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal.shade900,
                              side: BorderSide(color: Colors.teal.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Start as New Clinic', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
