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

class _ClinicalConsultationViewState extends State<ClinicalConsultationView> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers for free text clinical headings
  final _chiefComplaintController = TextEditingController();
  final _historyController = TextEditingController();
  final _pastHistoryController = TextEditingController();

  // Vital signs (entry separated)
  final _vitalsBpController = TextEditingController();
  final _vitalsPulseController = TextEditingController();
  final _vitalsTempController = TextEditingController();
  final _vitalsSaturationController = TextEditingController();

  final _systemicExamController = TextEditingController();
  final _investigationsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _adviceController = TextEditingController();
  final _referralToController = TextEditingController();
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
    _adviceController.dispose();
    _referralToController.dispose();
    _followupDateController.dispose();
    super.dispose();
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

      final visit = PatientVisit(
        visitUuid: visitUuid,
        patientId: widget.patient.id!,
        doctorId: widget.currentUser.id,
        visitNumber: nextVisitNumber,
        chiefComplaint: _chiefComplaintController.text.trim().isEmpty ? null : _chiefComplaintController.text.trim(),
        history: _historyController.text.trim().isEmpty ? null : _historyController.text.trim(),
        pastMedicalHistory: _pastHistoryController.text.trim().isEmpty ? null : _pastHistoryController.text.trim(),
        vitalsBp: _vitalsBpController.text.trim().isEmpty ? null : _vitalsBpController.text.trim(),
        vitalsPulse: _vitalsPulseController.text.trim().isEmpty ? null : _vitalsPulseController.text.trim(),
        vitalsTemp: _vitalsTempController.text.trim().isEmpty ? null : _vitalsTempController.text.trim(),
        vitalsSaturation: _vitalsSaturationController.text.trim().isEmpty ? null : _vitalsSaturationController.text.trim(),
        systemicExamination: _systemicExamController.text.trim().isEmpty ? null : _systemicExamController.text.trim(),
        investigations: _investigationsController.text.trim().isEmpty ? null : _investigationsController.text.trim(),
        diagnosis: _diagnosisController.text.trim().isEmpty ? null : _diagnosisController.text.trim(),
        advice: _adviceController.text.trim().isEmpty ? null : _adviceController.text.trim(),
        referralTo: _referralToController.text.trim().isEmpty ? null : _referralToController.text.trim(),
        followupDate: _followupDateController.text.trim().isEmpty ? null : _followupDateController.text.trim(),
        syncStatus: 'pending',
      );

      await DatabaseHelper.instance.insertPatientVisit(visit);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clinical Consultation Visit #$nextVisitNumber saved successfully!')),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: validator,
    );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              maxWidth: 900,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clinical Details',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                            ),
                      ),
                      const Divider(height: 24),

                      // a. Chief complaints
                      _buildSectionHeader('a. Chief complaints', Icons.report_problem),
                      _buildFreeTextField(
                        controller: _chiefComplaintController,
                        hintText: 'Enter chief complaints...',
                      ),

                      // b. History
                      _buildSectionHeader('b. History', Icons.history_edu),
                      _buildFreeTextField(
                        controller: _historyController,
                        hintText: 'Enter history of present illness / history...',
                        maxLines: 4,
                      ),

                      // c. Past history/Medical History
                      _buildSectionHeader('c. Past history/Medical History', Icons.medical_services),
                      _buildFreeTextField(
                        controller: _pastHistoryController,
                        hintText: 'Enter past medical history, chronic conditions, surgeries, allergies...',
                        maxLines: 4,
                      ),

                      // d. Vitals signs (BP, Pulse, Temp. Saturation) entry separated.
                      _buildSectionHeader('d. Vital signs', Icons.monitor_heart),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _vitalsBpController,
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
                              decoration: const InputDecoration(
                                labelText: 'Pulse (e.g. 72 bpm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _vitalsTempController,
                              decoration: const InputDecoration(
                                labelText: 'Temp (e.g. 98.6 °F)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _vitalsSaturationController,
                              decoration: const InputDecoration(
                                labelText: 'Saturation (e.g. 98%)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // e. Systemic Examination
                      _buildSectionHeader('e. Systemic Examination', Icons.accessibility_new),
                      _buildFreeTextField(
                        controller: _systemicExamController,
                        hintText: 'Enter systemic examination findings...',
                        maxLines: 4,
                      ),

                      // f. Investigations
                      _buildSectionHeader('f. Investigations', Icons.science),
                      _buildFreeTextField(
                        controller: _investigationsController,
                        hintText: 'Enter investigations / lab test details...',
                        maxLines: 3,
                      ),

                      // g. Diagnosis
                      _buildSectionHeader('g. Diagnosis', Icons.search_off),
                      _buildFreeTextField(
                        controller: _diagnosisController,
                        hintText: 'Enter diagnosis...',
                        maxLines: 3,
                      ),

                      // h. Advice
                      _buildSectionHeader('h. Advice', Icons.recommend),
                      _buildFreeTextField(
                        controller: _adviceController,
                        hintText: 'Enter advice, prescriptions, dietary / lifestyle recommendations...',
                        maxLines: 4,
                      ),

                      // i. Referral to…
                      _buildSectionHeader('i. Referral to…', Icons.outbox),
                      _buildFreeTextField(
                        controller: _referralToController,
                        hintText: 'Enter referral details...',
                        maxLines: 2,
                      ),

                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _followupDateController,
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() {
                              _followupDateController.text =
                                  "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Follow-up Date (Optional)',
                          prefixIcon: Icon(Icons.calendar_month),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
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
                          label: const Text('SAVE CLINICAL CONSULTATION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
