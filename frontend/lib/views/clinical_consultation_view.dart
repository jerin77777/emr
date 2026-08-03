import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class ClinicalConsultationView extends StatefulWidget {
  final Patient patient;
  final User currentUser;

  const ClinicalConsultationView({
    super.key,
    required this.patient,
    required this.currentUser,
  });

  @override
  State<ClinicalConsultationView> createState() => _ClinicalConsultationViewState();
}

class _ClinicalConsultationViewState extends State<ClinicalConsultationView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // 1. Chief Complaint & HPI
  final _chiefComplaintController = TextEditingController();
  final _hpiDurationController = TextEditingController();
  String _hpiSeverity = 'Moderate';
  final _hpiSymptomsController = TextEditingController();
  final _hpiProgressionController = TextEditingController();
  final _hpiPreviousTreatmentsController = TextEditingController();

  // 2. Past Medical History (PMH)
  final _pmhChronicController = TextEditingController();
  final _pmhDiseasesController = TextEditingController();
  final _pmhSurgeriesController = TextEditingController();
  final _pmhAllergiesController = TextEditingController();
  final _pmhMedicationsController = TextEditingController();

  // 3. Vital Signs
  final _systolicBpController = TextEditingController();
  final _diastolicBpController = TextEditingController();
  final _pulseController = TextEditingController();
  final _tempController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  double? _computedBmi;

  // 4. Systemic Examination
  final _examGeneralController = TextEditingController();
  final _examCvsController = TextEditingController();
  final _examRespController = TextEditingController();
  final _examAbdomenController = TextEditingController();
  final _examCnsController = TextEditingController();
  final _examMusculoskeletalController = TextEditingController();

  // 5. Investigations
  final List<Map<String, String>> _investigations = [];
  final _testNameController = TextEditingController();
  String _invCategory = 'Blood Test';
  final _invNotesController = TextEditingController();

  // 6. Diagnoses
  final List<Map<String, String>> _diagnoses = [];
  final _diagNameController = TextEditingController();
  final _icdCodeController = TextEditingController();
  String _diagType = 'Primary';
  final _diagNotesController = TextEditingController();

  // 7. Advice & Followup
  final _adviceLifestyleController = TextEditingController();
  final _adviceDietaryController = TextEditingController();
  final _adviceFollowupInstructionsController = TextEditingController();
  final _adviceMedicationInstructionsController = TextEditingController();
  final _followupDateController = TextEditingController();

  // 8. Prescriptions
  final List<Map<String, String>> _prescriptions = [];
  final _medNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _durationController = TextEditingController();
  final _rxInstructionsController = TextEditingController();

  // 9. Referrals
  final List<Map<String, String>> _referrals = [];
  final _providerNameController = TextEditingController();
  String _referralType = 'Specialist';
  final _referralReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chiefComplaintController.dispose();
    _hpiDurationController.dispose();
    _hpiSymptomsController.dispose();
    _hpiProgressionController.dispose();
    _hpiPreviousTreatmentsController.dispose();

    _pmhChronicController.dispose();
    _pmhDiseasesController.dispose();
    _pmhSurgeriesController.dispose();
    _pmhAllergiesController.dispose();
    _pmhMedicationsController.dispose();

    _systolicBpController.dispose();
    _diastolicBpController.dispose();
    _pulseController.dispose();
    _tempController.dispose();
    _spo2Controller.dispose();
    _weightController.dispose();
    _heightController.dispose();

    _examGeneralController.dispose();
    _examCvsController.dispose();
    _examRespController.dispose();
    _examAbdomenController.dispose();
    _examCnsController.dispose();
    _examMusculoskeletalController.dispose();

    _testNameController.dispose();
    _invNotesController.dispose();
    _diagNameController.dispose();
    _icdCodeController.dispose();
    _diagNotesController.dispose();

    _adviceLifestyleController.dispose();
    _adviceDietaryController.dispose();
    _adviceFollowupInstructionsController.dispose();
    _adviceMedicationInstructionsController.dispose();
    _followupDateController.dispose();

    _medNameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    _rxInstructionsController.dispose();

    _providerNameController.dispose();
    _referralReasonController.dispose();

    super.dispose();
  }

  void _calculateBmi() {
    final w = double.tryParse(_weightController.text);
    final h = double.tryParse(_heightController.text);
    if (w != null && h != null && h > 0) {
      final hMeter = h / 100.0;
      setState(() {
        _computedBmi = w / (hMeter * hMeter);
      });
    } else {
      setState(() {
        _computedBmi = null;
      });
    }
  }

  Future<void> _saveConsultation() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out required fields in the consultation form.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final existingVisits = await DatabaseHelper.instance.getVisitsForPatient(widget.patient.id!);
      final nextVisitNumber = existingVisits.length + 1;
      final visitUuid = 'vst-${DateTime.now().millisecondsSinceEpoch}';

      // 1. Save Visit Record
      final visit = PatientVisit(
        visitUuid: visitUuid,
        patientId: widget.patient.id!,
        doctorId: widget.currentUser.id,
        visitNumber: nextVisitNumber,
        chiefComplaint: _chiefComplaintController.text.trim().isEmpty ? null : _chiefComplaintController.text.trim(),
        hpiDuration: _hpiDurationController.text.trim().isEmpty ? null : _hpiDurationController.text.trim(),
        hpiSeverity: _hpiSeverity,
        hpiAssociatedSymptoms: _hpiSymptomsController.text.trim().isEmpty ? null : _hpiSymptomsController.text.trim(),
        hpiProgression: _hpiProgressionController.text.trim().isEmpty ? null : _hpiProgressionController.text.trim(),
        hpiPreviousTreatments: _hpiPreviousTreatmentsController.text.trim().isEmpty ? null : _hpiPreviousTreatmentsController.text.trim(),
        pmhChronicIllness: _pmhChronicController.text.trim().isEmpty ? null : _pmhChronicController.text.trim(),
        pmhPreviousDiseases: _pmhDiseasesController.text.trim().isEmpty ? null : _pmhDiseasesController.text.trim(),
        pmhSurgeries: _pmhSurgeriesController.text.trim().isEmpty ? null : _pmhSurgeriesController.text.trim(),
        pmhAllergies: _pmhAllergiesController.text.trim().isEmpty ? null : _pmhAllergiesController.text.trim(),
        pmhCurrentMedications: _pmhMedicationsController.text.trim().isEmpty ? null : _pmhMedicationsController.text.trim(),
        examGeneral: _examGeneralController.text.trim().isEmpty ? null : _examGeneralController.text.trim(),
        examCvs: _examCvsController.text.trim().isEmpty ? null : _examCvsController.text.trim(),
        examRespiratory: _examRespController.text.trim().isEmpty ? null : _examRespController.text.trim(),
        examAbdomen: _examAbdomenController.text.trim().isEmpty ? null : _examAbdomenController.text.trim(),
        examCns: _examCnsController.text.trim().isEmpty ? null : _examCnsController.text.trim(),
        examMusculoskeletal: _examMusculoskeletalController.text.trim().isEmpty ? null : _examMusculoskeletalController.text.trim(),
        adviceLifestyle: _adviceLifestyleController.text.trim().isEmpty ? null : _adviceLifestyleController.text.trim(),
        adviceDietary: _adviceDietaryController.text.trim().isEmpty ? null : _adviceDietaryController.text.trim(),
        adviceFollowupInstructions: _adviceFollowupInstructionsController.text.trim().isEmpty ? null : _adviceFollowupInstructionsController.text.trim(),
        adviceMedicationInstructions: _adviceMedicationInstructionsController.text.trim().isEmpty ? null : _adviceMedicationInstructionsController.text.trim(),
        followupDate: _followupDateController.text.trim().isEmpty ? null : _followupDateController.text.trim(),
        syncStatus: 'pending',
      );

      final visitId = await DatabaseHelper.instance.insertPatientVisit(visit);

      // 2. Save Vital Signs
      final sys = int.tryParse(_systolicBpController.text);
      final dia = int.tryParse(_diastolicBpController.text);
      final pulse = int.tryParse(_pulseController.text);
      final temp = double.tryParse(_tempController.text);
      final spo2 = double.tryParse(_spo2Controller.text);
      final weight = double.tryParse(_weightController.text);
      final height = double.tryParse(_heightController.text);

      if (sys != null || dia != null || pulse != null || temp != null || weight != null) {
        final vitals = VitalSign(
          visitId: visitId,
          patientId: widget.patient.id!,
          systolicBp: sys,
          diastolicBp: dia,
          pulseRate: pulse,
          temperatureCelsius: temp,
          oxygenSaturation: spo2,
          weightKg: weight,
          heightCm: height,
          bmi: _computedBmi,
          syncStatus: 'pending',
        );
        await DatabaseHelper.instance.insertVitalSign(vitals);
      }

      // 3. Save Investigations
      for (final inv in _investigations) {
        final item = Investigation(
          visitId: visitId,
          patientId: widget.patient.id!,
          category: inv['category']!,
          testName: inv['testName']!,
          findingsNotes: inv['notes'],
          syncStatus: 'pending',
        );
        await DatabaseHelper.instance.insertInvestigation(item);
      }

      // 4. Save Diagnoses
      for (final diag in _diagnoses) {
        final item = Diagnosis(
          visitId: visitId,
          patientId: widget.patient.id!,
          icdCode: diag['icdCode'],
          diagnosisName: diag['name']!,
          diagnosisType: diag['type']!,
          notes: diag['notes'],
          syncStatus: 'pending',
        );
        await DatabaseHelper.instance.insertDiagnosis(item);
      }

      // 5. Save Prescriptions
      for (final rx in _prescriptions) {
        final item = Prescription(
          visitId: visitId,
          patientId: widget.patient.id!,
          medicineName: rx['name']!,
          dosage: rx['dosage']!,
          frequency: rx['frequency']!,
          duration: rx['duration'],
          instructions: rx['instructions'],
          syncStatus: 'pending',
        );
        await DatabaseHelper.instance.insertPrescription(item);
      }

      // 6. Save Referrals
      for (final ref in _referrals) {
        final item = Referral(
          visitId: visitId,
          patientId: widget.patient.id!,
          referredToType: ref['type']!,
          providerName: ref['provider']!,
          reason: ref['reason'],
          syncStatus: 'pending',
        );
        await DatabaseHelper.instance.insertReferral(item);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Consultation Visit #$nextVisitNumber saved successfully!')),
        );
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;

    return Scaffold(
      appBar: AppBar(
        title: Text('Clinical Consultation - ${p.fullName} (${p.patientCode})'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
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
            label: const Text('SAVE CONSULTATION', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.teal.shade900,
              unselectedLabelColor: Colors.grey.shade700,
              indicatorColor: Colors.teal.shade700,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.notes), text: '1. Complaints & HPI'),
                Tab(icon: Icon(Icons.history), text: '2. Medical History (PMH)'),
                Tab(icon: Icon(Icons.monitor_heart), text: '3. Vitals & Examination'),
                Tab(icon: Icon(Icons.biotech), text: '4. Investigations & Diagnoses'),
                Tab(icon: Icon(Icons.medication), text: '5. Prescriptions'),
                Tab(icon: Icon(Icons.recommend), text: '6. Advice & Referrals'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildComplaintsHpiTab(),
                  _buildPmhTab(),
                  _buildVitalsExamTab(),
                  _buildInvestigationsDiagnosesTab(),
                  _buildPrescriptionsTab(),
                  _buildAdviceReferralsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Complaints & HPI
  Widget _buildComplaintsHpiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chief Complaint *', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _chiefComplaintController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe patient presenting complaints (e.g. Fever, dry cough for 3 days...)',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Chief complaint required' : null,
          ),
          const SizedBox(height: 24),
          Text('History of Present Illness (HPI)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _hpiDurationController,
                  decoration: const InputDecoration(labelText: 'Duration (e.g. 3 days)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _hpiSeverity,
                  decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Mild', child: Text('Mild')),
                    DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                    DropdownMenuItem(value: 'Severe', child: Text('Severe')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _hpiSeverity = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _hpiSymptomsController,
            decoration: const InputDecoration(labelText: 'Associated Symptoms (e.g. Headache, fatigue)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _hpiProgressionController,
            decoration: const InputDecoration(labelText: 'Progression (e.g. Gradually worsening)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _hpiPreviousTreatmentsController,
            decoration: const InputDecoration(labelText: 'Previous Treatments Taken', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  // 2. Past Medical History
  Widget _buildPmhTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Past Medical History (PMH)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pmhChronicController,
            decoration: const InputDecoration(labelText: 'Chronic Illnesses (e.g. Hypertension, Diabetes)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pmhDiseasesController,
            decoration: const InputDecoration(labelText: 'Previous Major Diseases', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pmhSurgeriesController,
            decoration: const InputDecoration(labelText: 'Past Surgeries & Procedures', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pmhAllergiesController,
            decoration: const InputDecoration(labelText: 'Known Allergies (Drug/Food)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pmhMedicationsController,
            decoration: const InputDecoration(labelText: 'Current Routine Medications', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  // 3. Vitals & Examination
  Widget _buildVitalsExamTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vital Signs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _systolicBpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Systolic BP (mmHg)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _diastolicBpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Diastolic BP (mmHg)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _pulseController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pulse Rate (bpm)', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _tempController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Temp (°C)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _spo2Controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'SpO2 (%)', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _calculateBmi(),
                  decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _calculateBmi(),
                  decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Text(
                    _computedBmi == null ? 'BMI: N/A' : 'BMI: ${_computedBmi!.toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 36),
          Text('Systemic Clinical Examination', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _examGeneralController,
            decoration: const InputDecoration(labelText: 'General Examination (Conscious, Oriented, Pallor...)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _examCvsController,
                  decoration: const InputDecoration(labelText: 'CVS (S1, S2, Murmurs)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _examRespController,
                  decoration: const InputDecoration(labelText: 'Respiratory System', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _examAbdomenController,
                  decoration: const InputDecoration(labelText: 'Abdomen (Soft, Non-tender...)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _examCnsController,
                  decoration: const InputDecoration(labelText: 'Central Nervous System', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _examMusculoskeletalController,
            decoration: const InputDecoration(labelText: 'Musculoskeletal System', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  // 4. Investigations & Diagnoses
  Widget _buildInvestigationsDiagnosesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Diagnoses Section
          Text('Diagnosis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _diagNameController,
                          decoration: const InputDecoration(labelText: 'Diagnosis Name (e.g. Acute URTI)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _icdCodeController,
                          decoration: const InputDecoration(labelText: 'ICD Code (e.g. J06.9)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          initialValue: _diagType,
                          decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Primary', child: Text('Primary')),
                            DropdownMenuItem(value: 'Secondary', child: Text('Secondary')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _diagType = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _diagNotesController,
                          decoration: const InputDecoration(labelText: 'Clinical Notes', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                        onPressed: () {
                          if (_diagNameController.text.trim().isNotEmpty) {
                            setState(() {
                              _diagnoses.add({
                                'name': _diagNameController.text.trim(),
                                'icdCode': _icdCodeController.text.trim(),
                                'type': _diagType,
                                'notes': _diagNotesController.text.trim(),
                              });
                              _diagNameController.clear();
                              _icdCodeController.clear();
                              _diagNotesController.clear();
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Diagnosis'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_diagnoses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _diagnoses.map((d) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: d['type'] == 'Primary' ? Colors.red : Colors.orange,
                    child: Text(d['type']![0], style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                  label: Text('${d['name']} ${d['icdCode']!.isNotEmpty ? "(${d['icdCode']})" : ""}'),
                  onDeleted: () {
                    setState(() => _diagnoses.remove(d));
                  },
                );
              }).toList(),
            ),
          ],
          const Divider(height: 36),
          // Investigations Section
          Text('Order Investigations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _invCategory,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Blood Test', child: Text('Blood Test')),
                        DropdownMenuItem(value: 'Urine Test', child: Text('Urine Test')),
                        DropdownMenuItem(value: 'ECG', child: Text('ECG')),
                        DropdownMenuItem(value: 'X-Ray', child: Text('X-Ray')),
                        DropdownMenuItem(value: 'CT Scan', child: Text('CT Scan')),
                        DropdownMenuItem(value: 'MRI', child: Text('MRI')),
                        DropdownMenuItem(value: 'Ultrasound', child: Text('Ultrasound')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _invCategory = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _testNameController,
                      decoration: const InputDecoration(labelText: 'Test Name (e.g. CBC, Lipid Profile)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _invNotesController,
                      decoration: const InputDecoration(labelText: 'Notes / Instructions', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                    onPressed: () {
                      if (_testNameController.text.trim().isNotEmpty) {
                        setState(() {
                          _investigations.add({
                            'category': _invCategory,
                            'testName': _testNameController.text.trim(),
                            'notes': _invNotesController.text.trim(),
                          });
                          _testNameController.clear();
                          _invNotesController.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Test'),
                  ),
                ],
              ),
            ),
          ),
          if (_investigations.isNotEmpty) ...[
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _investigations.length,
              itemBuilder: (context, index) {
                final item = _investigations[index];
                return Card(
                  child: ListTile(
                    leading: Chip(label: Text(item['category']!)),
                    title: Text(item['testName']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(item['notes'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => _investigations.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // 5. Prescriptions
  Widget _buildPrescriptionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prescribe Medications', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _medNameController,
                          decoration: const InputDecoration(labelText: 'Medicine Name (e.g. Paracetamol)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _dosageController,
                          decoration: const InputDecoration(labelText: 'Dosage (e.g. 650mg)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _frequencyController,
                          decoration: const InputDecoration(labelText: 'Frequency (e.g. TDS)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _durationController,
                          decoration: const InputDecoration(labelText: 'Duration (e.g. 5 days)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rxInstructionsController,
                          decoration: const InputDecoration(labelText: 'Instructions (e.g. Take after meals)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                        onPressed: () {
                          if (_medNameController.text.trim().isNotEmpty) {
                            setState(() {
                              _prescriptions.add({
                                'name': _medNameController.text.trim(),
                                'dosage': _dosageController.text.trim(),
                                'frequency': _frequencyController.text.trim(),
                                'duration': _durationController.text.trim(),
                                'instructions': _rxInstructionsController.text.trim(),
                              });
                              _medNameController.clear();
                              _dosageController.clear();
                              _frequencyController.clear();
                              _durationController.clear();
                              _rxInstructionsController.clear();
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Rx'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_prescriptions.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No medications added to prescription list yet.')))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _prescriptions.length,
              itemBuilder: (context, index) {
                final rx = _prescriptions[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.teal.shade100, child: Icon(Icons.medication, color: Colors.teal.shade900)),
                    title: Text('${rx['name']} ${rx['dosage']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Frequency: ${rx['frequency']} | Duration: ${rx['duration']}\nInstructions: ${rx['instructions']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => _prescriptions.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // 6. Advice & Referrals
  Widget _buildAdviceReferralsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Doctor Recommendations & Advice', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _adviceLifestyleController,
            decoration: const InputDecoration(labelText: 'Lifestyle Advice (e.g. Rest, hydration)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _adviceDietaryController,
            decoration: const InputDecoration(labelText: 'Dietary Advice (e.g. Low salt diet)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _adviceFollowupInstructionsController,
            decoration: const InputDecoration(labelText: 'Follow-up Instructions', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _followupDateController,
            readOnly: true,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 3)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _followupDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                });
              }
            },
            decoration: const InputDecoration(
              labelText: 'Follow-up Date',
              prefixIcon: Icon(Icons.calendar_month),
              suffixIcon: Icon(Icons.arrow_drop_down),
              border: OutlineInputBorder(),
            ),
          ),
          const Divider(height: 36),
          Text('Patient Referrals', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _referralType,
                      decoration: const InputDecoration(labelText: 'Referred To', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Specialist', child: Text('Specialist')),
                        DropdownMenuItem(value: 'Hospital', child: Text('Hospital')),
                        DropdownMenuItem(value: 'Diagnostic Center', child: Text('Diagnostic Center')),
                        DropdownMenuItem(value: 'Physiotherapy', child: Text('Physiotherapy')),
                        DropdownMenuItem(value: 'Other Provider', child: Text('Other Provider')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _referralType = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _providerNameController,
                      decoration: const InputDecoration(labelText: 'Provider / Hospital Name', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _referralReasonController,
                      decoration: const InputDecoration(labelText: 'Reason for Referral', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                    onPressed: () {
                      if (_providerNameController.text.trim().isNotEmpty) {
                        setState(() {
                          _referrals.add({
                            'type': _referralType,
                            'provider': _providerNameController.text.trim(),
                            'reason': _referralReasonController.text.trim(),
                          });
                          _providerNameController.clear();
                          _referralReasonController.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Referral'),
                  ),
                ],
              ),
            ),
          ),
          if (_referrals.isNotEmpty) ...[
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _referrals.length,
              itemBuilder: (context, index) {
                final ref = _referrals[index];
                return Card(
                  child: ListTile(
                    leading: Chip(label: Text(ref['type']!)),
                    title: Text(ref['provider']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(ref['reason'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => _referrals.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
