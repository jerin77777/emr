// AUTO-GENERATED FILE FROM schema.json via setup.py - DO NOT MODIFY DIRECTLY
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('emr.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS "roles" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "role_name" TEXT NOT NULL UNIQUE,
  "description" TEXT,
  "permissions" TEXT,
  "created_at" TEXT DEFAULT CURRENT_TIMESTAMP
);''');
    await db.execute('''CREATE UNIQUE INDEX IF NOT EXISTS "idx_roles_name" ON "roles" ("role_name");''');
    await db.execute('''CREATE TABLE IF NOT EXISTS "users" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_uuid" TEXT NOT NULL UNIQUE,
  "username" TEXT NOT NULL UNIQUE,
  "password_hash" TEXT NOT NULL,
  "full_name" TEXT NOT NULL,
  "specialization" TEXT,
  "license_number" TEXT,
  "phone" TEXT,
  "email" TEXT,
  "role" TEXT NOT NULL,
  "is_active" INTEGER NOT NULL DEFAULT 1,
  "created_at" TEXT DEFAULT CURRENT_TIMESTAMP
);''');
    await db.execute('''CREATE UNIQUE INDEX IF NOT EXISTS "idx_users_username" ON "users" ("username");''');
    await db.execute('''CREATE INDEX IF NOT EXISTS "idx_users_role" ON "users" ("role");''');
    await db.execute('''CREATE TABLE IF NOT EXISTS "patients" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "patient_uuid" TEXT NOT NULL UNIQUE,
  "patient_code" TEXT NOT NULL UNIQUE,
  "full_name" TEXT NOT NULL,
  "date_of_birth" TEXT NOT NULL,
  "age" INTEGER,
  "gender" TEXT NOT NULL,
  "occupation" TEXT,
  "mobile_number" TEXT NOT NULL,
  "address" TEXT,
  "email" TEXT,
  "emergency_contact" TEXT,
  "referral_doctor" TEXT,
  "registration_date" TEXT DEFAULT CURRENT_TIMESTAMP,
  "sync_status" TEXT DEFAULT 'pending',
  "updated_at" TEXT DEFAULT CURRENT_TIMESTAMP
);''');
    await db.execute('''CREATE UNIQUE INDEX IF NOT EXISTS "idx_patients_code" ON "patients" ("patient_code");''');
    await db.execute('''CREATE INDEX IF NOT EXISTS "idx_patients_name" ON "patients" ("full_name");''');
    await db.execute('''CREATE INDEX IF NOT EXISTS "idx_patients_mobile" ON "patients" ("mobile_number");''');
    await db.execute('''CREATE TABLE IF NOT EXISTS "patient_visits" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "visit_uuid" TEXT NOT NULL UNIQUE,
  "patient_id" INTEGER NOT NULL,
  "doctor_id" INTEGER,
  "visit_date" TEXT DEFAULT CURRENT_TIMESTAMP,
  "visit_number" INTEGER,
  "chief_complaint" TEXT,
  "history" TEXT,
  "past_medical_history" TEXT,
  "vitals_bp" TEXT,
  "vitals_pulse" TEXT,
  "vitals_temp" TEXT,
  "vitals_saturation" TEXT,
  "systemic_examination" TEXT,
  "investigations" TEXT,
  "diagnosis" TEXT,
  "advice" TEXT,
  "referral_to" TEXT,
  "followup_date" TEXT,
  "sync_status" TEXT DEFAULT 'pending',
  "created_at" TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY ("patient_id") REFERENCES "patients" ("id") ON DELETE CASCADE,
  FOREIGN KEY ("doctor_id") REFERENCES "users" ("id") ON DELETE SET NULL
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS "idx_visits_patient" ON "patient_visits" ("patient_id");''');
    await db.execute('''CREATE INDEX IF NOT EXISTS "idx_visits_date" ON "patient_visits" ("visit_date");''');
    await db.execute('''CREATE TABLE IF NOT EXISTS "bills" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "bill_number" TEXT NOT NULL UNIQUE,
  "visit_id" INTEGER,
  "patient_id" INTEGER NOT NULL,
  "consultation_charges" REAL DEFAULT 0.0,
  "procedure_charges" REAL DEFAULT 0.0,
  "additional_charges" REAL DEFAULT 0.0,
  "discount_amount" REAL DEFAULT 0.0,
  "total_amount" REAL NOT NULL,
  "paid_amount" REAL DEFAULT 0.0,
  "payment_status" TEXT NOT NULL DEFAULT 'Pending',
  "payment_method" TEXT,
  "bill_date" TEXT DEFAULT CURRENT_TIMESTAMP,
  "sync_status" TEXT DEFAULT 'pending',
  FOREIGN KEY ("visit_id") REFERENCES "patient_visits" ("id") ON DELETE SET NULL,
  FOREIGN KEY ("patient_id") REFERENCES "patients" ("id") ON DELETE CASCADE
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS "idx_bills_patient" ON "bills" ("patient_id");''');
    await db.execute('''CREATE UNIQUE INDEX IF NOT EXISTS "idx_bills_number" ON "bills" ("bill_number");''');
    await db.execute('''CREATE TABLE IF NOT EXISTS "bill_items" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "bill_id" INTEGER NOT NULL,
  "item_description" TEXT NOT NULL,
  "amount" REAL NOT NULL,
  FOREIGN KEY ("bill_id") REFERENCES "bills" ("id") ON DELETE CASCADE
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS "idx_bill_items_bill" ON "bill_items" ("bill_id");''');
    await db.execute('''CREATE TABLE IF NOT EXISTS "audit_logs" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER,
  "action" TEXT NOT NULL,
  "details" TEXT,
  "timestamp" TEXT DEFAULT CURRENT_TIMESTAMP,
  "sync_status" TEXT DEFAULT 'pending',
  FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE SET NULL
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS "idx_audit_user" ON "audit_logs" ("user_id");''');
    await db.execute('''CREATE INDEX IF NOT EXISTS "idx_audit_action" ON "audit_logs" ("action");''');
    await db.execute('''CREATE TABLE IF NOT EXISTS "sync_queue" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "table_name" TEXT NOT NULL,
  "record_id" INTEGER NOT NULL,
  "operation" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "last_attempt" TEXT,
  "error_message" TEXT,
  "created_at" TEXT DEFAULT CURRENT_TIMESTAMP
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS "idx_sync_status" ON "sync_queue" ("status");''');
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    await db.execute('''INSERT OR IGNORE INTO "roles" ("role_name", "description", "permissions") VALUES ('Admin', 'System Administrator with full access', 'all');''');
    await db.execute('''INSERT OR IGNORE INTO "roles" ("role_name", "description", "permissions") VALUES ('Doctor', 'Doctor / Physician with clinical access', 'clinical,patients,prescriptions,billing');''');
  }

  // === Role CRUD Operations ===
  Future<int> insertRole(Role role) async {
    final db = await instance.database;
    return await db.insert('roles', role.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Role>> getAllRoles() async {
    final db = await instance.database;
    final result = await db.query('roles');
    return result.map((json) => Role.fromMap(json)).toList();
  }

  Future<Role?> getRoleById(int id) async {
    final db = await instance.database;
    final maps = await db.query('roles', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Role.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updateRole(Role role) async {
    final db = await instance.database;
    return await db.update('roles', role.toMap(), where: 'id = ?', whereArgs: [role.id]);
  }

  Future<int> deleteRole(int id) async {
    final db = await instance.database;
    return await db.delete('roles', where: 'id = ?', whereArgs: [id]);
  }

  // === User CRUD Operations ===
  Future<int> insertUser(User user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final result = await db.query('users');
    return result.map((json) => User.fromMap(json)).toList();
  }

  Future<User?> getUserById(int id) async {
    final db = await instance.database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updateUser(User user) async {
    final db = await instance.database;
    return await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await instance.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // === Patient CRUD Operations ===
  Future<int> insertPatient(Patient patient) async {
    final db = await instance.database;
    return await db.insert('patients', patient.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Patient>> getAllPatients() async {
    final db = await instance.database;
    final result = await db.query('patients');
    return result.map((json) => Patient.fromMap(json)).toList();
  }

  Future<Patient?> getPatientById(int id) async {
    final db = await instance.database;
    final maps = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Patient.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updatePatient(Patient patient) async {
    final db = await instance.database;
    return await db.update('patients', patient.toMap(), where: 'id = ?', whereArgs: [patient.id]);
  }

  Future<int> deletePatient(int id) async {
    final db = await instance.database;
    return await db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  // === PatientVisit CRUD Operations ===
  Future<int> insertPatientVisit(PatientVisit patientVisit) async {
    final db = await instance.database;
    return await db.insert('patient_visits', patientVisit.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PatientVisit>> getAllPatientVisits() async {
    final db = await instance.database;
    final result = await db.query('patient_visits');
    return result.map((json) => PatientVisit.fromMap(json)).toList();
  }

  Future<PatientVisit?> getPatientVisitById(int id) async {
    final db = await instance.database;
    final maps = await db.query('patient_visits', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return PatientVisit.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updatePatientVisit(PatientVisit patientVisit) async {
    final db = await instance.database;
    return await db.update('patient_visits', patientVisit.toMap(), where: 'id = ?', whereArgs: [patientVisit.id]);
  }

  Future<int> deletePatientVisit(int id) async {
    final db = await instance.database;
    return await db.delete('patient_visits', where: 'id = ?', whereArgs: [id]);
  }





  // === Bill CRUD Operations ===
  Future<int> insertBill(Bill bill) async {
    final db = await instance.database;
    return await db.insert('bills', bill.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Bill>> getAllBills() async {
    final db = await instance.database;
    final result = await db.query('bills');
    return result.map((json) => Bill.fromMap(json)).toList();
  }

  Future<Bill?> getBillById(int id) async {
    final db = await instance.database;
    final maps = await db.query('bills', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Bill.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updateBill(Bill bill) async {
    final db = await instance.database;
    return await db.update('bills', bill.toMap(), where: 'id = ?', whereArgs: [bill.id]);
  }

  Future<int> deleteBill(int id) async {
    final db = await instance.database;
    return await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  // === BillItem CRUD Operations ===
  Future<int> insertBillItem(BillItem billItem) async {
    final db = await instance.database;
    return await db.insert('bill_items', billItem.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BillItem>> getAllBillItems() async {
    final db = await instance.database;
    final result = await db.query('bill_items');
    return result.map((json) => BillItem.fromMap(json)).toList();
  }

  Future<BillItem?> getBillItemById(int id) async {
    final db = await instance.database;
    final maps = await db.query('bill_items', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return BillItem.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updateBillItem(BillItem billItem) async {
    final db = await instance.database;
    return await db.update('bill_items', billItem.toMap(), where: 'id = ?', whereArgs: [billItem.id]);
  }

  Future<int> deleteBillItem(int id) async {
    final db = await instance.database;
    return await db.delete('bill_items', where: 'id = ?', whereArgs: [id]);
  }

  // === AuditLog CRUD Operations ===
  Future<int> insertAuditLog(AuditLog auditLog) async {
    final db = await instance.database;
    return await db.insert('audit_logs', auditLog.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AuditLog>> getAllAuditLogs() async {
    final db = await instance.database;
    final result = await db.query('audit_logs');
    return result.map((json) => AuditLog.fromMap(json)).toList();
  }

  Future<AuditLog?> getAuditLogById(int id) async {
    final db = await instance.database;
    final maps = await db.query('audit_logs', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return AuditLog.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updateAuditLog(AuditLog auditLog) async {
    final db = await instance.database;
    return await db.update('audit_logs', auditLog.toMap(), where: 'id = ?', whereArgs: [auditLog.id]);
  }

  Future<int> deleteAuditLog(int id) async {
    final db = await instance.database;
    return await db.delete('audit_logs', where: 'id = ?', whereArgs: [id]);
  }

  // === SyncQueue CRUD Operations ===
  Future<int> insertSyncQueue(SyncQueue syncQueue) async {
    final db = await instance.database;
    return await db.insert('sync_queue', syncQueue.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SyncQueue>> getAllSyncQueues() async {
    final db = await instance.database;
    final result = await db.query('sync_queue');
    return result.map((json) => SyncQueue.fromMap(json)).toList();
  }

  Future<SyncQueue?> getSyncQueueById(int id) async {
    final db = await instance.database;
    final maps = await db.query('sync_queue', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return SyncQueue.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updateSyncQueue(SyncQueue syncQueue) async {
    final db = await instance.database;
    return await db.update('sync_queue', syncQueue.toMap(), where: 'id = ?', whereArgs: [syncQueue.id]);
  }

  Future<int> deleteSyncQueue(int id) async {
    final db = await instance.database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // === Custom EMR Specialized Queries ===

  Future<List<Patient>> searchPatients(String query) async {
    final db = await instance.database;
    if (query.trim().isEmpty) {
      final result = await db.query('patients', orderBy: 'id DESC');
      return result.map((json) => Patient.fromMap(json)).toList();
    }
    final q = '%${query.trim().toLowerCase()}%';
    final result = await db.rawQuery('''
      SELECT * FROM patients 
      WHERE LOWER(full_name) LIKE ? 
         OR LOWER(patient_code) LIKE ? 
         OR LOWER(mobile_number) LIKE ? 
         OR LOWER(referral_doctor) LIKE ?
      ORDER BY id DESC
    ''', [q, q, q, q]);
    return result.map((json) => Patient.fromMap(json)).toList();
  }

  Future<List<PatientVisit>> getVisitsForPatient(int patientId) async {
    final db = await instance.database;
    final result = await db.query('patient_visits', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'id DESC');
    return result.map((json) => PatientVisit.fromMap(json)).toList();
  }



  Future<List<Bill>> getBillsForPatient(int patientId) async {
    final db = await instance.database;
    final result = await db.query('bills', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'id DESC');
    return result.map((json) => Bill.fromMap(json)).toList();
  }

  Future<String> generateNextPatientCode() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT MAX(id) as max_id FROM patients');
    final maxId = (result.first['max_id'] as num?)?.toInt() ?? 0;
    final nextId = maxId + 1;
    final year = DateTime.now().year;
    return 'PAT-$year-${nextId.toString().padLeft(3, '0')}';
  }

  Future<String> generateNextBillNumber() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT MAX(id) as max_id FROM bills');
    final maxId = (result.first['max_id'] as num?)?.toInt() ?? 0;
    final nextId = maxId + 1;
    final year = DateTime.now().year;
    return 'INV-$year-${nextId.toString().padLeft(4, '0')}';
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}