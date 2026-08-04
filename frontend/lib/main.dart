import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/database_helper.dart';
import 'models/models.dart';
import 'views/patient_management_view.dart';
import 'views/billing_dashboard_view.dart';

bool debug = false;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const EMRApp());
}

class EMRApp extends StatelessWidget {
  const EMRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'EMR Clinic Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal,
          secondary: Colors.tealAccent,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      builder: (context, child) {
        if (!debug) return child ?? const SizedBox.shrink();
        return Stack(
          children: [
            ?child,
            const Positioned(
              bottom: 20,
              right: 20,
              child: DebugResetDbButton(),
            ),
          ],
        );
      },
    );
  }
}

class DebugResetDbButton extends StatefulWidget {
  const DebugResetDbButton({super.key});

  @override
  State<DebugResetDbButton> createState() => _DebugResetDbButtonState();
}

class _DebugResetDbButtonState extends State<DebugResetDbButton> {
  bool _isResetting = false;

  Future<void> _handleReset() async {
    final navContext = navigatorKey.currentContext;
    if (navContext == null) return;

    final confirm = await showDialog<bool>(
      context: navContext,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Reset Database?'),
          ],
        ),
        content: const Text(
          'This will delete all current records (patients, visits, bills, audit logs) and re-seed default admin and doctor accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset & Seed'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isResetting = true;
    });

    try {
      await DatabaseHelper.instance.resetAndSeedDatabase();

      final currentNavContext = navigatorKey.currentContext;
      if (currentNavContext != null && currentNavContext.mounted) {
        ScaffoldMessenger.of(currentNavContext).showSnackBar(
          const SnackBar(
            content: Text('Database reset and seeded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      final currentNavContext = navigatorKey.currentContext;
      if (currentNavContext != null && currentNavContext.mounted) {
        ScaffoldMessenger.of(currentNavContext).showSnackBar(
          SnackBar(
            content: Text('Error resetting database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: FloatingActionButton.extended(
        heroTag: 'debug_reset_db_fab',
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: _isResetting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.delete_forever),
        label: Text(_isResetting ? 'Resetting...' : 'Reset DB'),
        onPressed: _isResetting ? null : _handleReset,
      ),
    );
  }
}

// ============================================================================
// 1. LOGIN SCREEN
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin');
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

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
            u.passwordHash == password &&
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

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSection ?? 'patients';
    _preSelectedPatient = widget.initialPreSelectedPatient;
  }

  void navigateToSection(String section, {Patient? patient}) {
    setState(() {
      _activeSection = section;
      _preSelectedPatient = patient;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.currentUser.role.toLowerCase() == 'admin';
    final hasBilling = widget.currentUser.role.toLowerCase() == 'admin' || 
                       widget.currentUser.role.toLowerCase() == 'doctor';

    // Sidebar items
    final List<Map<String, dynamic>> menuItems = [
      {'id': 'patients', 'title': 'Patient Directory', 'icon': Icons.people},
      if (hasBilling) {'id': 'billing', 'title': 'Billing & Invoices', 'icon': Icons.receipt_long},
      if (isAdmin) {'id': 'users', 'title': 'User Management', 'icon': Icons.manage_accounts},
      if (isAdmin) {'id': 'roles', 'title': 'Role Management', 'icon': Icons.security},
    ];

    Widget buildBody() {
      switch (_activeSection) {
        case 'patients':
          return PatientManagementView(currentUser: widget.currentUser);
        case 'billing':
          return BillingDashboardView(
            currentUser: widget.currentUser,
            preSelectedPatient: _preSelectedPatient,
          );
        case 'users':
          return const UserManagementTab();
        case 'roles':
          return const RoleManagementTab();
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
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  color: const Color(0xFF00332C),
                  child: Row(
                    children: [
                      const Icon(Icons.local_hospital, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Clinic EMR',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
                        child: Text(widget.currentUser.fullName[0].toUpperCase()),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.currentUser.fullName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.currentUser.role,
                              style: TextStyle(color: Colors.teal.shade200, fontSize: 11),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              _activeSection = item['id'];
                              _preSelectedPatient = null;
                            });
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          selected: isSelected,
                          selectedTileColor: Colors.teal.shade800,
                          selectedColor: Colors.white,
                          textColor: Colors.teal.shade100,
                          iconColor: Colors.teal.shade200,
                          leading: Icon(item['icon']),
                          title: Text(
                            item['title'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Sidebar Footer - Logout Button
                const Divider(color: Colors.white12, height: 1),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textColor: Colors.red.shade100,
                    iconColor: Colors.red.shade200,
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w500)),
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
                      : _activeSection == 'billing'
                          ? 'Billing Dashboard & Invoices'
                          : _activeSection == 'users'
                              ? 'User & Doctor Management'
                              : 'Role & Permission Configuration',
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
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showUserForm(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
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

  @override
  void initState() {
    super.initState();
    final u = widget.existingUser;
    _usernameController = TextEditingController(text: u?.username ?? '');
    _passwordController = TextEditingController(text: u?.passwordHash ?? '');
    _fullNameController = TextEditingController(text: u?.fullName ?? '');
    _specController = TextEditingController(text: u?.specialization ?? '');
    _licenseController = TextEditingController(text: u?.licenseNumber ?? '');
    _phoneController = TextEditingController(text: u?.phone ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    if (u != null) {
      _selectedRole = u.role;
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

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final user = User(
      id: widget.existingUser?.id,
      userUuid:
          widget.existingUser?.userUuid ??
          'usr-${DateTime.now().millisecondsSinceEpoch}',
      username: _usernameController.text.trim(),
      passwordHash: _passwordController.text.trim(),
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
            width: 400,
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
                  decoration: const InputDecoration(labelText: 'Password *'),
                  obscureText: true,
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
                  title: Text(
                    role.roleName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'Description: ${role.description ?? "N/A"}\nPermissions: ${role.permissions ?? "None"}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showRoleForm(role),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
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
  late TextEditingController _permController;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRole;
    _nameController = TextEditingController(text: r?.roleName ?? '');
    _descController = TextEditingController(text: r?.description ?? '');
    _permController = TextEditingController(text: r?.permissions ?? '');
  }

  Future<void> _saveRole() async {
    if (!_formKey.currentState!.validate()) return;

    final role = Role(
      id: widget.existingRole?.id,
      roleName: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      permissions: _permController.text.trim().isEmpty
          ? null
          : _permController.text.trim(),
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
                  decoration: const InputDecoration(
                    labelText: 'Role Name (e.g. Nurse, Radiologist) *',
                  ),
                  validator: (v) => v!.isEmpty ? 'Role Name required' : null,
                ),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextFormField(
                  controller: _permController,
                  decoration: const InputDecoration(
                    labelText:
                        'Permissions (comma-separated, e.g. clinical,billing)',
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
