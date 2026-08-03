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
      onOpen: _migrateSchema,
    );
  }

  Future<void> _migrateSchema(Database db) async {
    try {
      final rolesInfo = await db.rawQuery("PRAGMA table_info('roles')");
      final rolesCols = rolesInfo.map((c) => c['name'] as String).toSet();
      if (!rolesCols.contains('role_name')) {
        await db.execute('ALTER TABLE "roles" ADD COLUMN "role_name" TEXT;');
      }
      if (!rolesCols.contains('description')) {
        await db.execute('ALTER TABLE "roles" ADD COLUMN "description" TEXT;');
      }
      if (!rolesCols.contains('permissions')) {
        await db.execute('ALTER TABLE "roles" ADD COLUMN "permissions" TEXT;');
      }
      if (!rolesCols.contains('created_at')) {
        await db.execute('ALTER TABLE "roles" ADD COLUMN "created_at" TEXT;');
      }
      final usersInfo = await db.rawQuery("PRAGMA table_info('users')");
      final usersCols = usersInfo.map((c) => c['name'] as String).toSet();
      if (!usersCols.contains('user_uuid')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "user_uuid" TEXT;');
      }
      if (!usersCols.contains('username')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "username" TEXT;');
      }
      if (!usersCols.contains('password_hash')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "password_hash" TEXT;');
      }
      if (!usersCols.contains('full_name')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "full_name" TEXT;');
      }
      if (!usersCols.contains('specialization')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "specialization" TEXT;');
      }
      if (!usersCols.contains('license_number')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "license_number" TEXT;');
      }
      if (!usersCols.contains('phone')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "phone" TEXT;');
      }
      if (!usersCols.contains('email')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "email" TEXT;');
      }
      if (!usersCols.contains('role')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "role" TEXT;');
      }
      if (!usersCols.contains('is_active')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "is_active" INTEGER;');
      }
      if (!usersCols.contains('created_at')) {
        await db.execute('ALTER TABLE "users" ADD COLUMN "created_at" TEXT;');
      }
      final patientsInfo = await db.rawQuery("PRAGMA table_info('patients')");
      final patientsCols = patientsInfo.map((c) => c['name'] as String).toSet();
      if (!patientsCols.contains('patient_uuid')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "patient_uuid" TEXT;');
      }
      if (!patientsCols.contains('patient_code')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "patient_code" TEXT;');
      }
      if (!patientsCols.contains('full_name')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "full_name" TEXT;');
      }
      if (!patientsCols.contains('date_of_birth')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "date_of_birth" TEXT;');
      }
      if (!patientsCols.contains('age')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "age" INTEGER;');
      }
      if (!patientsCols.contains('gender')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "gender" TEXT;');
      }
      if (!patientsCols.contains('occupation')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "occupation" TEXT;');
      }
      if (!patientsCols.contains('mobile_number')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "mobile_number" TEXT;');
      }
      if (!patientsCols.contains('address')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "address" TEXT;');
      }
      if (!patientsCols.contains('email')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "email" TEXT;');
      }
      if (!patientsCols.contains('emergency_contact')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "emergency_contact" TEXT;');
      }
      if (!patientsCols.contains('referral_doctor')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "referral_doctor" TEXT;');
      }
      if (!patientsCols.contains('registration_date')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "registration_date" TEXT;');
      }
      if (!patientsCols.contains('sync_status')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "sync_status" TEXT;');
      }
      if (!patientsCols.contains('updated_at')) {
        await db.execute('ALTER TABLE "patients" ADD COLUMN "updated_at" TEXT;');
      }
      final patientVisitsInfo = await db.rawQuery("PRAGMA table_info('patient_visits')");
      final patientVisitsCols = patientVisitsInfo.map((c) => c['name'] as String).toSet();
      if (!patientVisitsCols.contains('visit_uuid')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "visit_uuid" TEXT;');
      }
      if (!patientVisitsCols.contains('patient_id')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "patient_id" INTEGER;');
      }
      if (!patientVisitsCols.contains('doctor_id')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "doctor_id" INTEGER;');
      }
      if (!patientVisitsCols.contains('visit_date')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "visit_date" TEXT;');
      }
      if (!patientVisitsCols.contains('visit_number')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "visit_number" INTEGER;');
      }
      if (!patientVisitsCols.contains('chief_complaint')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "chief_complaint" TEXT;');
      }
      if (!patientVisitsCols.contains('history')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "history" TEXT;');
      }
      if (!patientVisitsCols.contains('past_medical_history')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "past_medical_history" TEXT;');
      }
      if (!patientVisitsCols.contains('vitals_bp')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "vitals_bp" TEXT;');
      }
      if (!patientVisitsCols.contains('vitals_pulse')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "vitals_pulse" TEXT;');
      }
      if (!patientVisitsCols.contains('vitals_temp')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "vitals_temp" TEXT;');
      }
      if (!patientVisitsCols.contains('vitals_saturation')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "vitals_saturation" TEXT;');
      }
      if (!patientVisitsCols.contains('systemic_examination')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "systemic_examination" TEXT;');
      }
      if (!patientVisitsCols.contains('investigations')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "investigations" TEXT;');
      }
      if (!patientVisitsCols.contains('diagnosis')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "diagnosis" TEXT;');
      }
      if (!patientVisitsCols.contains('advice')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "advice" TEXT;');
      }
      if (!patientVisitsCols.contains('referral_to')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "referral_to" TEXT;');
      }
      if (!patientVisitsCols.contains('followup_date')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "followup_date" TEXT;');
      }
      if (!patientVisitsCols.contains('sync_status')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "sync_status" TEXT;');
      }
      if (!patientVisitsCols.contains('created_at')) {
        await db.execute('ALTER TABLE "patient_visits" ADD COLUMN "created_at" TEXT;');
      }
      final billsInfo = await db.rawQuery("PRAGMA table_info('bills')");
      final billsCols = billsInfo.map((c) => c['name'] as String).toSet();
      if (!billsCols.contains('bill_number')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "bill_number" TEXT;');
      }
      if (!billsCols.contains('visit_id')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "visit_id" INTEGER;');
      }
      if (!billsCols.contains('patient_id')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "patient_id" INTEGER;');
      }
      if (!billsCols.contains('consultation_charges')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "consultation_charges" REAL;');
      }
      if (!billsCols.contains('procedure_charges')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "procedure_charges" REAL;');
      }
      if (!billsCols.contains('additional_charges')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "additional_charges" REAL;');
      }
      if (!billsCols.contains('discount_amount')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "discount_amount" REAL;');
      }
      if (!billsCols.contains('total_amount')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "total_amount" REAL;');
      }
      if (!billsCols.contains('paid_amount')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "paid_amount" REAL;');
      }
      if (!billsCols.contains('payment_status')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "payment_status" TEXT;');
      }
      if (!billsCols.contains('payment_method')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "payment_method" TEXT;');
      }
      if (!billsCols.contains('bill_date')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "bill_date" TEXT;');
      }
      if (!billsCols.contains('sync_status')) {
        await db.execute('ALTER TABLE "bills" ADD COLUMN "sync_status" TEXT;');
      }
      final billItemsInfo = await db.rawQuery("PRAGMA table_info('bill_items')");
      final billItemsCols = billItemsInfo.map((c) => c['name'] as String).toSet();
      if (!billItemsCols.contains('bill_id')) {
        await db.execute('ALTER TABLE "bill_items" ADD COLUMN "bill_id" INTEGER;');
      }
      if (!billItemsCols.contains('item_description')) {
        await db.execute('ALTER TABLE "bill_items" ADD COLUMN "item_description" TEXT;');
      }
      if (!billItemsCols.contains('amount')) {
        await db.execute('ALTER TABLE "bill_items" ADD COLUMN "amount" REAL;');
      }
      final auditLogsInfo = await db.rawQuery("PRAGMA table_info('audit_logs')");
      final auditLogsCols = auditLogsInfo.map((c) => c['name'] as String).toSet();
      if (!auditLogsCols.contains('user_id')) {
        await db.execute('ALTER TABLE "audit_logs" ADD COLUMN "user_id" INTEGER;');
      }
      if (!auditLogsCols.contains('action')) {
        await db.execute('ALTER TABLE "audit_logs" ADD COLUMN "action" TEXT;');
      }
      if (!auditLogsCols.contains('details')) {
        await db.execute('ALTER TABLE "audit_logs" ADD COLUMN "details" TEXT;');
      }
      if (!auditLogsCols.contains('timestamp')) {
        await db.execute('ALTER TABLE "audit_logs" ADD COLUMN "timestamp" TEXT;');
      }
      if (!auditLogsCols.contains('sync_status')) {
        await db.execute('ALTER TABLE "audit_logs" ADD COLUMN "sync_status" TEXT;');
      }
      final syncQueueInfo = await db.rawQuery("PRAGMA table_info('sync_queue')");
      final syncQueueCols = syncQueueInfo.map((c) => c['name'] as String).toSet();
      if (!syncQueueCols.contains('table_name')) {
        await db.execute('ALTER TABLE "sync_queue" ADD COLUMN "table_name" TEXT;');
      }
      if (!syncQueueCols.contains('record_id')) {
        await db.execute('ALTER TABLE "sync_queue" ADD COLUMN "record_id" INTEGER;');
      }
      if (!syncQueueCols.contains('operation')) {
        await db.execute('ALTER TABLE "sync_queue" ADD COLUMN "operation" TEXT;');
      }
      if (!syncQueueCols.contains('status')) {
        await db.execute('ALTER TABLE "sync_queue" ADD COLUMN "status" TEXT;');
      }
      if (!syncQueueCols.contains('last_attempt')) {
        await db.execute('ALTER TABLE "sync_queue" ADD COLUMN "last_attempt" TEXT;');
      }
      if (!syncQueueCols.contains('error_message')) {
        await db.execute('ALTER TABLE "sync_queue" ADD COLUMN "error_message" TEXT;');
      }
      if (!syncQueueCols.contains('created_at')) {
        await db.execute('ALTER TABLE "sync_queue" ADD COLUMN "created_at" TEXT;');
      }
    } catch (_) {}
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
    await db.execute('''INSERT OR IGNORE INTO "users" ("user_uuid", "username", "password_hash", "full_name", "specialization", "license_number", "phone", "email", "role", "is_active") VALUES ('usr-admin-default', 'admin', 'admin', 'System Administrator', 'Administration', 'ADMIN-001', '1234567890', 'admin@clinic.com', 'Admin', 1);''');
    await db.execute('''INSERT OR IGNORE INTO "users" ("user_uuid", "username", "password_hash", "full_name", "specialization", "license_number", "phone", "email", "role", "is_active") VALUES ('usr-doctor-default', 'doctor', 'doctor', 'Dr. John Doe', 'General Medicine', 'MED-1001', '0987654321', 'doctor@clinic.com', 'Doctor', 1);''');
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

  Future<void> resetAndSeedDatabase() async {
    final db = await instance.database;
    await db.execute('PRAGMA foreign_keys = OFF;');
    await db.execute('DROP TABLE IF EXISTS "sync_queue";');
    await db.execute('DROP TABLE IF EXISTS "audit_logs";');
    await db.execute('DROP TABLE IF EXISTS "bill_items";');
    await db.execute('DROP TABLE IF EXISTS "bills";');
    await db.execute('DROP TABLE IF EXISTS "patient_visits";');
    await db.execute('DROP TABLE IF EXISTS "patients";');
    await db.execute('DROP TABLE IF EXISTS "users";');
    await db.execute('DROP TABLE IF EXISTS "roles";');
    await _createDB(db, 1);
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}