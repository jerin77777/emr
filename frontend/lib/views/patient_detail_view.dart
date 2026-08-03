import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import 'clinical_consultation_view.dart';
import 'billing_view.dart';

class PatientDetailView extends StatefulWidget {
  final Patient patient;
  final User currentUser;

  const PatientDetailView({
    super.key,
    required this.patient,
    required this.currentUser,
  });

  @override
  State<PatientDetailView> createState() => _PatientDetailViewState();
}

class _PatientDetailViewState extends State<PatientDetailView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<PatientVisit>> _visitsFuture;
  late Future<List<VitalSign>> _vitalsFuture;
  late Future<List<Diagnosis>> _diagnosesFuture;
  late Future<List<Bill>> _billsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _visitsFuture = DatabaseHelper.instance.getVisitsForPatient(widget.patient.id!);
      _vitalsFuture = DatabaseHelper.instance.getVitalsForPatient(widget.patient.id!);
      _diagnosesFuture = DatabaseHelper.instance.getDiagnosesForPatient(widget.patient.id!);
      _billsFuture = DatabaseHelper.instance.getBillsForPatient(widget.patient.id!);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startNewConsultation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClinicalConsultationView(
          patient: widget.patient,
          currentUser: widget.currentUser,
        ),
      ),
    ).then((_) => _refreshData());
  }

  void _generateBill() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillingView(
          patient: widget.patient,
          currentUser: widget.currentUser,
        ),
      ),
    ).then((_) => _refreshData());
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;

    return Scaffold(
      appBar: AppBar(
        title: Text('EMR Record - ${p.fullName} (${p.patientCode})'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.teal.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: _startNewConsultation,
            icon: const Icon(Icons.add_task),
            label: const Text('Start New Visit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: _generateBill,
            icon: const Icon(Icons.receipt),
            label: const Text('Generate Bill'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.teal.shade50,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.teal.shade200,
                  child: Text(
                    p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : 'P',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.fullName,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Chip(
                            label: Text(p.gender, style: const TextStyle(fontSize: 12)),
                            backgroundColor: p.gender == 'Male' ? Colors.blue.shade100 : Colors.pink.shade100,
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text('${p.age ?? "N/A"} yrs'),
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          _infoText(Icons.numbers, 'Patient Code', p.patientCode),
                          _infoText(Icons.phone, 'Mobile', p.mobileNumber),
                          _infoText(Icons.cake, 'DOB', p.dateOfBirth),
                          if (p.occupation != null) _infoText(Icons.work, 'Occupation', p.occupation!),
                          if (p.referralDoctor != null) _infoText(Icons.medical_information, 'Referral', p.referralDoctor!),
                          if (p.emergencyContact != null) _infoText(Icons.contact_phone, 'Emergency', p.emergencyContact!),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: Colors.teal.shade900,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.teal.shade700,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.history_edu), text: 'Visits & Clinical Timeline'),
              Tab(icon: Icon(Icons.favorite_border), text: 'Vitals & Diagnoses Overview'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Billing & Invoices'),
            ],
          ),
          // Tab View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVisitsTimelineTab(),
                _buildVitalsDiagnosesTab(),
                _buildBillingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoText(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.teal.shade700),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(value, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
      ],
    );
  }

  // 1. VISITS TIMELINE TAB
  Widget _buildVisitsTimelineTab() {
    return FutureBuilder<List<PatientVisit>>(
      future: _visitsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading visits: ${snapshot.error}'));
        }

        final visits = snapshot.data ?? [];
        if (visits.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No clinical consultation visits recorded yet for this patient.'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                  onPressed: _startNewConsultation,
                  icon: const Icon(Icons.add),
                  label: const Text('Start First Visit'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index];
            return _VisitCard(visit: visit, index: visits.length - index);
          },
        );
      },
    );
  }

  // 2. VITALS & DIAGNOSES OVERVIEW TAB
  Widget _buildVitalsDiagnosesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Diagnoses Section
          Text('Diagnosis History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<List<Diagnosis>>(
            future: _diagnosesFuture,
            builder: (context, snapshot) {
              final diagnoses = snapshot.data ?? [];
              if (diagnoses.isEmpty) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No diagnoses recorded yet.')));
              }

              return Card(
                elevation: 2,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: diagnoses.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = diagnoses[index];
                    final dType = d.diagnosisType ?? 'Primary';
                    final initial = dType.isNotEmpty ? dType[0] : 'D';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: dType == 'Primary' ? Colors.red.shade100 : Colors.orange.shade100,
                        child: Text(initial, style: TextStyle(fontWeight: FontWeight.bold, color: dType == 'Primary' ? Colors.red.shade900 : Colors.orange.shade900)),
                      ),
                      title: Text(d.diagnosisName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('ICD Code: ${d.icdCode ?? "N/A"} | Notes: ${d.notes ?? "None"}'),
                      trailing: Chip(label: Text(dType)),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Vitals History Table
          Text('Vitals History Log', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<List<VitalSign>>(
            future: _vitalsFuture,
            builder: (context, snapshot) {
              final vitals = snapshot.data ?? [];
              if (vitals.isEmpty) {
                return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No vital signs recorded yet.')));
              }

              return Card(
                elevation: 2,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Date & Time')),
                      DataColumn(label: Text('BP (mmHg)')),
                      DataColumn(label: Text('Pulse (bpm)')),
                      DataColumn(label: Text('Temp (°C)')),
                      DataColumn(label: Text('SpO2 (%)')),
                      DataColumn(label: Text('Weight (kg)')),
                      DataColumn(label: Text('Height (cm)')),
                      DataColumn(label: Text('BMI')),
                    ],
                    rows: vitals.map((v) {
                      return DataRow(cells: [
                        DataCell(Text(v.recordedAt ?? '')),
                        DataCell(Text('${v.systolicBp ?? "-"}/${v.diastolicBp ?? "-"}')),
                        DataCell(Text(v.pulseRate != null ? '${v.pulseRate}' : '-')),
                        DataCell(Text(v.temperatureCelsius != null ? '${v.temperatureCelsius}' : '-')),
                        DataCell(Text(v.oxygenSaturation != null ? '${v.oxygenSaturation}%' : '-')),
                        DataCell(Text(v.weightKg != null ? '${v.weightKg}' : '-')),
                        DataCell(Text(v.heightCm != null ? '${v.heightCm}' : '-')),
                        DataCell(Text(v.bmi != null ? v.bmi!.toStringAsFixed(1) : '-')),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 3. BILLING TAB
  Widget _buildBillingTab() {
    return FutureBuilder<List<Bill>>(
      future: _billsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final bills = snapshot.data ?? [];
        if (bills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No bills or invoices generated yet for this patient.'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                  onPressed: _generateBill,
                  icon: const Icon(Icons.add),
                  label: const Text('Generate Invoice'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final bill = bills[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: bill.paymentStatus == 'Paid' ? Colors.green.shade100 : Colors.amber.shade100,
                  child: Icon(
                    bill.paymentStatus == 'Paid' ? Icons.check_circle : Icons.pending,
                    color: bill.paymentStatus == 'Paid' ? Colors.green.shade800 : Colors.amber.shade900,
                  ),
                ),
                title: Text('${bill.billNumber} | ₹${bill.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Date: ${bill.billDate ?? "N/A"} | Method: ${bill.paymentMethod ?? "Cash"}'),
                trailing: Chip(
                  label: Text(bill.paymentStatus ?? 'Pending'),
                  backgroundColor: (bill.paymentStatus ?? '') == 'Paid' ? Colors.green.shade50 : Colors.amber.shade50,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _VisitCard extends StatefulWidget {
  final PatientVisit visit;
  final int index;

  const _VisitCard({required this.visit, required this.index});

  @override
  State<_VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends State<_VisitCard> {
  bool _expanded = false;

  late Future<List<VitalSign>> _vitals;
  late Future<List<Diagnosis>> _diagnoses;
  late Future<List<Prescription>> _prescriptions;
  late Future<List<Investigation>> _investigations;
  late Future<List<Referral>> _referrals;

  @override
  void initState() {
    super.initState();
    final vid = widget.visit.id!;
    _vitals = DatabaseHelper.instance.getVitalsForVisit(vid);
    _diagnoses = DatabaseHelper.instance.getDiagnosesForVisit(vid);
    _prescriptions = DatabaseHelper.instance.getPrescriptionsForVisit(vid);
    _investigations = DatabaseHelper.instance.getInvestigationsForVisit(vid);
    _referrals = DatabaseHelper.instance.getReferralsForVisit(vid);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              child: Text('#${v.visitNumber ?? widget.index}'),
            ),
            title: Text(
              'Visit Date: ${v.visitDate ?? "N/A"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Chief Complaint: ${v.chiefComplaint ?? "None documented"}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  if (v.chiefComplaint != null) _section('Chief Complaint', v.chiefComplaint!),
                  if (v.hpiDuration != null || v.hpiSeverity != null || v.hpiAssociatedSymptoms != null)
                    _section(
                      'History of Present Illness (HPI)',
                      'Duration: ${v.hpiDuration ?? "N/A"} | Severity: ${v.hpiSeverity ?? "N/A"}\n'
                      'Symptoms: ${v.hpiAssociatedSymptoms ?? "N/A"}\n'
                      'Progression: ${v.hpiProgression ?? "N/A"} | Previous Treatment: ${v.hpiPreviousTreatments ?? "N/A"}',
                    ),
                  if (v.pmhChronicIllness != null || v.pmhAllergies != null || v.pmhCurrentMedications != null)
                    _section(
                      'Past Medical History (PMH)',
                      'Chronic Illness: ${v.pmhChronicIllness ?? "None"} | Allergies: ${v.pmhAllergies ?? "None"}\n'
                      'Surgeries: ${v.pmhSurgeries ?? "None"} | Current Meds: ${v.pmhCurrentMedications ?? "None"}',
                    ),
                  // Vitals
                  FutureBuilder<List<VitalSign>>(
                    future: _vitals,
                    builder: (c, s) {
                      final vt = s.data ?? [];
                      if (vt.isEmpty) return const SizedBox.shrink();
                      final item = vt.first;
                      return _section(
                        'Vital Signs',
                        'BP: ${item.systolicBp ?? "-"}/${item.diastolicBp ?? "-"} mmHg | Pulse: ${item.pulseRate ?? "-"} bpm | '
                        'Temp: ${item.temperatureCelsius ?? "-"}°C | SpO2: ${item.oxygenSaturation ?? "-"}%\n'
                        'Weight: ${item.weightKg ?? "-"} kg | Height: ${item.heightCm ?? "-"} cm | BMI: ${item.bmi?.toStringAsFixed(1) ?? "-"}',
                      );
                    },
                  ),
                  if (v.examGeneral != null || v.examCvs != null || v.examRespiratory != null)
                    _section(
                      'Systemic Examination',
                      'General: ${v.examGeneral ?? "Normal"}\n'
                      'CVS: ${v.examCvs ?? "Normal"} | Resp: ${v.examRespiratory ?? "Normal"}\n'
                      'Abdomen: ${v.examAbdomen ?? "Normal"} | CNS: ${v.examCns ?? "Normal"} | Musculoskeletal: ${v.examMusculoskeletal ?? "Normal"}',
                    ),
                  // Diagnoses
                  FutureBuilder<List<Diagnosis>>(
                    future: _diagnoses,
                    builder: (c, s) {
                      final dx = s.data ?? [];
                      if (dx.isEmpty) return const SizedBox.shrink();
                      final text = dx.map((d) => '${d.diagnosisName} (${d.diagnosisType}${d.icdCode != null ? ", ICD: ${d.icdCode}" : ""})').join(', ');
                      return _section('Diagnoses', text);
                    },
                  ),
                  // Investigations
                  FutureBuilder<List<Investigation>>(
                    future: _investigations,
                    builder: (c, s) {
                      final inv = s.data ?? [];
                      if (inv.isEmpty) return const SizedBox.shrink();
                      final text = inv.map((i) => '${i.testName} [${i.category}] ${i.findingsNotes != null ? "(${i.findingsNotes})" : ""}').join(', ');
                      return _section('Ordered Investigations', text);
                    },
                  ),
                  // Prescriptions
                  FutureBuilder<List<Prescription>>(
                    future: _prescriptions,
                    builder: (c, s) {
                      final rx = s.data ?? [];
                      if (rx.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text('Prescriptions:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                          const SizedBox(height: 4),
                          ...rx.map((r) => Text('• ${r.medicineName} ${r.dosage} - ${r.frequency} for ${r.duration ?? ""} (${r.instructions ?? ""})')),
                        ],
                      );
                    },
                  ),
                  // Referrals
                  FutureBuilder<List<Referral>>(
                    future: _referrals,
                    builder: (c, s) {
                      final ref = s.data ?? [];
                      if (ref.isEmpty) return const SizedBox.shrink();
                      final text = ref.map((r) => 'Referred to ${r.providerName} (${r.referredToType}): ${r.reason ?? ""}').join('\n');
                      return _section('Referrals', text);
                    },
                  ),
                  if (v.adviceLifestyle != null || v.adviceDietary != null || v.adviceFollowupInstructions != null || v.followupDate != null)
                    _section(
                      'Doctor Advice & Follow-up',
                      'Lifestyle: ${v.adviceLifestyle ?? "N/A"}\n'
                      'Dietary: ${v.adviceDietary ?? "N/A"}\n'
                      'Instructions: ${v.adviceFollowupInstructions ?? "N/A"}\n'
                      'Follow-up Date: ${v.followupDate ?? "None"}',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 2),
          Text(content, style: TextStyle(color: Colors.grey.shade900)),
        ],
      ),
    );
  }
}
