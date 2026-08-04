// AUTO-GENERATED FILE FROM schema.json via setup.py - DO NOT MODIFY DIRECTLY

class Role {
  final int? id;
  final String roleName;
  final String? description;
  final String? permissions;
  final String? createdAt;
  final String? updatedAt;
  final String? lastSyncedAt;
  final int? isDeleted;
  final String? syncStatus;

  const Role({
    this.id,
    required this.roleName,
    this.description,
    this.permissions,
    this.createdAt,
    this.updatedAt,
    this.lastSyncedAt,
    this.isDeleted,
    this.syncStatus,
  });

  factory Role.fromMap(Map<String, dynamic> map) {
    return Role(
      id: map['id'] != null ? (map['id'] as num).toInt() : null,
      roleName: map['role_name'] as String,
      description: map['description'] as String?,
      permissions: map['permissions'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      lastSyncedAt: map['last_synced_at'] as String?,
      isDeleted: map['is_deleted'] != null ? (map['is_deleted'] as num).toInt() : null,
      syncStatus: map['sync_status'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role_name': roleName,
      'description': description,
      'permissions': permissions,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'is_deleted': isDeleted,
      'sync_status': syncStatus,
    };
  }

  Role copyWith({
    int? id,
    String? roleName,
    String? description,
    String? permissions,
    String? createdAt,
    String? updatedAt,
    String? lastSyncedAt,
    int? isDeleted,
    String? syncStatus,
  }) {
    return Role(
      id: id ?? this.id,
      roleName: roleName ?? this.roleName,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class User {
  final int? id;
  final String userUuid;
  final String username;
  final String passwordHash;
  final String fullName;
  final String? specialization;
  final String? licenseNumber;
  final String? phone;
  final String? email;
  final String role;
  final int? isActive;
  final String? createdAt;
  final String? updatedAt;
  final String? lastSyncedAt;
  final int? isDeleted;
  final String? syncStatus;

  const User({
    this.id,
    required this.userUuid,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    this.specialization,
    this.licenseNumber,
    this.phone,
    this.email,
    required this.role,
    this.isActive,
    this.createdAt,
    this.updatedAt,
    this.lastSyncedAt,
    this.isDeleted,
    this.syncStatus,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] != null ? (map['id'] as num).toInt() : null,
      userUuid: map['user_uuid'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      fullName: map['full_name'] as String,
      specialization: map['specialization'] as String?,
      licenseNumber: map['license_number'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      role: map['role'] as String,
      isActive: map['is_active'] != null ? (map['is_active'] as num).toInt() : null,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      lastSyncedAt: map['last_synced_at'] as String?,
      isDeleted: map['is_deleted'] != null ? (map['is_deleted'] as num).toInt() : null,
      syncStatus: map['sync_status'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_uuid': userUuid,
      'username': username,
      'password_hash': passwordHash,
      'full_name': fullName,
      'specialization': specialization,
      'license_number': licenseNumber,
      'phone': phone,
      'email': email,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'is_deleted': isDeleted,
      'sync_status': syncStatus,
    };
  }

  User copyWith({
    int? id,
    String? userUuid,
    String? username,
    String? passwordHash,
    String? fullName,
    String? specialization,
    String? licenseNumber,
    String? phone,
    String? email,
    String? role,
    int? isActive,
    String? createdAt,
    String? updatedAt,
    String? lastSyncedAt,
    int? isDeleted,
    String? syncStatus,
  }) {
    return User(
      id: id ?? this.id,
      userUuid: userUuid ?? this.userUuid,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      fullName: fullName ?? this.fullName,
      specialization: specialization ?? this.specialization,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class Patient {
  final int? id;
  final String patientUuid;
  final String patientCode;
  final String fullName;
  final String dateOfBirth;
  final int? age;
  final String gender;
  final String? occupation;
  final String mobileNumber;
  final String? address;
  final String? email;
  final String? emergencyContact;
  final String? referralDoctor;
  final String? registrationDate;
  final String? syncStatus;
  final String? updatedAt;
  final String? lastSyncedAt;
  final int? isDeleted;

  const Patient({
    this.id,
    required this.patientUuid,
    required this.patientCode,
    required this.fullName,
    required this.dateOfBirth,
    this.age,
    required this.gender,
    this.occupation,
    required this.mobileNumber,
    this.address,
    this.email,
    this.emergencyContact,
    this.referralDoctor,
    this.registrationDate,
    this.syncStatus,
    this.updatedAt,
    this.lastSyncedAt,
    this.isDeleted,
  });

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] != null ? (map['id'] as num).toInt() : null,
      patientUuid: map['patient_uuid'] as String,
      patientCode: map['patient_code'] as String,
      fullName: map['full_name'] as String,
      dateOfBirth: map['date_of_birth'] as String,
      age: map['age'] != null ? (map['age'] as num).toInt() : null,
      gender: map['gender'] as String,
      occupation: map['occupation'] as String?,
      mobileNumber: map['mobile_number'] as String,
      address: map['address'] as String?,
      email: map['email'] as String?,
      emergencyContact: map['emergency_contact'] as String?,
      referralDoctor: map['referral_doctor'] as String?,
      registrationDate: map['registration_date'] as String?,
      syncStatus: map['sync_status'] as String?,
      updatedAt: map['updated_at'] as String?,
      lastSyncedAt: map['last_synced_at'] as String?,
      isDeleted: map['is_deleted'] != null ? (map['is_deleted'] as num).toInt() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_uuid': patientUuid,
      'patient_code': patientCode,
      'full_name': fullName,
      'date_of_birth': dateOfBirth,
      'age': age,
      'gender': gender,
      'occupation': occupation,
      'mobile_number': mobileNumber,
      'address': address,
      'email': email,
      'emergency_contact': emergencyContact,
      'referral_doctor': referralDoctor,
      'registration_date': registrationDate,
      'sync_status': syncStatus,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'is_deleted': isDeleted,
    };
  }

  Patient copyWith({
    int? id,
    String? patientUuid,
    String? patientCode,
    String? fullName,
    String? dateOfBirth,
    int? age,
    String? gender,
    String? occupation,
    String? mobileNumber,
    String? address,
    String? email,
    String? emergencyContact,
    String? referralDoctor,
    String? registrationDate,
    String? syncStatus,
    String? updatedAt,
    String? lastSyncedAt,
    int? isDeleted,
  }) {
    return Patient(
      id: id ?? this.id,
      patientUuid: patientUuid ?? this.patientUuid,
      patientCode: patientCode ?? this.patientCode,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      address: address ?? this.address,
      email: email ?? this.email,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      referralDoctor: referralDoctor ?? this.referralDoctor,
      registrationDate: registrationDate ?? this.registrationDate,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class PatientVisit {
  final int? id;
  final String visitUuid;
  final int patientId;
  final int? doctorId;
  final String? visitDate;
  final int? visitNumber;
  final String? chiefComplaint;
  final String? history;
  final String? pastMedicalHistory;
  final String? vitalsBp;
  final String? vitalsPulse;
  final String? vitalsTemp;
  final String? vitalsSaturation;
  final String? systemicExamination;
  final String? investigations;
  final String? diagnosis;
  final String? diagnosisCode;
  final String? advice;
  final String? referralTo;
  final String? followupDate;
  final String? syncStatus;
  final String? createdAt;
  final String? updatedAt;
  final String? lastSyncedAt;
  final int? isDeleted;

  const PatientVisit({
    this.id,
    required this.visitUuid,
    required this.patientId,
    this.doctorId,
    this.visitDate,
    this.visitNumber,
    this.chiefComplaint,
    this.history,
    this.pastMedicalHistory,
    this.vitalsBp,
    this.vitalsPulse,
    this.vitalsTemp,
    this.vitalsSaturation,
    this.systemicExamination,
    this.investigations,
    this.diagnosis,
    this.diagnosisCode,
    this.advice,
    this.referralTo,
    this.followupDate,
    this.syncStatus,
    this.createdAt,
    this.updatedAt,
    this.lastSyncedAt,
    this.isDeleted,
  });

  factory PatientVisit.fromMap(Map<String, dynamic> map) {
    return PatientVisit(
      id: map['id'] != null ? (map['id'] as num).toInt() : null,
      visitUuid: map['visit_uuid'] as String,
      patientId: (map['patient_id'] as num).toInt(),
      doctorId: map['doctor_id'] != null ? (map['doctor_id'] as num).toInt() : null,
      visitDate: map['visit_date'] as String?,
      visitNumber: map['visit_number'] != null ? (map['visit_number'] as num).toInt() : null,
      chiefComplaint: map['chief_complaint'] as String?,
      history: map['history'] as String?,
      pastMedicalHistory: map['past_medical_history'] as String?,
      vitalsBp: map['vitals_bp'] as String?,
      vitalsPulse: map['vitals_pulse'] as String?,
      vitalsTemp: map['vitals_temp'] as String?,
      vitalsSaturation: map['vitals_saturation'] as String?,
      systemicExamination: map['systemic_examination'] as String?,
      investigations: map['investigations'] as String?,
      diagnosis: map['diagnosis'] as String?,
      diagnosisCode: map['diagnosis_code'] as String?,
      advice: map['advice'] as String?,
      referralTo: map['referral_to'] as String?,
      followupDate: map['followup_date'] as String?,
      syncStatus: map['sync_status'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      lastSyncedAt: map['last_synced_at'] as String?,
      isDeleted: map['is_deleted'] != null ? (map['is_deleted'] as num).toInt() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visit_uuid': visitUuid,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'visit_date': visitDate,
      'visit_number': visitNumber,
      'chief_complaint': chiefComplaint,
      'history': history,
      'past_medical_history': pastMedicalHistory,
      'vitals_bp': vitalsBp,
      'vitals_pulse': vitalsPulse,
      'vitals_temp': vitalsTemp,
      'vitals_saturation': vitalsSaturation,
      'systemic_examination': systemicExamination,
      'investigations': investigations,
      'diagnosis': diagnosis,
      'diagnosis_code': diagnosisCode,
      'advice': advice,
      'referral_to': referralTo,
      'followup_date': followupDate,
      'sync_status': syncStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'is_deleted': isDeleted,
    };
  }

  PatientVisit copyWith({
    int? id,
    String? visitUuid,
    int? patientId,
    int? doctorId,
    String? visitDate,
    int? visitNumber,
    String? chiefComplaint,
    String? history,
    String? pastMedicalHistory,
    String? vitalsBp,
    String? vitalsPulse,
    String? vitalsTemp,
    String? vitalsSaturation,
    String? systemicExamination,
    String? investigations,
    String? diagnosis,
    String? diagnosisCode,
    String? advice,
    String? referralTo,
    String? followupDate,
    String? syncStatus,
    String? createdAt,
    String? updatedAt,
    String? lastSyncedAt,
    int? isDeleted,
  }) {
    return PatientVisit(
      id: id ?? this.id,
      visitUuid: visitUuid ?? this.visitUuid,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      visitDate: visitDate ?? this.visitDate,
      visitNumber: visitNumber ?? this.visitNumber,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      history: history ?? this.history,
      pastMedicalHistory: pastMedicalHistory ?? this.pastMedicalHistory,
      vitalsBp: vitalsBp ?? this.vitalsBp,
      vitalsPulse: vitalsPulse ?? this.vitalsPulse,
      vitalsTemp: vitalsTemp ?? this.vitalsTemp,
      vitalsSaturation: vitalsSaturation ?? this.vitalsSaturation,
      systemicExamination: systemicExamination ?? this.systemicExamination,
      investigations: investigations ?? this.investigations,
      diagnosis: diagnosis ?? this.diagnosis,
      diagnosisCode: diagnosisCode ?? this.diagnosisCode,
      advice: advice ?? this.advice,
      referralTo: referralTo ?? this.referralTo,
      followupDate: followupDate ?? this.followupDate,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class Bill {
  final int? id;
  final String billNumber;
  final int? visitId;
  final int patientId;
  final double? consultationCharges;
  final double? procedureCharges;
  final double? additionalCharges;
  final double? discountAmount;
  final double totalAmount;
  final double? paidAmount;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? billDate;
  final String? syncStatus;
  final String? updatedAt;
  final String? lastSyncedAt;
  final int? isDeleted;

  const Bill({
    this.id,
    required this.billNumber,
    this.visitId,
    required this.patientId,
    this.consultationCharges,
    this.procedureCharges,
    this.additionalCharges,
    this.discountAmount,
    required this.totalAmount,
    this.paidAmount,
    this.paymentStatus,
    this.paymentMethod,
    this.billDate,
    this.syncStatus,
    this.updatedAt,
    this.lastSyncedAt,
    this.isDeleted,
  });

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] != null ? (map['id'] as num).toInt() : null,
      billNumber: map['bill_number'] as String,
      visitId: map['visit_id'] != null ? (map['visit_id'] as num).toInt() : null,
      patientId: (map['patient_id'] as num).toInt(),
      consultationCharges: map['consultation_charges'] != null ? (map['consultation_charges'] as num).toDouble() : null,
      procedureCharges: map['procedure_charges'] != null ? (map['procedure_charges'] as num).toDouble() : null,
      additionalCharges: map['additional_charges'] != null ? (map['additional_charges'] as num).toDouble() : null,
      discountAmount: map['discount_amount'] != null ? (map['discount_amount'] as num).toDouble() : null,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: map['paid_amount'] != null ? (map['paid_amount'] as num).toDouble() : null,
      paymentStatus: map['payment_status'] as String?,
      paymentMethod: map['payment_method'] as String?,
      billDate: map['bill_date'] as String?,
      syncStatus: map['sync_status'] as String?,
      updatedAt: map['updated_at'] as String?,
      lastSyncedAt: map['last_synced_at'] as String?,
      isDeleted: map['is_deleted'] != null ? (map['is_deleted'] as num).toInt() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_number': billNumber,
      'visit_id': visitId,
      'patient_id': patientId,
      'consultation_charges': consultationCharges,
      'procedure_charges': procedureCharges,
      'additional_charges': additionalCharges,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'bill_date': billDate,
      'sync_status': syncStatus,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'is_deleted': isDeleted,
    };
  }

  Bill copyWith({
    int? id,
    String? billNumber,
    int? visitId,
    int? patientId,
    double? consultationCharges,
    double? procedureCharges,
    double? additionalCharges,
    double? discountAmount,
    double? totalAmount,
    double? paidAmount,
    String? paymentStatus,
    String? paymentMethod,
    String? billDate,
    String? syncStatus,
    String? updatedAt,
    String? lastSyncedAt,
    int? isDeleted,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      visitId: visitId ?? this.visitId,
      patientId: patientId ?? this.patientId,
      consultationCharges: consultationCharges ?? this.consultationCharges,
      procedureCharges: procedureCharges ?? this.procedureCharges,
      additionalCharges: additionalCharges ?? this.additionalCharges,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      billDate: billDate ?? this.billDate,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class BillItem {
  final int? id;
  final int billId;
  final String itemDescription;
  final double amount;

  const BillItem({
    this.id,
    required this.billId,
    required this.itemDescription,
    required this.amount,
  });

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id'] != null ? (map['id'] as num).toInt() : null,
      billId: (map['bill_id'] as num).toInt(),
      itemDescription: map['item_description'] as String,
      amount: (map['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_id': billId,
      'item_description': itemDescription,
      'amount': amount,
    };
  }

  BillItem copyWith({
    int? id,
    int? billId,
    String? itemDescription,
    double? amount,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      itemDescription: itemDescription ?? this.itemDescription,
      amount: amount ?? this.amount,
    );
  }
}

class AuditLog {
  final int? id;
  final int? userId;
  final String action;
  final String? details;
  final String? timestamp;
  final String? syncStatus;

  const AuditLog({
    this.id,
    this.userId,
    required this.action,
    this.details,
    this.timestamp,
    this.syncStatus,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] != null ? (map['id'] as num).toInt() : null,
      userId: map['user_id'] != null ? (map['user_id'] as num).toInt() : null,
      action: map['action'] as String,
      details: map['details'] as String?,
      timestamp: map['timestamp'] as String?,
      syncStatus: map['sync_status'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'details': details,
      'timestamp': timestamp,
      'sync_status': syncStatus,
    };
  }

  AuditLog copyWith({
    int? id,
    int? userId,
    String? action,
    String? details,
    String? timestamp,
    String? syncStatus,
  }) {
    return AuditLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      action: action ?? this.action,
      details: details ?? this.details,
      timestamp: timestamp ?? this.timestamp,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class SyncQueue {
  final int? id;
  final String tableName;
  final int recordId;
  final String operation;
  final String? status;
  final String? lastAttempt;
  final String? errorMessage;
  final String? createdAt;

  const SyncQueue({
    this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    this.status,
    this.lastAttempt,
    this.errorMessage,
    this.createdAt,
  });

  factory SyncQueue.fromMap(Map<String, dynamic> map) {
    return SyncQueue(
      id: map['id'] != null ? (map['id'] as num).toInt() : null,
      tableName: map['table_name'] as String,
      recordId: (map['record_id'] as num).toInt(),
      operation: map['operation'] as String,
      status: map['status'] as String?,
      lastAttempt: map['last_attempt'] as String?,
      errorMessage: map['error_message'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'status': status,
      'last_attempt': lastAttempt,
      'error_message': errorMessage,
      'created_at': createdAt,
    };
  }

  SyncQueue copyWith({
    int? id,
    String? tableName,
    int? recordId,
    String? operation,
    String? status,
    String? lastAttempt,
    String? errorMessage,
    String? createdAt,
  }) {
    return SyncQueue(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      recordId: recordId ?? this.recordId,
      operation: operation ?? this.operation,
      status: status ?? this.status,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
