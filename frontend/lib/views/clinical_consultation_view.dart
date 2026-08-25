import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';
import '../utils/date_formatter.dart';
import '../widgets/spell_check_widgets.dart';

class ClinicalConsultationView extends StatefulWidget {
  final Patient patient;
  final User currentUser;
  final PatientVisit? existingVisit;

  const ClinicalConsultationView({
    super.key,
    required this.patient,
    required this.currentUser,
    this.existingVisit,
  });

  @override
  State<ClinicalConsultationView> createState() => _ClinicalConsultationViewState();
}

class _ClinicalConsultationViewState extends State<ClinicalConsultationView> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String _tempUnit = '°F';

  String? _selectedIcdCode;
  String? _selectedIcdName;
  final FocusNode _diagnosisFocusNode = FocusNode();
  final List<ConsultationDiagnosis> _selectedDiagnoses = [];

  List<PatientVisit> _previousVisits = [];
  bool _hasPreviousVisits = false;

  // Doctor assignment state variables
  List<User> _activeDoctors = [];
  User? _selectedDoctor;
  bool _canAssignDoctor = false;
  bool _isLoadingDoctors = true;

  @override
  void initState() {
    super.initState();
    if (widget.existingVisit != null) {
      _loadExistingVisitData(widget.existingVisit!);
    }
    _loadPreviousVisits();
    _diagnosisController.addListener(_onDiagnosisChanged);
    _initDoctorAssignment();
  }

  void _loadExistingVisitData(PatientVisit v) {
    _chiefComplaintController.text = v.chiefComplaint ?? '';
    _historyController.text = v.history ?? '';
    _pastHistoryController.text = v.pastMedicalHistory ?? '';
    _vitalsBpController.text = v.vitalsBp ?? '';
    _vitalsPulseController.text = v.vitalsPulse ?? '';
    _vitalsSaturationController.text = v.vitalsSaturation ?? '';

    if (v.vitalsTemp != null && v.vitalsTemp!.isNotEmpty) {
      if (v.vitalsTemp!.contains('°C') || v.vitalsTemp!.toLowerCase().contains('c')) {
        _tempUnit = '°C';
        _vitalsTempController.text = v.vitalsTemp!.replaceAll('°C', '').replaceAll('C', '').replaceAll('°', '').trim();
      } else {
        _tempUnit = '°F';
        _vitalsTempController.text = v.vitalsTemp!.replaceAll('°F', '').replaceAll('F', '').replaceAll('°', '').trim();
      }
    }

    _systemicExamController.text = v.systemicExamination ?? '';
    _investigationsController.text = v.investigations ?? '';
    _adviceController.text = v.advice ?? '';
    _referralToController.text = v.referralTo ?? '';
    _followupDateController.text = v.followupDate ?? '';

    if (v.diagnoses != null && v.diagnoses!.isNotEmpty) {
      _selectedDiagnoses.clear();
      _selectedDiagnoses.addAll(v.diagnoses!);
    } else if (v.id != null) {
      DatabaseHelper.instance.getDiagnosesForVisit(v.id!).then((diags) {
        if (mounted && diags.isNotEmpty) {
          setState(() {
            _selectedDiagnoses.clear();
            _selectedDiagnoses.addAll(diags);
          });
        } else if (v.diagnosis != null && v.diagnosis!.isNotEmpty) {
          setState(() {
            _selectedDiagnoses.clear();
            _selectedDiagnoses.add(ConsultationDiagnosis(
              icdCode: v.diagnosisCode ?? 'Custom',
              diagnosisName: v.diagnosis!,
            ));
          });
        }
      }).catchError((_) {});
    }
  }

  Future<void> _loadPreviousVisits() async {
    try {
      final visits = await DatabaseHelper.instance.getVisitsForPatient(widget.patient.id!);
      if (visits.isNotEmpty) {
        setState(() {
          visits.sort((a, b) => (b.visitDate ?? '').compareTo(a.visitDate ?? ''));
          _previousVisits = visits;
          _hasPreviousVisits = true;
        });
      }
    } catch (_) {}
  }

  void _onDiagnosisChanged() {
    if (_selectedIcdCode != null && _diagnosisController.text != _selectedIcdName) {
      setState(() {
        _selectedIcdCode = null;
        _selectedIcdName = null;
      });
    }
  }

  // Fetch active doctors and evaluate selection priorities
  Future<void> _initDoctorAssignment() async {
    setState(() => _isLoadingDoctors = true);
    try {
      final allUsers = await DatabaseHelper.instance.getAllUsers();
      final List<User> doctors = [];
      for (final u in allUsers) {
        if (u.isActive == 0) continue;
        final role = await DatabaseHelper.instance.getRoleByName(u.role);
        if (role?.roleKey == 'doctor' || u.role.toLowerCase() == 'doctor') {
          doctors.add(u);
        }
      }
      
      bool hasAssignPerm = false;
      final currentRole = await DatabaseHelper.instance.getRoleByName(widget.currentUser.role);
      if (widget.currentUser.role.toLowerCase() == 'admin' ||
          currentRole?.roleKey == 'admin' ||
          currentRole?.roleName.toLowerCase() == 'admin') {
        hasAssignPerm = true;
      } else if (currentRole != null) {
        final permsStr = currentRole.permissions?.toLowerCase() ?? '';
        if (permsStr == 'all' || permsStr == 'all_permissions') {
          hasAssignPerm = true;
        } else {
          final perms = permsStr.split(',').map((p) => p.trim()).toList();
          hasAssignPerm = perms.contains('consultation.assign_doctor') ||
                          perms.contains('assign doctor') ||
                          perms.contains('assign_doctor') ||
                          perms.contains('consultation.assign doctor');
        }
      }

      User? defaultDoc;
      if (widget.existingVisit?.doctorId != null) {
        for (final d in doctors) {
          if (d.id == widget.existingVisit!.doctorId) {
            defaultDoc = d;
            break;
          }
        }
      }

      if (defaultDoc == null) {
        final currentRoleOfUser = await DatabaseHelper.instance.getRoleByName(widget.currentUser.role);
        final isCurrentUserDoctor = currentRoleOfUser?.roleKey == 'doctor' || widget.currentUser.role.toLowerCase() == 'doctor';
        
        if (isCurrentUserDoctor) {
          for (final d in doctors) {
            if (d.userUuid == widget.currentUser.userUuid) {
              defaultDoc = d;
              break;
            }
          }
          defaultDoc ??= widget.currentUser;
        }
      }

      if (defaultDoc == null && widget.patient.id != null) {
        final patientVisits = await DatabaseHelper.instance.getVisitsForPatient(widget.patient.id!);
        if (patientVisits.isNotEmpty) {
          patientVisits.sort((a, b) => (b.visitDate ?? '').compareTo(a.visitDate ?? ''));
          final lastDocId = patientVisits.first.doctorId;
          if (lastDocId != null) {
            for (final d in doctors) {
              if (d.id == lastDocId) {
                defaultDoc = d;
                break;
              }
            }
          }
        }
      }

      if (defaultDoc == null) {
        final lastDocUuid = await DatabaseHelper.instance.getSetting('last_selected_doctor_${widget.currentUser.userUuid}');
        if (lastDocUuid != null && lastDocUuid.isNotEmpty) {
          for (final d in doctors) {
            if (d.userUuid == lastDocUuid) {
              defaultDoc = d;
              break;
            }
          }
        }
      }

      if (defaultDoc == null && doctors.isNotEmpty) {
        defaultDoc = doctors.first;
      }

      setState(() {
        _activeDoctors = doctors;
        _selectedDoctor = defaultDoc;
        _canAssignDoctor = hasAssignPerm;
        _isLoadingDoctors = false;
      });
    } catch (e) {
      debugPrint('Error initializing doctor assignment: $e');
      setState(() {
        _isLoadingDoctors = false;
      });
    }
  }

  // Controllers for free text clinical headings
  final _chiefComplaintController = SpellCheckTextEditingController();
  final _historyController = SpellCheckTextEditingController();
  final _pastHistoryController = SpellCheckTextEditingController();

  // Vital signs (entry separated)
  final _vitalsBpController = TextEditingController();
  final _vitalsPulseController = TextEditingController();
  final _vitalsTempController = TextEditingController();
  final _vitalsSaturationController = TextEditingController();

  final _systemicExamController = SpellCheckTextEditingController();
  final _investigationsController = SpellCheckTextEditingController();
  final _diagnosisController = TextEditingController();
  final _adviceController = SpellCheckTextEditingController();
  final _referralToController = SpellCheckTextEditingController();
  final _followupDateController = TextEditingController();

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _historyController.dispose();
    _pastHistoryController.dispose();
    _vitalsBpController.dispose();
    _vitalsPulseController.dispose();
    _vitalsTempController.dispose();
    _vitalsSaturationController.dispose();
    _systemicExamController.dispose();
    _investigationsController.dispose();
    _diagnosisController.dispose();
    _diagnosisFocusNode.dispose();
    _adviceController.dispose();
    _referralToController.dispose();
    _followupDateController.dispose();
    super.dispose();
  }

  Future<void> _showCopyPreviousDialog() async {
    if (_previousVisits.isEmpty) return;

    final selected = await showDialog<PatientVisit>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Copy Previous Consultation'),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _previousVisits.length,
              itemBuilder: (context, index) {
                final visit = _previousVisits[index];
                final dateStr = visit.visitDate != null
                    ? DateFormatter.formatDate(visit.visitDate!)
                    : 'Unknown Date';
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text('Visit #${visit.visitNumber ?? (index + 1)}'),
                    subtitle: Text('Date: $dateStr\nDiagnosis: ${visit.diagnosis ?? "N/A"}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.pop(context, visit),
                  ),
                );
              },
            ),
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

    if (selected == null) return;

    // Load diagnoses for the selected visit
    List<ConsultationDiagnosis> copiedDiags = [];
    try {
      copiedDiags = await DatabaseHelper.instance.getDiagnosesForVisit(selected.id ?? 0);
    } catch (_) {}

    setState(() {
      _chiefComplaintController.text = selected.chiefComplaint ?? '';
      _historyController.text = selected.history ?? '';
      _pastHistoryController.text = selected.pastMedicalHistory ?? '';
      _systemicExamController.text = selected.systemicExamination ?? '';
      _investigationsController.text = selected.investigations ?? '';
      _adviceController.text = selected.advice ?? '';
      _referralToController.text = selected.referralTo ?? '';

      _selectedDiagnoses.clear();
      for (final diag in copiedDiags) {
        _selectedDiagnoses.add(
          ConsultationDiagnosis(
            icdCode: diag.icdCode,
            diagnosisName: diag.diagnosisName,
          ),
        );
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Previous consultation details copied! You can now edit and save as a new visit.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Sanitizes text input to prevent SQLite encoding issues or string truncations caused by NUL characters.
  String? _sanitizeInput(String? text) {
    if (text == null) return null;
    final cleaned = text.replaceAll('\x00', '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  // --- Vitals Validations ---
  String? _validateBp(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final v = val.trim();
    if (v.length > 20) return 'Max 20 chars';
    final bpRegex = RegExp(r'^\d{2,3}\s*\/\s*\d{2,3}(\s*mmHg)?$', caseSensitive: false);
    if (!bpRegex.hasMatch(v)) {
      return 'e.g. 120/80';
    }
    return null;
  }

  String? _validatePulse(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final v = val.trim();
    if (v.length > 20) return 'Max 20 chars';
    final pulseRegex = RegExp(r'^\d{2,3}(\s*bpm)?$', caseSensitive: false);
    if (!pulseRegex.hasMatch(v)) {
      return 'e.g. 72 or 72 bpm';
    }
    final match = RegExp(r'\d+').stringMatch(v);
    if (match != null) {
      final p = int.tryParse(match);
      if (p != null && (p < 20 || p > 300)) {
        return 'Range: 20-300';
      }
    }
    return null;
  }

  String? _validateTemp(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final v = val.trim();
    if (v.length > 20) return 'Max 20 chars';
    final tempRegex = RegExp(r'^\d{2,3}(\.\d{1,2})?(\s*°?[FC])?$', caseSensitive: false);
    if (!tempRegex.hasMatch(v)) {
      return 'e.g. 98.6 or 37.0';
    }
    final match = RegExp(r'\d+(\.\d+)?').stringMatch(v);
    if (match != null) {
      final t = double.tryParse(match);
      if (t != null && (t < 20 || t > 115)) {
        return 'Invalid range';
      }
    }
    return null;
  }

  String? _validateSaturation(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final v = val.trim();
    if (v.length > 20) return 'Max 20 chars';
    final satRegex = RegExp(r'^\d{2,3}(\s*%)?$', caseSensitive: false);
    if (!satRegex.hasMatch(v)) {
      return 'e.g. 98 or 98%';
    }
    final match = RegExp(r'\d+').stringMatch(v);
    if (match != null) {
      final s = int.tryParse(match);
      if (s != null && (s < 30 || s > 100)) {
        return 'Range: 30-100%';
      }
    }
    return null;
  }

  String? _validateFreeText(String? val, {int maxLength = 2500}) {
    if (val == null || val.trim().isEmpty) return null;
    if (val.length > maxLength) {
      return 'Exceeds max limit of $maxLength characters';
    }
    return null;
  }

  DateTime? _parseFollowupInput(String? input, [DateTime? baseDate]) {
    if (input == null) return null;
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    final base = baseDate ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);

    if (trimmed == 'tomorrow') {
      return today.add(const Duration(days: 1));
    }
    if (trimmed == 'next week') {
      return today.add(const Duration(days: 7));
    }
    if (trimmed == 'next month') {
      return DateTime(today.year, today.month + 1, today.day);
    }

    // Relative durations: e.g. "1 day", "2 days", "3 d", "1 week", "2 w", "2 wks", "1 month", "3 m", "1 year"
    final regex = RegExp(r'^(\d+)\s*(d|day|days|w|wk|wks|week|weeks|m|mo|mos|mon|month|months|y|yr|yrs|year|years)$');
    final match = regex.firstMatch(trimmed);
    if (match != null) {
      final count = int.tryParse(match.group(1)!);
      final unit = match.group(2)!;
      if (count != null && count > 0) {
        if (unit.startsWith('d')) {
          return today.add(Duration(days: count));
        } else if (unit.startsWith('w')) {
          return today.add(Duration(days: count * 7));
        } else if (unit.startsWith('m')) {
          return DateTime(today.year, today.month + count, today.day);
        } else if (unit.startsWith('y')) {
          return DateTime(today.year + count, today.month, today.day);
        }
      }
    }

    // Standard date formats: YYYY-MM-DD or YYYY/MM/DD
    final dateRegex1 = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$');
    final m1 = dateRegex1.firstMatch(trimmed);
    if (m1 != null) {
      final y = int.parse(m1.group(1)!);
      final m = int.parse(m1.group(2)!);
      final d = int.parse(m1.group(3)!);
      try {
        return DateTime(y, m, d);
      } catch (_) {}
    }

    // DD-MM-YYYY or DD/MM/YYYY
    final dateRegex2 = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$');
    final m2 = dateRegex2.firstMatch(trimmed);
    if (m2 != null) {
      final d = int.parse(m2.group(1)!);
      final m = int.parse(m2.group(2)!);
      final y = int.parse(m2.group(3)!);
      try {
        return DateTime(y, m, d);
      } catch (_) {}
    }

    return null;
  }

  String? _validateFollowupInput(String? val) {
    if (val == null || val.trim().isEmpty) {
      return null;
    }
    final parsed = _parseFollowupInput(val);
    if (parsed == null) {
      return 'Please enter a valid format like "1 day", "2 weeks", "1 month" or select a date.';
    }
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (parsed.isBefore(today)) {
      return 'Follow-up date cannot be in the past.';
    }
    return null;
  }

  void _showPreviousInvestigationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.biotech, color: Colors.teal.shade800),
              const SizedBox(width: 10),
              const Text('Historical Medical Investigations'),
            ],
          ),
          content: SizedBox(
            width: 700,
            height: 500,
            child: FutureBuilder<List<InvestigationMeasurement>>(
              future: widget.patient.id != null
                  ? DatabaseHelper.instance.getMeasurementsForPatient(widget.patient.id!)
                  : Future.value([]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final measurements = snapshot.data ?? [];
                if (measurements.isEmpty) {
                  return const Center(
                    child: Text('No historical structured measurements recorded for this patient.'),
                  );
                }

                return ListView.builder(
                  itemCount: measurements.length,
                  itemBuilder: (context, index) {
                    final m = measurements[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Icon(Icons.analytics, color: Colors.teal.shade800, size: 20),
                        ),
                        title: Text(m.parameterName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Ref Range: ${m.referenceRange ?? "N/A"}'),
                        trailing: Text(
                          m.valueText,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal.shade900),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveConsultation() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the errors in the consultation form before saving.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final chief = _sanitizeInput(_chiefComplaintController.text);
    final history = _sanitizeInput(_historyController.text);
    final past = _sanitizeInput(_pastHistoryController.text);
    final sysExam = _sanitizeInput(_systemicExamController.text);
    final inv = _sanitizeInput(_investigationsController.text);
    final diag = _sanitizeInput(_diagnosisController.text);
    final advice = _sanitizeInput(_adviceController.text);
    final referral = _sanitizeInput(_referralToController.text);

    final vitalsBp = _sanitizeInput(_vitalsBpController.text);
    final vitalsPulse = _sanitizeInput(_vitalsPulseController.text);
    String? vitalsTemp = _sanitizeInput(_vitalsTempController.text);
    if (vitalsTemp != null && !vitalsTemp.contains('°') && !vitalsTemp.toLowerCase().contains('c') && !vitalsTemp.toLowerCase().contains('f')) {
      vitalsTemp = '$vitalsTemp $_tempUnit';
    }
    final vitalsSat = _sanitizeInput(_vitalsSaturationController.text);
    String? followup = _sanitizeInput(_followupDateController.text);
    if (followup != null) {
      final parsed = _parseFollowupInput(followup);
      if (parsed != null) {
        followup = "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
      }
    }

    final List<ConsultationDiagnosis> diagnosesToSave = List.from(_selectedDiagnoses);
    if (diag != null && !diagnosesToSave.any((d) => d.diagnosisName == diag)) {
      diagnosesToSave.add(ConsultationDiagnosis(
        icdCode: _selectedIcdCode ?? 'Custom',
        diagnosisName: _selectedIcdName ?? diag,
      ));
    }

    // Require at least one clinical detail or vital sign
    if (chief == null &&
        history == null &&
        past == null &&
        sysExam == null &&
        inv == null &&
        diagnosesToSave.isEmpty &&
        advice == null &&
        referral == null &&
        vitalsBp == null &&
        vitalsPulse == null &&
        vitalsTemp == null &&
        vitalsSat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one clinical detail or vital sign.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a doctor before saving the consultation.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      if (widget.patient.id == null || widget.patient.id! <= 0) {
        throw Exception('Invalid patient identifier.');
      }

      if (widget.existingVisit != null) {
        // Enforce same-day midnight + 30 mins buffer edit cutoff
        if (!DateFormatter.isVisitEditable(widget.existingVisit!.visitDate, widget.existingVisit!.createdAt)) {
          throw Exception('The editing window for this consultation closed at midnight + 30 mins. Historical records cannot be modified.');
        }

        final updatedVisit = widget.existingVisit!.copyWith(
          doctorId: _selectedDoctor?.id,
          doctorSignatureVersion: _selectedDoctor?.signatureVersion ?? widget.existingVisit!.doctorSignatureVersion,
          chiefComplaint: chief,
          history: history,
          pastMedicalHistory: past,
          vitalsBp: vitalsBp,
          vitalsPulse: vitalsPulse,
          vitalsTemp: vitalsTemp,
          vitalsSaturation: vitalsSat,
          systemicExamination: sysExam,
          investigations: inv,
          diagnosis: diagnosesToSave.isNotEmpty ? diagnosesToSave.first.diagnosisName : null,
          diagnosisCode: diagnosesToSave.isNotEmpty ? diagnosesToSave.first.icdCode : null,
          advice: advice,
          referralTo: referral,
          followupDate: followup,
          diagnoses: diagnosesToSave,
          syncStatus: 'pending',
        );

        if (_selectedDoctor != null) {
          await DatabaseHelper.instance.saveSetting(
            'last_selected_doctor_${widget.currentUser.userUuid}',
            _selectedDoctor!.userUuid,
          );
        }

        final updatedRows = await DatabaseHelper.instance.updatePatientVisit(updatedVisit);
        if (updatedRows <= 0) {
          throw Exception('Failed to update consultation in database.');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Consultation Visit #${widget.existingVisit!.visitNumber ?? ""} updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
        return;
      }

      final existingVisits = await DatabaseHelper.instance.getVisitsForPatient(widget.patient.id!);
      final nextVisitNumber = existingVisits.length + 1;
      final visitUuid = 'vst-${DateTime.now().microsecondsSinceEpoch}';

      final visit = PatientVisit(
        visitUuid: visitUuid,
        patientId: widget.patient.id!,
        doctorId: _selectedDoctor?.id,
        doctorSignatureVersion: _selectedDoctor?.signatureVersion,
        visitNumber: nextVisitNumber,
        chiefComplaint: chief,
        history: history,
        pastMedicalHistory: past,
        vitalsBp: vitalsBp,
        vitalsPulse: vitalsPulse,
        vitalsTemp: vitalsTemp,
        vitalsSaturation: vitalsSat,
        systemicExamination: sysExam,
        investigations: inv,
        diagnosis: diagnosesToSave.isNotEmpty ? diagnosesToSave.first.diagnosisName : null,
        diagnosisCode: diagnosesToSave.isNotEmpty ? diagnosesToSave.first.icdCode : null,
        advice: advice,
        referralTo: referral,
        followupDate: followup,
        visitDate: DateTime.now().toString().split('.')[0],
        syncStatus: 'pending',
        diagnoses: diagnosesToSave,
      );

      // Remember last selected doctor for current user
      if (_selectedDoctor != null) {
        await DatabaseHelper.instance.saveSetting(
          'last_selected_doctor_${widget.currentUser.userUuid}',
          _selectedDoctor!.userUuid,
        );
      }

      final insertedId = await DatabaseHelper.instance.insertPatientVisit(visit);
      if (insertedId <= 0) {
        throw Exception('Failed to insert consultation into database.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clinical Consultation Visit #$nextVisitNumber saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving consultation: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _previewPrintConsultation() {
    String? tempVal = _sanitizeInput(_vitalsTempController.text);
    if (tempVal != null && !tempVal.contains('°') && !tempVal.toLowerCase().contains('c') && !tempVal.toLowerCase().contains('f')) {
      tempVal = '$tempVal $_tempUnit';
    }

    final diag = _sanitizeInput(_diagnosisController.text);
    final List<ConsultationDiagnosis> diagnosesToSave = List.from(_selectedDiagnoses);
    if (diag != null && !diagnosesToSave.any((d) => d.diagnosisName == diag)) {
      diagnosesToSave.add(ConsultationDiagnosis(
        icdCode: _selectedIcdCode ?? 'Custom',
        diagnosisName: _selectedIcdName ?? diag,
      ));
    }

    final tempVisit = PatientVisit(
      visitUuid: 'vst-draft',
      patientId: widget.patient.id ?? 0,
      doctorId: _selectedDoctor?.id,
      visitNumber: 0,
      chiefComplaint: _sanitizeInput(_chiefComplaintController.text),
      history: _sanitizeInput(_historyController.text),
      pastMedicalHistory: _sanitizeInput(_pastHistoryController.text),
      vitalsBp: _sanitizeInput(_vitalsBpController.text),
      vitalsPulse: _sanitizeInput(_vitalsPulseController.text),
      vitalsTemp: tempVal,
      vitalsSaturation: _sanitizeInput(_vitalsSaturationController.text),
      systemicExamination: _sanitizeInput(_systemicExamController.text),
      investigations: _sanitizeInput(_investigationsController.text),
      diagnosis: diagnosesToSave.isNotEmpty ? diagnosesToSave.first.diagnosisName : null,
      diagnosisCode: diagnosesToSave.isNotEmpty ? diagnosesToSave.first.icdCode : null,
      advice: _sanitizeInput(_adviceController.text),
      referralTo: _sanitizeInput(_referralToController.text),
      followupDate: () {
        final f = _sanitizeInput(_followupDateController.text);
        if (f == null) return null;
        final p = _parseFollowupInput(f);
        return p != null ? "${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}" : f;
      }(),
      visitDate: DateTime.now().toString().split(' ')[0],
      diagnoses: diagnosesToSave,
    );

    ConsultationPrintPreviewDialog.show(
      context,
      dialog: ConsultationPrintPreviewDialog.fromVisit(
        visit: tempVisit,
        patient: widget.patient,
        currentUser: _selectedDoctor ?? widget.currentUser,
        title: 'Consultation Draft Print Preview',
        isDraft: true,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal.shade700, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 3,
    int maxLength = 2500,
    String? Function(String?)? validator,
    String? fieldName,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      decoration: InputDecoration(
        hintText: hintText,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        suffixIcon: (controller is SpellCheckTextEditingController && fieldName != null)
            ? ExcludeFocus(
                child: IconButton(
                  icon: const Icon(Icons.spellcheck, color: Colors.teal),
                  tooltip: 'Spell Check $fieldName',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => SpellCheckDialog(
                        controller: controller,
                        fieldName: fieldName,
                      ),
                    );
                  },
                ),
              )
            : null,
      ),
      validator: validator ?? (v) => _validateFreeText(v, maxLength: maxLength),
    );
  }

  Future<void> _confirmDeleteCurrentVisit() async {
    if (widget.existingVisit == null || widget.existingVisit!.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Consultation Visit'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Consultation Visit #${widget.existingVisit!.visitNumber ?? ""} (${DateFormatter.formatDate(widget.existingVisit!.visitDate)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Visit'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deletePatientVisit(widget.existingVisit!.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Consultation Visit #${widget.existingVisit!.visitNumber ?? ""} deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting consultation: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final isEdit = widget.existingVisit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? 'Edit Consultation - Visit #${widget.existingVisit!.visitNumber ?? ""} (${p.fullName})'
              : 'Clinical Consultation - ${p.fullName} (ID: ${p.patientCode})',
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_hasPreviousVisits && !isEdit) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: _showCopyPreviousDialog,
              icon: const Icon(Icons.copy_all),
              label: const Text('COPY PREVIOUS'),
            ),
            const SizedBox(width: 12),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: _previewPrintConsultation,
            icon: const Icon(Icons.print),
            label: const Text('PREVIEW / PRINT DRAFT'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.teal.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: _isSaving ? null : _saveConsultation,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle),
            label: Text(
              isEdit ? 'UPDATE CONSULTATION' : 'SAVE CONSULTATION',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (isEdit) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              tooltip: 'Delete Consultation',
              onPressed: _confirmDeleteCurrentVisit,
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isEdit) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.edit_calendar, color: Colors.amber.shade900, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Editing Consultation Visit #${widget.existingVisit!.visitNumber ?? ""}',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${DateFormatter.getEditStatusText(widget.existingVisit!.visitDate, widget.existingVisit!.createdAt)} (Editable within midnight + 30m buffer).',
                                      style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Clinical Details',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                            ),
                      ),
                      const Divider(height: 24),

                      // Doctor Selector Input
                      if (_isLoadingDoctors)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        InkWell(
                          onTap: _canAssignDoctor
                              ? () async {
                                  final User? chosen = await showDialog<User>(
                                    context: context,
                                    builder: (context) => _SearchableDoctorDialog(
                                      doctors: _activeDoctors,
                                      initialDoctor: _selectedDoctor,
                                    ),
                                  );
                                  if (chosen != null) {
                                    setState(() {
                                      _selectedDoctor = chosen;
                                    });
                                  }
                                }
                              : null,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              labelText: 'Consulting Doctor *',
                              suffixIcon: Icon(
                                _canAssignDoctor ? Icons.arrow_drop_down : Icons.lock_outline,
                                color: Colors.teal.shade700,
                              ),
                              filled: !_canAssignDoctor,
                              fillColor: !_canAssignDoctor ? Colors.grey.shade100 : null,
                            ),
                            child: Text(
                              _selectedDoctor != null
                                  ? '${_selectedDoctor!.fullName} (${_selectedDoctor!.specialization ?? "General Medicine"})'
                                  : 'Select Doctor...',
                              style: TextStyle(
                                fontSize: 14,
                                color: !_canAssignDoctor ? Colors.grey.shade700 : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // a. Chief complaints
                      _buildSectionHeader('Chief Complaint', Icons.report_problem),
                      _buildFreeTextField(
                        controller: _chiefComplaintController,
                        hintText: 'Enter chief complaints...',
                        fieldName: 'Chief Complaint',
                      ),

                      // b. History
                      _buildSectionHeader('History', Icons.history_edu),
                      _buildFreeTextField(
                        controller: _historyController,
                        hintText: 'Enter history of present illness / history...',
                        maxLines: 4,
                        fieldName: 'History',
                      ),

                      // c. Past history/Medical History
                      _buildSectionHeader('Past Medical History', Icons.medical_services),
                      _buildFreeTextField(
                        controller: _pastHistoryController,
                        hintText: 'Enter past medical history, chronic conditions, surgeries, allergies...',
                        maxLines: 4,
                        fieldName: 'Past Medical History',
                      ),

                      // d. Vitals signs (BP, Pulse, Temp. Saturation) entry separated.
                      _buildSectionHeader('Vitals', Icons.monitor_heart),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _vitalsBpController,
                              validator: _validateBp,
                              decoration: const InputDecoration(
                                labelText: 'BP (e.g. 120/80 mmHg)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _vitalsPulseController,
                              validator: _validatePulse,
                              decoration: const InputDecoration(
                                labelText: 'Pulse (e.g. 72 bpm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _vitalsTempController,
                                    validator: _validateTemp,
                                    decoration: InputDecoration(
                                      labelText: 'Temp (e.g. 98.6 $_tempUnit)',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                DropdownButton<String>(
                                  value: _tempUnit,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(value: '°F', child: Text('°F')),
                                    DropdownMenuItem(value: '°C', child: Text('°C')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _tempUnit = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _vitalsSaturationController,
                              validator: _validateSaturation,
                              decoration: const InputDecoration(
                                labelText: 'Saturation (e.g. 98%)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // e. Systemic Examination
                      _buildSectionHeader('Systemic Examination', Icons.accessibility_new),
                      _buildFreeTextField(
                        controller: _systemicExamController,
                        hintText: 'Enter systemic examination findings...',
                        maxLines: 4,
                        fieldName: 'Systemic Examination',
                      ),

                      // f. Investigations
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('Investigations', Icons.science),
                          TextButton.icon(
                            onPressed: _showPreviousInvestigationsDialog,
                            icon: const Icon(Icons.biotech, size: 18),
                            label: const Text('View Historical Test Intelligence'),
                          ),
                        ],
                      ),
                      _buildFreeTextField(
                        controller: _investigationsController,
                        hintText: 'Enter investigations / lab test details...',
                        maxLines: 3,
                        fieldName: 'Investigations',
                      ),

                      // g. Diagnosis
                      _buildSectionHeader('Diagnosis', Icons.search),
                      Row(
                        children: [
                          Expanded(
                            child: RawAutocomplete<Map<String, dynamic>>(
                              textEditingController: _diagnosisController,
                              focusNode: _diagnosisFocusNode,
                              optionsBuilder: (TextEditingValue textEditingValue) async {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<Map<String, dynamic>>.empty();
                                }
                                return await DatabaseHelper.instance.searchIcd10Diagnoses(textEditingValue.text);
                              },
                              displayStringForOption: (Map<String, dynamic> option) {
                                return option['name_en'] ?? '';
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 500,
                                      constraints: const BoxConstraints(maxHeight: 250),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (BuildContext context, int index) {
                                          final option = options.elementAt(index);
                                          final code = option['code'] ?? '';
                                          final nameEn = option['name_en'] ?? '';
                                          final nameId = option['name_id'] ?? '';
                                          return ListTile(
                                            title: RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '$code - ',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.teal.shade700,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: nameEn,
                                                    style: const TextStyle(color: Colors.black87),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            subtitle: nameId.trim().isNotEmpty
                                                ? Text(
                                                    nameId,
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontSize: 12,
                                                    ),
                                                  )
                                                : null,
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                return TextFormField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Type to search ICD-10 diagnoses, or enter custom...',
                                    alignLabelWithHint: true,
                                    border: const OutlineInputBorder(),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    suffixIcon: textEditingController.text.isNotEmpty
                                        ? ExcludeFocus(
                                            child: IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                setState(() {
                                                  textEditingController.clear();
                                                  _selectedIcdCode = null;
                                                  _selectedIcdName = null;
                                                });
                                              },
                                            ),
                                          )
                                        : null,
                                  ),
                                );
                              },
                              onSelected: (Map<String, dynamic> selection) {
                                setState(() {
                                  final code = selection['code'] ?? '';
                                  final name = selection['name_en'] ?? '';
                                  if (!_selectedDiagnoses.any((d) => d.icdCode == code)) {
                                    _selectedDiagnoses.add(ConsultationDiagnosis(
                                      icdCode: code,
                                      diagnosisName: name,
                                    ));
                                  }
                                  _diagnosisController.clear();
                                  _selectedIcdCode = null;
                                  _selectedIcdName = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onPressed: () {
                              final text = _diagnosisController.text.trim();
                              if (text.isNotEmpty) {
                                setState(() {
                                  if (!_selectedDiagnoses.any((d) => d.diagnosisName.toLowerCase() == text.toLowerCase())) {
                                    _selectedDiagnoses.add(ConsultationDiagnosis(
                                      icdCode: _selectedIcdCode ?? 'Custom',
                                      diagnosisName: _selectedIcdName ?? text,
                                    ));
                                  }
                                  _diagnosisController.clear();
                                  _selectedIcdCode = null;
                                  _selectedIcdName = null;
                                });
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                          ),
                        ],
                      ),

                      if (_selectedDiagnoses.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(
                            children: _selectedDiagnoses.map((diag) {
                              return ListTile(
                                dense: true,
                                title: Text(
                                  diag.icdCode == 'Custom'
                                      ? diag.diagnosisName
                                      : '${diag.icdCode} - ${diag.diagnosisName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _selectedDiagnoses.remove(diag);
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      // h. Advice
                      _buildSectionHeader('Advice', Icons.recommend),
                      _buildFreeTextField(
                        controller: _adviceController,
                        hintText: 'Enter advice, prescriptions, dietary / lifestyle recommendations...',
                        maxLines: 4,
                        fieldName: 'Advice',
                      ),

                      // i. Referral to…
                      _buildSectionHeader('Referral', Icons.outbox),
                      _buildFreeTextField(
                        controller: _referralToController,
                        hintText: 'Enter referral details...',
                        maxLines: 2,
                        fieldName: 'Referral',
                      ),

                      // j. Follow-up
                      _buildSectionHeader('Follow-up', Icons.calendar_month),
                      TextFormField(
                        controller: _followupDateController,
                        decoration: InputDecoration(
                          labelText: 'Follow-up Duration / Date (Optional)',
                          hintText: 'e.g. 1 day, 2 weeks, 1 month, or select date',
                          prefixIcon: const Icon(Icons.event_repeat),
                          suffixIcon: ExcludeFocus(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_followupDateController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    tooltip: 'Clear',
                                    onPressed: () {
                                      setState(() {
                                        _followupDateController.clear();
                                      });
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.calendar_today, color: Colors.teal),
                                  tooltip: 'Pick Date from Calendar',
                                  onPressed: () async {
                                    final currentParsed = _parseFollowupInput(_followupDateController.text);
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: (currentParsed != null && !currentParsed.isBefore(DateTime.now()))
                                          ? currentParsed
                                          : DateTime.now().add(const Duration(days: 7)),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 730)),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _followupDateController.text =
                                            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: _validateFollowupInput,
                      ),

                      // Live Date Preview
                      Builder(
                        builder: (context) {
                          final parsedDate = _parseFollowupInput(_followupDateController.text);
                          if (parsedDate == null) return const SizedBox.shrink();

                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final daysFromNow = parsedDate.difference(today).inDays;
                          final formattedDate = DateFormatter.formatDate(parsedDate.toIso8601String());
                          final weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                          final weekday = weekdayNames[parsedDate.weekday - 1];

                          return Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_available, color: Colors.teal.shade800, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(color: Colors.teal.shade900, fontSize: 13),
                                      children: [
                                        const TextSpan(text: 'Calculated Date: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                        TextSpan(
                                          text: '$formattedDate ($weekday)',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (daysFromNow > 0)
                                          TextSpan(
                                            text: ' • in $daysFromNow day${daysFromNow == 1 ? "" : "s"}',
                                            style: TextStyle(color: Colors.teal.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                                          )
                                        else if (daysFromNow == 0)
                                          TextSpan(
                                            text: ' • Today',
                                            style: TextStyle(color: Colors.teal.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Quick Duration Suggestions
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Quick presets:',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                            ...[
                              '3 days',
                              '5 days',
                              '1 week',
                              '2 weeks',
                              '1 month',
                              '3 months',
                              '6 months',
                            ].map((preset) {
                              final isSelected = _followupDateController.text.trim().toLowerCase() == preset;
                              return ActionChip(
                                label: Text(preset),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.teal.shade900 : Colors.black87,
                                ),
                                backgroundColor: isSelected ? Colors.teal.shade100 : Colors.grey.shade100,
                                side: BorderSide(
                                  color: isSelected ? Colors.teal.shade400 : Colors.grey.shade300,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                onPressed: () {
                                  setState(() {
                                    _followupDateController.text = preset;
                                  });
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _isSaving ? null : _saveConsultation,
                                icon: _isSaving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.save),
                                label: const Text('SAVE CLINICAL CONSULTATION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.teal.shade700, width: 2),
                                  foregroundColor: Colors.teal.shade700,
                                ),
                                onPressed: _isSaving ? null : _previewPrintConsultation,
                                icon: const Icon(Icons.print),
                                label: const Text('PRINT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
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

class _SearchableDoctorDialog extends StatefulWidget {
  final List<User> doctors;
  final User? initialDoctor;

  const _SearchableDoctorDialog({
    required this.doctors,
    this.initialDoctor,
  });

  @override
  State<_SearchableDoctorDialog> createState() => _SearchableDoctorDialogState();
}

class _SearchableDoctorDialogState extends State<_SearchableDoctorDialog> {
  late List<User> _filteredDoctors;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredDoctors = widget.doctors;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDoctors = widget.doctors.where((doc) {
        final name = doc.fullName.toLowerCase();
        final spec = (doc.specialization ?? '').toLowerCase();
        final license = (doc.licenseNumber ?? '').toLowerCase();
        return name.contains(query) || spec.contains(query) || license.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Consulting Doctor'),
      content: SizedBox(
        width: 400,
        height: 350,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Doctor...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredDoctors.isEmpty
                  ? const Center(child: Text('No doctors match your search.'))
                  : ListView.builder(
                      itemCount: _filteredDoctors.length,
                      itemBuilder: (context, index) {
                        final doc = _filteredDoctors[index];
                        final isSelected = widget.initialDoctor?.id == doc.id;
                        return ListTile(
                          selected: isSelected,
                          selectedColor: Colors.teal.shade800,
                          selectedTileColor: Colors.teal.shade50,
                          title: Text(doc.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${doc.specialization ?? "General Medicine"} | License: ${doc.licenseNumber ?? "N/A"}'),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.teal) : null,
                          onTap: () => Navigator.pop(context, doc),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
