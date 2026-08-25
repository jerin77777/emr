import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'database/database_helper.dart';
import 'models/models.dart';
import 'views/patient_management_view.dart';
import 'views/billing_dashboard_view.dart';
import 'views/consultation_records_view.dart';
import 'views/settings_backup_view.dart';
import 'services/sync_service.dart';
import 'services/backup_service.dart';
import 'utils/crypto_helper.dart';
import 'services/spell_check_service.dart';
import 'services/signature_cleanup_service.dart';
import 'views/welcome_restore_view.dart';
import 'widgets/custom_title_bar.dart';
import 'package:path/path.dart' show join;
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'config.dart';

bool debug = true;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  final appDirPath = await DatabaseHelper.getAppDirectoryPath();
  final dbFile = File(join(appDirPath, 'emr.db'));
  final bool dbExists = await dbFile.exists();

  // Initialize offline spell check dictionary in background
  SpellCheckService.instance.initialize();

  SyncService.instance.startSyncLoop();
  runApp(EMRApp(isFirstLaunch: !dbExists));

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    doWhenWindowReady(() {
      const initialSize = Size(1280, 800);
      const minSize = Size(1024, 650);
      appWindow.minSize = minSize;
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = "Anything EMR";
      appWindow.show();
    });
  }
}

class EMRApp extends StatelessWidget {
  final bool isFirstLaunch;
  const EMRApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Anything EMR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal,
          secondary: Colors.tealAccent,
        ),
        useMaterial3: true,
      ),
      home: isFirstLaunch ? const WelcomeRestoreScreen() : const LoginScreen(),
      builder: (context, child) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          return Material(
            color: const Color(0xFF00241E),
            child: Column(
              children: [
                const CustomAppTitleBar(),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            ),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

// ============================================================================
// 1. LOGIN SCREEN
// ============================================================================
class LoginScreen extends StatefulWidget {
  final bool showSetupDialog;
  const LoginScreen({super.key, this.showSetupDialog = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin');
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showSetupDialog) {
        _checkNewInstallation();
      }
    });
  }

  Future<void> _checkNewInstallation() async {
    try {
      final patients = await DatabaseHelper.instance.getAllPatients();
      if (patients.isEmpty) {
        if (!mounted) return;
        _showInitialSetupDialog();
      }
    } catch (_) {}
  }

  void _showInitialSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool showBackupOptions = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(showBackupOptions ? 'Select Restore Source' : 'New Installation Detected'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showBackupOptions
                          ? 'How would you like to restore your clinic database?'
                          : 'No clinic data was found. How would you like to proceed?',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    if (!showBackupOptions) ...[
                      // Start Fresh option
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
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
                              Icon(Icons.add_circle_outline, color: Colors.teal.shade800, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Start Fresh',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 14)),
                                    const Text('Configure this as a completely new clinic setup.',
                                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Restore Backup option
                      InkWell(
                        onTap: () {
                          setDialogState(() {
                            showBackupOptions = true;
                          });
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
                              Icon(Icons.history, color: Colors.teal.shade800, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Restore Backup',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 14)),
                                    const Text('Restore your existing clinic database from a backup.',
                                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Local Hard Drive option
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _restoreFromLocalDrive();
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
                              Icon(Icons.drive_file_move, color: Colors.teal.shade800, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Restore from Hard Drive',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 14)),
                                    const Text('Browse and select a local backup folder.',
                                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Cloud option
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _showRestoreCredentialsDialog();
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
                              Icon(Icons.cloud_download, color: Colors.teal.shade800, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Restore from Cloud',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 14)),
                                    const Text('Enter Firebase credentials to restore from cloud.',
                                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (showBackupOptions)
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        showBackupOptions = false;
                      });
                    },
                    child: const Text('Back'),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _restoreFromLocalDrive() async {
    try {
      final selectedPath = await FilePicker.getDirectoryPath();
      if (selectedPath == null) return;

      if (!mounted) return;
      setState(() => _isLoading = true);

      final metadata = await BackupService.instance.validateBackup(selectedPath);

      setState(() => _isLoading = false);

      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Restore'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Restore this backup?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Clinic: ${metadata.clinicIdentifier}'),
              Text('Patients: ${metadata.patientCount}'),
              Text('Consultations: ${metadata.visitCount}'),
              Text('Bills: ${metadata.billCount}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              child: const Text('Restore'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      setState(() => _isLoading = true);
      await BackupService.instance.restoreLocalBackup(selectedPath);
      setState(() => _isLoading = false);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 26),
            SizedBox(width: 10),
            Text('Restore Successful'),
          ]),
          content: const Text('Clinic data restored. You can now log in with your credentials.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showRestoreCredentialsDialog() {
    final projController = TextEditingController();
    final apiController = TextEditingController();
    final clinicController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isRestoring = false;
        double progress = 0.0;
        String statusMessage = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void runRestore() {
              if (!formKey.currentState!.validate()) return;

              setDialogState(() {
                isRestoring = true;
                progress = 0.0;
                statusMessage = 'Connecting to cloud vault...';
              });

              SyncService.instance
                  .restoreFromCloud(
                    projectId: projController.text.trim(),
                    apiKey: apiController.text.trim(),
                    clinicId: clinicController.text.trim(),
                    onProgress: (prog, msg) {
                      setDialogState(() {
                        progress = prog;
                        statusMessage = msg;
                      });
                    },
                  )
                  .then((_) {
                    if (!context.mounted) return;
                    setDialogState(() {
                      isRestoring = false;
                    });
                    Navigator.pop(context);
                    _showSuccessMessage();
                  })
                  .catchError((err) {
                    if (!context.mounted) return;
                    setDialogState(() {
                      isRestoring = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Restore Failed: ${SyncService.extractErrorMessage(err)}'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Cloud Vault Credentials'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isRestoring) ...[
                        const Text(
                          'Please input your clinic\'s cloud vault settings:',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: projController,
                          decoration: const InputDecoration(
                            labelText: 'Firebase Project ID',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: apiController,
                          decoration: const InputDecoration(
                            labelText: 'Firebase Web API Key',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: clinicController,
                          decoration: const InputDecoration(
                            labelText: 'Clinic Identifier Namespace',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        CircularProgressIndicator(value: progress),
                        const SizedBox(height: 24),
                        Text(
                          statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% Complete',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: isRestoring
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: runRestore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start Restoration'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _showSuccessMessage() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Restoration Completed'),
            ],
          ),
          content: const Text(
            'Your clinic database has been successfully recovered. You can now log in using your doctor or administrator credentials.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue to Login'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      var users = await DatabaseHelper.instance.getAllUsers();
      if (users.isEmpty) {
        // Ensure default users are seeded for existing DBs
        await DatabaseHelper.instance.insertUser(
          const User(
            userUuid: 'usr-admin-default',
            username: 'admin',
            passwordHash: 'admin',
            fullName: 'System Administrator',
            specialization: 'Administration',
            licenseNumber: 'ADMIN-001',
            phone: '1234567890',
            email: 'admin@clinic.com',
            role: 'Admin',
            isActive: 1,
          ),
        );
        await DatabaseHelper.instance.insertUser(
          const User(
            userUuid: 'usr-doctor-default',
            username: 'doctor',
            passwordHash: 'doctor',
            fullName: 'Dr. John Doe',
            specialization: 'General Medicine',
            licenseNumber: 'MED-1001',
            phone: '0987654321',
            email: 'doctor@clinic.com',
            role: 'Doctor',
            isActive: 1,
          ),
        );
        users = await DatabaseHelper.instance.getAllUsers();
      }

      final matchedUser = users.firstWhere(
        (u) =>
            u.username == username &&
            CryptoHelper.verifyPassword(password, u.passwordHash) &&
            u.isActive == 1,
        orElse: () => const User(
          id: -1,
          userUuid: '',
          username: '',
          passwordHash: '',
          fullName: '',
          role: '',
        ),
      );

      setState(() {
        _isLoading = false;
      });

      if (matchedUser.id == -1) {
        setState(() {
          _errorMessage = 'Invalid username or password.';
        });
      } else {
        // Log Audit Event
        await DatabaseHelper.instance.insertAuditLog(
          AuditLog(
            userId: matchedUser.id,
            action: 'User Login',
            details:
                'User ${matchedUser.username} (${matchedUser.role}) logged in',
          ),
        );

        if (!mounted) return;

        if (matchedUser.role.toLowerCase() == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboard(currentUser: matchedUser),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StaffDashboard(currentUser: matchedUser),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Login Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade800, Colors.teal.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(24),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.local_hospital,
                            size: 64,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'EMR Clinic Portal',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please sign in to continue',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Enter username' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Enter password' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Default Admin: admin / admin',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. ADMIN DASHBOARD (User Management & Role Management)
// ============================================================================
class AdminDashboard extends StatelessWidget {
  final User currentUser;
  const AdminDashboard({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(currentUser: currentUser);
  }
}

class DashboardShell extends StatefulWidget {
  final User currentUser;
  final Patient? initialPreSelectedPatient;
  final String? initialSection;

  const DashboardShell({
    super.key,
    required this.currentUser,
    this.initialPreSelectedPatient,
    this.initialSection,
  });

  @override
  State<DashboardShell> createState() => DashboardShellState();
}

class DashboardShellState extends State<DashboardShell> {
  late String _activeSection;
  Patient? _preSelectedPatient;
  List<String> _permissions = [];
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSection ?? 'patients';
    _preSelectedPatient = widget.initialPreSelectedPatient;
    _loadRolePermissions();
  }

  Future<void> _loadRolePermissions() async {
    try {
      final role = await DatabaseHelper.instance.getRoleByName(widget.currentUser.role);
      if (role != null) {
        final permStr = role.permissions?.toLowerCase() ?? '';
        if (permStr == 'all' || permStr == 'all_permissions') {
          _permissions = [
            'dashboard',
            'patients',
            'consultations',
            'prescriptions',
            'billing',
            'reports',
            'settings',
            'user management'
          ];
        } else {
          _permissions = permStr.split(',').map((p) => p.trim()).toList();
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingPermissions = false;
      });
    }
  }

  void navigateToSection(String section, {Patient? patient}) {
    setState(() {
      _activeSection = section;
      _preSelectedPatient = patient;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermissions) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = widget.currentUser.role.toLowerCase() == 'admin';
    final hasPatients = isAdmin || _permissions.contains('patients');
    final hasConsultations = isAdmin || _permissions.contains('consultations');
    final hasBilling = isAdmin || _permissions.contains('billing');
    final hasUsers = isAdmin || _permissions.contains('user management');
    final hasRoles = isAdmin || _permissions.contains('user management');
    final hasSettings = isAdmin || _permissions.contains('settings');

    // Sidebar items
    final List<Map<String, dynamic>> menuItems = [
      if (hasPatients)
        {'id': 'patients', 'title': 'Patient Directory', 'icon': Icons.people},
      if (hasConsultations)
        {
          'id': 'consultations',
          'title': 'Consultation Records',
          'icon': Icons.history_edu,
        },
      if (hasBilling)
        {
          'id': 'billing',
          'title': 'Billing & Invoices',
          'icon': Icons.receipt_long,
        },
      if (hasUsers)
        {
          'id': 'users',
          'title': 'User Management',
          'icon': Icons.manage_accounts,
        },
      if (hasRoles)
        {'id': 'roles', 'title': 'Role Management', 'icon': Icons.security},
      if (hasSettings)
        {'id': 'settings', 'title': 'Settings & Backup', 'icon': Icons.settings},
    ];

    if (menuItems.isNotEmpty && !menuItems.any((item) => item['id'] == _activeSection)) {
      _activeSection = menuItems.first['id'];
    }

    Widget buildBody() {
      switch (_activeSection) {
        case 'patients':
          return PatientManagementView(currentUser: widget.currentUser);
        case 'consultations':
          return ConsultationRecordsView(currentUser: widget.currentUser);
        case 'billing':
          return BillingDashboardView(
            currentUser: widget.currentUser,
            preSelectedPatient: _preSelectedPatient,
          );
        case 'users':
          return const UserManagementTab();
        case 'roles':
          return const RoleManagementTab();
        case 'settings':
          return SettingsBackupView(currentUser: widget.currentUser);
        default:
          return PatientManagementView(currentUser: widget.currentUser);
      }
    }

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar Navigation
          Container(
            width: 260,
            color: Colors.teal.shade900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sidebar Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  color: const Color(0xFF00332C),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_hospital,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Clinic EMR',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDemoVersion
                                    ? Colors.orange.shade700
                                    : Colors.green.shade600,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isDemoVersion ? 'DEMO VERSION' : 'PRODUCTION VERSION',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // User Profile Summary in Sidebar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.teal.shade800,
                        foregroundColor: Colors.white,
                        child: Text(
                          widget.currentUser.fullName[0].toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.currentUser.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.currentUser.role,
                              style: TextStyle(
                                color: Colors.teal.shade200,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                // Sidebar Menu Items
                Expanded(
                  child: ListView.builder(
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final isSelected = _activeSection == item['id'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                _activeSection = item['id'];
                                _preSelectedPatient = null;
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            selected: isSelected,
                            selectedTileColor: Colors.teal.shade800,
                            selectedColor: Colors.white,
                            textColor: Colors.teal.shade100,
                            iconColor: Colors.teal.shade200,
                            leading: Icon(item['icon']),
                            title: Text(
                              item['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Sidebar Footer - Demo Limits Usage
                if (isDemoVersion) ...[
                  const Divider(color: Colors.white12, height: 1),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    child: DemoUsageSidebarPanel(),
                  ),
                ],
                // Sidebar Footer - Logout Button
                const Divider(color: Colors.white12, height: 1),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textColor: Colors.red.shade100,
                      iconColor: Colors.red.shade200,
                      leading: const Icon(Icons.logout),
                      title: const Text(
                        'Logout',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Active Main View Content
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  _activeSection == 'patients'
                      ? 'Patient Directory & EMR Record'
                      : _activeSection == 'consultations'
                      ? 'Consultation Records Search'
                      : _activeSection == 'billing'
                      ? 'Billing Dashboard & Invoices'
                      : _activeSection == 'users'
                      ? 'User & Doctor Management'
                      : _activeSection == 'roles'
                      ? 'Role & Permission Configuration'
                      : 'EMR Cloud Settings & Backups',
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal.shade900,
                elevation: 1,
                shadowColor: Colors.black12,
              ),
              body: buildBody(),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. USER MANAGEMENT TAB (CRUD Users / Doctors / Staff)
// ============================================================================
class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    setState(() {
      _usersFuture = DatabaseHelper.instance.getAllUsers();
    });
  }

  Future<void> _deleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete user "${user.username}" (${user.fullName})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && user.id != null) {
      await DatabaseHelper.instance.deleteUser(user.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted user ${user.username}')));
      _loadUsers();
    }
  }

  void _showUserForm([User? existingUser]) {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        existingUser: existingUser,
        onSaved: () {
          _loadUsers();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add User / Doctor'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    foregroundColor: Colors.teal.shade900,
                    child: Text(user.role[0].toUpperCase()),
                  ),
                  title: Text(
                    '${user.fullName} (@${user.username})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Role: ${user.role} | Specialization: ${user.specialization ?? "N/A"}\nLicense: ${user.licenseNumber ?? "N/A"} | Phone: ${user.phone ?? "N/A"}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        tooltip: 'Edit User',
                        onPressed: () => _showUserForm(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete User',
                        onPressed: () => _deleteUser(user),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Form dialog to Create / Edit User
class UserFormDialog extends StatefulWidget {
  final User? existingUser;
  final VoidCallback onSaved;

  const UserFormDialog({super.key, this.existingUser, required this.onSaved});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _fullNameController;
  late TextEditingController _specController;
  late TextEditingController _licenseController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  String _selectedRole = 'Doctor';
  List<Role> _availableRoles = [];
  bool _obscurePassword = true;

  // Signature processing states
  Uint8List? _origSigBytes;
  Uint8List? _cleanSigBytes;
  bool _isProcessingSig = false;
  String? _sigError;

  Uint8List? _approvedSigBytes;
  Uint8List? _approvedOrigBytes;
  bool? _approvedIsClean;

  String? _existingSigPath;
  String? _existingOrigSigPath;
  int _existingSigVersion = 1;

  @override
  void initState() {
    super.initState();
    final u = widget.existingUser;
    _usernameController = TextEditingController(text: u?.username ?? '');
    _passwordController = TextEditingController(text: u != null ? '******' : '');
    _fullNameController = TextEditingController(text: u?.fullName ?? '');
    _specController = TextEditingController(text: u?.specialization ?? '');
    _licenseController = TextEditingController(text: u?.licenseNumber ?? '');
    _phoneController = TextEditingController(text: u?.phone ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    if (u != null) {
      _selectedRole = u.role;
      _existingSigPath = u.signatureFilePath;
      _existingOrigSigPath = u.originalSignatureFilePath;
      _existingSigVersion = u.signatureVersion ?? 1;
    }
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    final roles = await DatabaseHelper.instance.getAllRoles();
    setState(() {
      _availableRoles = roles;
      if (roles.isNotEmpty && !roles.any((r) => r.roleName == _selectedRole)) {
        _selectedRole = roles.first.roleName;
      }
    });
  }

  Future<void> _pickAndProcessSignature() async {
    setState(() {
      _sigError = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );

      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final file = File(path);
      if (!await file.exists()) {
        setState(() => _sigError = 'File does not exist on disk.');
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        setState(() => _sigError = 'File size exceeds maximum limit of 10MB.');
        return;
      }

      setState(() {
        _isProcessingSig = true;
      });

      // Process transparent cleanup locally using dynamic threshold isolate
      final cleanResult = await SignatureCleanupService.cleanSignature(bytes);

      setState(() {
        _isProcessingSig = false;
        _origSigBytes = bytes;
        if (cleanResult.success) {
          _cleanSigBytes = cleanResult.cleanedBytes;
          _sigError = null;
        } else {
          _cleanSigBytes = null;
          _sigError = cleanResult.errorMessage ?? 'Background removal failed.';
        }
      });
    } catch (e) {
      setState(() {
        _isProcessingSig = false;
        _sigError = 'Error picking file: $e';
      });
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final enteredPassword = _passwordController.text.trim();
    String passwordHashToSave;
    if (widget.existingUser != null) {
      if (enteredPassword.isEmpty || RegExp(r'^\*+$').hasMatch(enteredPassword)) {
        passwordHashToSave = widget.existingUser!.passwordHash;
      } else {
        passwordHashToSave = CryptoHelper.hashPassword(enteredPassword);
      }
    } else {
      passwordHashToSave = CryptoHelper.hashPassword(enteredPassword);
    }

    final userUuid = widget.existingUser?.userUuid ?? 'usr-${DateTime.now().millisecondsSinceEpoch}';
    
    String? sigPath = _existingSigPath;
    String? origSigPath = _existingOrigSigPath;
    int sigVersion = _existingSigVersion;
    String? sigUpdatedAt = widget.existingUser?.signatureUpdatedAt;

    // Save uploaded signature files versioned in local directory
    if (_approvedSigBytes != null) {
      try {
        final appDir = await DatabaseHelper.getAppDirectoryPath();
        final sigDir = Directory(join(appDir, 'ClinicData', 'users', userUuid, 'signature'));
        await sigDir.create(recursive: true);
        
        final origDir = Directory(join(sigDir.path, 'original'));
        final procDir = Directory(join(sigDir.path, 'processed'));
        await origDir.create(recursive: true);
        await procDir.create(recursive: true);

        final nextVersion = widget.existingUser != null ? _existingSigVersion + 1 : 1;
        
        final newOrigPath = join(origDir.path, 'signature_v$nextVersion.jpg');
        final newProcPath = join(procDir.path, 'signature_v$nextVersion.png');
        
        await File(newOrigPath).writeAsBytes(_approvedOrigBytes!);
        await File(newProcPath).writeAsBytes(_approvedSigBytes!);
        
        sigPath = newProcPath;
        origSigPath = newOrigPath;
        sigVersion = nextVersion;
        sigUpdatedAt = DateTime.now().toIso8601String();
      } catch (e) {
        debugPrint('Error saving signature files: $e');
      }
    } else if (_approvedSigBytes == null && _existingSigPath == null) {
      // If signature is removed, set to null
      sigPath = null;
      origSigPath = null;
      sigVersion = 1;
      sigUpdatedAt = null;
    }

    final user = User(
      id: widget.existingUser?.id,
      userUuid: userUuid,
      username: _usernameController.text.trim(),
      passwordHash: passwordHashToSave,
      fullName: _fullNameController.text.trim(),
      specialization: _specController.text.trim().isEmpty
          ? null
          : _specController.text.trim(),
      licenseNumber: _licenseController.text.trim().isEmpty
          ? null
          : _licenseController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      role: _selectedRole,
      isActive: 1,
      signatureFilePath: sigPath,
      originalSignatureFilePath: origSigPath,
      signatureVersion: sigVersion,
      signatureUpdatedAt: sigUpdatedAt,
    );

    if (widget.existingUser == null) {
      await DatabaseHelper.instance.insertUser(user);
    } else {
      await DatabaseHelper.instance.updateUser(user);
    }

    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingUser != null;
    return AlertDialog(
      title: Text(
        isEditing ? 'Edit User / Doctor' : 'Create New User / Doctor',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username *'),
                  validator: (v) => v!.isEmpty ? 'Username required' : null,
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: widget.existingUser != null ? 'Password (leave as ****** to keep unchanged) *' : 'Password *',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (v) => v!.isEmpty ? 'Password required' : null,
                ),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                  validator: (v) => v!.isEmpty ? 'Full Name required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Role *'),
                  items:
                      (_availableRoles.isEmpty
                              ? [
                                  const Role(roleName: 'Doctor'),
                                  const Role(roleName: 'Admin'),
                                ]
                              : _availableRoles)
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.roleName,
                              child: Text(r.roleName),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedRole = v);
                  },
                ),
                TextFormField(
                  controller: _specController,
                  decoration: const InputDecoration(
                    labelText: 'Specialization (e.g. Cardiology)',
                  ),
                ),
                TextFormField(
                  controller: _licenseController,
                  decoration: const InputDecoration(
                    labelText: 'License Number (e.g. MED-1234)',
                  ),
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                ),
                if (_selectedRole.toLowerCase() == 'doctor') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Doctor Signature *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isProcessingSig) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(width: 12),
                          Text('Cleaning background offline...', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ] else if (_origSigBytes != null) ...[
                    // Comparison view
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Compare Signature Cleanup',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('Original Upload', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        color: Colors.white,
                                      ),
                                      child: Image.memory(_origSigBytes!, fit: BoxFit.contain),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('Cleaned (Transparent)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        color: Colors.teal.shade50,
                                      ),
                                      child: _cleanSigBytes != null
                                          ? Image.memory(_cleanSigBytes!, fit: BoxFit.contain)
                                          : const Center(
                                              child: Text(
                                                'Failed',
                                                style: TextStyle(color: Colors.red, fontSize: 11),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_sigError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _sigError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (_cleanSigBytes != null)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _approvedSigBytes = _cleanSigBytes;
                                      _approvedOrigBytes = _origSigBytes;
                                      _approvedIsClean = true;
                                      _origSigBytes = null;
                                      _cleanSigBytes = null;
                                      _sigError = null;
                                    });
                                  },
                                  child: const Text('Use Cleaned', style: TextStyle(fontSize: 12)),
                                ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade600,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _approvedSigBytes = _origSigBytes;
                                    _approvedOrigBytes = _origSigBytes;
                                    _approvedIsClean = false;
                                    _origSigBytes = null;
                                    _cleanSigBytes = null;
                                    _sigError = null;
                                  });
                                },
                                child: const Text('Use Original', style: TextStyle(fontSize: 12)),
                              ),
                              TextButton(
                                onPressed: _pickAndProcessSignature,
                                child: const Text('Try Again', style: TextStyle(fontSize: 12)),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _origSigBytes = null;
                                    _cleanSigBytes = null;
                                    _sigError = null;
                                  });
                                },
                                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else if (_approvedSigBytes != null) ...[
                    Column(
                      children: [
                        Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.memory(_approvedSigBytes!, fit: BoxFit.contain),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _approvedIsClean == true ? 'Cleaned' : 'Original',
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _pickAndProcessSignature,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Replace', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _approvedSigBytes = null;
                                  _approvedOrigBytes = null;
                                  _approvedIsClean = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                              label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else if (_existingSigPath != null) ...[
                    Column(
                      children: [
                        Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: FutureBuilder<bool>(
                            future: File(_existingSigPath!).exists(),
                            builder: (context, snapshot) {
                              if (snapshot.data == true) {
                                return Image.file(File(_existingSigPath!), fit: BoxFit.contain);
                              } else {
                                return const Center(
                                  child: Text('Signature file not found', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _pickAndProcessSignature,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Replace', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _existingSigPath = null;
                                  _existingOrigSigPath = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                              label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.teal.shade800,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.teal.shade200),
                        ),
                      ),
                      onPressed: _pickAndProcessSignature,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Signature (PNG, JPG, JPEG)'),
                    ),
                    if (_sigError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _sigError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: _saveUser,
          child: const Text('Save User'),
        ),
      ],
    );
  }
}

// ============================================================================
// 4. ROLE MANAGEMENT TAB (Separate Role CRUD & Permissions)
// ============================================================================
class RoleManagementTab extends StatefulWidget {
  const RoleManagementTab({super.key});

  @override
  State<RoleManagementTab> createState() => _RoleManagementTabState();
}

class _RoleManagementTabState extends State<RoleManagementTab> {
  late Future<List<Role>> _rolesFuture;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  void _loadRoles() {
    setState(() {
      _rolesFuture = DatabaseHelper.instance.getAllRoles();
    });
  }

  Future<void> _deleteRole(Role role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text(
          'Are you sure you want to delete role "${role.roleName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && role.id != null) {
      await DatabaseHelper.instance.deleteRole(role.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted role ${role.roleName}')));
      _loadRoles();
    }
  }

  void _showRoleForm([Role? existingRole]) {
    showDialog(
      context: context,
      builder: (context) => RoleFormDialog(
        existingRole: existingRole,
        onSaved: () {
          _loadRoles();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoleForm(),
        icon: const Icon(Icons.shield_outlined),
        label: const Text('Add Custom Role'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Role>>(
        future: _rolesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final roles = snapshot.data ?? [];
          if (roles.isEmpty) {
            return const Center(child: Text('No roles found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: roles.length,
            itemBuilder: (context, index) {
              final role = roles[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.security, size: 20),
                  ),
                  title: Row(
                    children: [
                      Text(
                        role.roleName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (role.isSystem) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade800,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'System Role',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'Description: ${role.description ?? "N/A"}\nPermissions: ${role.permissions ?? "None"}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        tooltip: 'Edit Role',
                        onPressed: () => _showRoleForm(role),
                      ),
                      if (!role.isSystem)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete Role',
                          onPressed: () => _deleteRole(role),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Form dialog to Create / Edit Role
class RoleFormDialog extends StatefulWidget {
  final Role? existingRole;
  final VoidCallback onSaved;

  const RoleFormDialog({super.key, this.existingRole, required this.onSaved});

  @override
  State<RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  final List<String> _allPermissionsList = [
    'Dashboard',
    'Patients',
    'Consultations',
    'Prescriptions',
    'Billing',
    'Reports',
    'Settings',
    'User Management',
    'Assign Doctor'
  ];
  List<String> _selectedPerms = [];

  @override
  void initState() {
    super.initState();
    final r = widget.existingRole;
    _nameController = TextEditingController(text: r?.roleName ?? '');
    _descController = TextEditingController(text: r?.description ?? '');
    
    final initialPerms = r?.permissions ?? '';
    if (initialPerms.toLowerCase() == 'all') {
      _selectedPerms = List.from(_allPermissionsList);
    } else {
      _selectedPerms = initialPerms
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .map((p) {
            final mapped = p.toLowerCase() == 'consultation.assign_doctor' ? 'Assign Doctor' : p;
            return _allPermissionsList.firstWhere(
              (item) => item.toLowerCase() == mapped.toLowerCase(),
              orElse: () => mapped,
            );
          })
          .toList();
    }
  }

  Future<void> _saveRole() async {
    if (!_formKey.currentState!.validate()) return;

    final String permissionsString = _selectedPerms.map((p) {
      if (p == 'Assign Doctor') return 'consultation.assign_doctor';
      return p.toLowerCase();
    }).join(',');

    final role = Role(
      id: widget.existingRole?.id,
      roleName: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      permissions: permissionsString.isEmpty ? 'none' : permissionsString,
      roleKey: widget.existingRole?.roleKey,
      isSystemRole: widget.existingRole?.isSystemRole ?? 0,
    );

    if (widget.existingRole == null) {
      await DatabaseHelper.instance.insertRole(role);
    } else {
      await DatabaseHelper.instance.updateRole(role);
    }

    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRole != null;
    final isSystem = widget.existingRole?.isSystem == true;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Role' : 'Create Custom Role'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !isSystem,
                  decoration: const InputDecoration(
                    labelText: 'Role Name (e.g. Nurse, Radiologist) *',
                  ),
                  validator: (v) => v!.isEmpty ? 'Role Name required' : null,
                ),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Permissions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _allPermissionsList.map((perm) {
                      final isChecked = _selectedPerms.contains(perm);
                      return CheckboxListTile(
                        title: Text(perm, style: const TextStyle(fontSize: 13)),
                        dense: true,
                        value: isChecked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedPerms.add(perm);
                            } else {
                              _selectedPerms.remove(perm);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: _saveRole,
          child: const Text('Save Role'),
        ),
      ],
    );
  }
}

// ============================================================================
// 5. STAFF DASHBOARD (Doctor / Receptionist Workspace)
// ============================================================================
class StaffDashboard extends StatelessWidget {
  final User currentUser;
  const StaffDashboard({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(currentUser: currentUser);
  }
}

// ============================================================================
// 6. DEMO USAGE SIDEBAR PANEL WIDGET
// ============================================================================
class DemoUsageSidebarPanel extends StatefulWidget {
  const DemoUsageSidebarPanel({super.key});

  @override
  State<DemoUsageSidebarPanel> createState() => _DemoUsageSidebarPanelState();
}

class _DemoUsageSidebarPanelState extends State<DemoUsageSidebarPanel> {
  int _patients = 0;
  int _visits = 0;
  int _bills = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    DatabaseHelper.changeNotifier.addListener(_loadCounts);
  }

  @override
  void dispose() {
    DatabaseHelper.changeNotifier.removeListener(_loadCounts);
    super.dispose();
  }

  Future<void> _loadCounts() async {
    try {
      final pCount = await DatabaseHelper.instance.getActivePatientsCount();
      final vCount = await DatabaseHelper.instance.getActivePatientVisitsCount();
      final bCount = await DatabaseHelper.instance.getActiveBillsCount();
      if (mounted) {
        setState(() {
          _patients = pCount;
          _visits = vCount;
          _bills = bCount;
          _loading = false;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    final pPct = (_patients / 10).clamp(0.0, 1.0);
    final vPct = (_visits / 10).clamp(0.0, 1.0);
    final bPct = (_bills / 10).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'DEMO RECORD LIMITS',
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        _buildUsageRow('Patients', _patients, 10, pPct),
        const SizedBox(height: 8),
        _buildUsageRow('Visits', _visits, 10, vPct),
        const SizedBox(height: 8),
        _buildUsageRow('Invoices', _bills, 10, bPct),
      ],
    );
  }

  Widget _buildUsageRow(String label, int current, int max, double pct) {
    final isLimitReached = current >= max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '$current / $max',
              style: TextStyle(
                color: isLimitReached ? Colors.orangeAccent : Colors.white,
                fontSize: 12,
                fontWeight: isLimitReached ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              isLimitReached ? Colors.orangeAccent : Colors.tealAccent,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
