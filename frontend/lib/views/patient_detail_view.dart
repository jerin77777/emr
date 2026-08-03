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
  late Future<List<Bill>> _billsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _visitsFuture = DatabaseHelper.instance.getVisitsForPatient(widget.patient.id!);
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
              Tab(icon: Icon(Icons.receipt_long), text: 'Billing & Invoices'),
            ],
          ),
          // Tab View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVisitsTimelineTab(),
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

  // 2. BILLING TAB
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
            final status = bill.paymentStatus ?? 'Pending';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: status == 'Paid' ? Colors.green.shade100 : Colors.amber.shade100,
                  child: Icon(
                    status == 'Paid' ? Icons.check_circle : Icons.pending,
                    color: status == 'Paid' ? Colors.green.shade800 : Colors.amber.shade900,
                  ),
                ),
                title: Text('${bill.billNumber} | ₹${bill.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Date: ${bill.billDate ?? "N/A"} | Method: ${bill.paymentMethod ?? "Cash"}'),
                trailing: Chip(
                  label: Text(status),
                  backgroundColor: status == 'Paid' ? Colors.green.shade50 : Colors.amber.shade50,
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

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;

    final vitalsList = <String>[];
    if (v.vitalsBp != null && v.vitalsBp!.isNotEmpty) vitalsList.add('BP: ${v.vitalsBp}');
    if (v.vitalsPulse != null && v.vitalsPulse!.isNotEmpty) vitalsList.add('Pulse: ${v.vitalsPulse}');
    if (v.vitalsTemp != null && v.vitalsTemp!.isNotEmpty) vitalsList.add('Temp: ${v.vitalsTemp}');
    if (v.vitalsSaturation != null && v.vitalsSaturation!.isNotEmpty) vitalsList.add('Saturation: ${v.vitalsSaturation}');
    final vitalsText = vitalsList.join(' | ');

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
                  if (v.chiefComplaint != null && v.chiefComplaint!.isNotEmpty)
                    _section('a. Chief complaints', v.chiefComplaint!),
                  if (v.history != null && v.history!.isNotEmpty)
                    _section('b. History', v.history!),
                  if (v.pastMedicalHistory != null && v.pastMedicalHistory!.isNotEmpty)
                    _section('c. Past history/Medical History', v.pastMedicalHistory!),
                  if (vitalsText.isNotEmpty)
                    _section('d. Vital signs', vitalsText),
                  if (v.systemicExamination != null && v.systemicExamination!.isNotEmpty)
                    _section('e. Systemic Examination', v.systemicExamination!),
                  if (v.investigations != null && v.investigations!.isNotEmpty)
                    _section('f. Investigations', v.investigations!),
                  if (v.diagnosis != null && v.diagnosis!.isNotEmpty)
                    _section('g. Diagnosis', v.diagnosis!),
                  if (v.advice != null && v.advice!.isNotEmpty)
                    _section('h. Advice', v.advice!),
                  if (v.referralTo != null && v.referralTo!.isNotEmpty)
                    _section('i. Referral to…', v.referralTo!),
                  if (v.followupDate != null && v.followupDate!.isNotEmpty)
                    _section('Follow-up Date', v.followupDate!),
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
