import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../database/database_helper.dart';
import '../models/models.dart';
import '../services/sync_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/common_widgets.dart';
import 'clinical_consultation_view.dart';
import 'billing_view.dart';
import '../main.dart';
import '../widgets/investigation_review_dialog.dart';
import '../services/document_text_extractor.dart';
import '../services/investigation_parser_service.dart';

/// Main Patient Detail View Widget
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
  late Future<List<InvestigationReport>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _visitsFuture = DatabaseHelper.instance.getVisitsForPatient(widget.patient.id!);
      _billsFuture = DatabaseHelper.instance.getBillsForPatient(widget.patient.id!);
      _reportsFuture = DatabaseHelper.instance.getInvestigationReportsForPatient(widget.patient.id!);
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
    final dashboardState = context.findAncestorStateOfType<DashboardShellState>();
    if (dashboardState != null) {
      Navigator.pop(context);
      dashboardState.navigateToSection('billing', patient: widget.patient);
    } else {
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
  }

  Future<void> _confirmDeletePatient() async {
    final p = widget.patient;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Patient Record'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${p.fullName}" (ID: ${p.patientCode})?\n\nThis will permanently delete this patient and all their clinical visits, invoices, and documents.',
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
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true && p.id != null) {
      try {
        await DatabaseHelper.instance.deletePatient(p.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Patient "${p.fullName}" deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting patient: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;

    return Scaffold(
      appBar: AppBar(
        title: Text('EMR Record - ${p.fullName} (ID: ${p.patientCode})'),
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
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            tooltip: 'Delete Patient Record',
            onPressed: _confirmDeletePatient,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Header Card Widget
          PatientHeaderCard(patient: p),

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
              Tab(icon: Icon(Icons.folder_shared), text: 'Investigation Reports'),
            ],
          ),

          // Tab View with separate Widgets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                VisitsTimelineTab(
                  visitsFuture: _visitsFuture,
                  patient: widget.patient,
                  currentUser: widget.currentUser,
                  onStartVisit: _startNewConsultation,
                  onRefresh: _refreshData,
                ),
                BillingTab(
                  billsFuture: _billsFuture,
                  patient: widget.patient,
                  currentUser: widget.currentUser,
                  onGenerateBill: _generateBill,
                  onRefresh: _refreshData,
                ),
                InvestigationReportsTab(
                  reportsFuture: _reportsFuture,
                  patient: widget.patient,
                  currentUser: widget.currentUser,
                  onRefresh: _refreshData,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header widget displaying patient demographics
class PatientHeaderCard extends StatelessWidget {
  final Patient patient;

  const PatientHeaderCard({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final p = patient;
    return Container(
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
                    PatientInfoBadge(icon: Icons.numbers, label: 'Patient ID', value: p.patientCode),
                    PatientInfoBadge(icon: Icons.phone, label: 'Mobile', value: p.mobileNumber),
                    PatientInfoBadge(icon: Icons.cake, label: 'DOB', value: p.dateOfBirth),
                    if (p.occupation != null && p.occupation!.isNotEmpty)
                      PatientInfoBadge(icon: Icons.work, label: 'Occupation', value: p.occupation!),
                    if (p.referralDoctor != null && p.referralDoctor!.isNotEmpty)
                      PatientInfoBadge(icon: Icons.medical_information, label: 'Referral', value: p.referralDoctor!),
                    if (p.emergencyContact != null && p.emergencyContact!.isNotEmpty)
                      PatientInfoBadge(icon: Icons.contact_phone, label: 'Emergency', value: p.emergencyContact!),
                    if (p.proofOfIdentity != null && p.proofOfIdentity!.contains('|'))
                      PatientInfoBadge(icon: Icons.fingerprint, label: p.identityType ?? 'Identity', value: p.identityNumber ?? ''),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone Widget for patient info badge in header
class PatientInfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const PatientInfoBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// 1. VISITS TIMELINE TAB WIDGET
class VisitsTimelineTab extends StatelessWidget {
  final Future<List<PatientVisit>> visitsFuture;
  final Patient patient;
  final User currentUser;
  final VoidCallback onStartVisit;
  final VoidCallback onRefresh;

  const VisitsTimelineTab({
    super.key,
    required this.visitsFuture,
    required this.patient,
    required this.currentUser,
    required this.onStartVisit,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PatientVisit>>(
      future: visitsFuture,
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
                  onPressed: onStartVisit,
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
            return VisitCard(
              patient: patient,
              visit: visit,
              index: visits.length - index,
              currentUser: currentUser,
              onRefresh: onRefresh,
            );
          },
        );
      },
    );
  }
}

/// Individual Visit Card Widget
class VisitCard extends StatefulWidget {
  final Patient patient;
  final PatientVisit visit;
  final int index;
  final User currentUser;
  final VoidCallback onRefresh;

  const VisitCard({
    super.key,
    required this.patient,
    required this.visit,
    required this.index,
    required this.currentUser,
    required this.onRefresh,
  });

  @override
  State<VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends State<VisitCard> {
  bool _expanded = false;

  void _openEditConsultation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClinicalConsultationView(
          patient: widget.patient,
          currentUser: widget.currentUser,
          existingVisit: widget.visit,
        ),
      ),
    ).then((result) {
      if (result == true || mounted) {
        widget.onRefresh();
      }
    });
  }

  Future<void> _confirmDeleteVisit() async {
    final v = widget.visit;
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
          'Are you sure you want to delete Consultation Visit #${v.visitNumber ?? widget.index} (${DateFormatter.formatDate(v.visitDate)})?',
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

    if (confirm == true && v.id != null) {
      try {
        await DatabaseHelper.instance.deletePatientVisit(v.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Consultation Visit #${v.visitNumber ?? widget.index} deleted.'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onRefresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting visit: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showPrintPreviewModal() {
    ConsultationPrintPreviewDialog.show(
      context,
      dialog: ConsultationPrintPreviewDialog.fromVisit(
        visit: widget.visit,
        patient: widget.patient,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final vitalsText = v.formattedVitals(includePlaceholders: true);
    final isEditable = DateFormatter.isVisitEditable(v.visitDate, v.createdAt);
    final editStatus = DateFormatter.getEditStatusText(v.visitDate, v.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              foregroundColor: Colors.teal.shade900,
              child: Text('#${widget.index}'),
            ),
            title: Row(
              children: [
                Text(
                  'Visit: ${DateFormatter.formatDate(v.visitDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (v.chiefComplaint != null)
                    Text('Complaints: ${v.chiefComplaint!}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.monitor_heart, size: 14, color: Colors.teal.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vitalsText,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.teal.shade900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.print_outlined, color: Colors.teal),
                  tooltip: 'Preview / Print Record',
                  onPressed: _showPrintPreviewModal,
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: isEditable ? Colors.teal.shade700 : Colors.grey.shade400,
                  ),
                  tooltip: isEditable
                      ? 'Edit Consultation ($editStatus)'
                      : 'Edit window closed ($editStatus)',
                  onPressed: isEditable ? _openEditConsultation : null,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  tooltip: 'Delete Visit',
                  onPressed: _confirmDeleteVisit,
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
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
                    ClinicalSectionItem(title: 'Chief Complaint', content: v.chiefComplaint!),
                  if (v.history != null && v.history!.isNotEmpty)
                    ClinicalSectionItem(title: 'History', content: v.history!),
                  if (v.pastMedicalHistory != null && v.pastMedicalHistory!.isNotEmpty)
                    ClinicalSectionItem(title: 'Past Medical History', content: v.pastMedicalHistory!),
                  VitalsPreviewBlock(bp: v.vitalsBp, pulse: v.vitalsPulse, temp: v.vitalsTemp, saturation: v.vitalsSaturation),
                  if (v.systemicExamination != null && v.systemicExamination!.isNotEmpty)
                    ClinicalSectionItem(title: 'Systemic Examination', content: v.systemicExamination!),
                  if (v.investigations != null && v.investigations!.isNotEmpty)
                    ClinicalSectionItem(title: 'Investigations', content: v.investigations!),
                  if (v.diagnoses != null && v.diagnoses!.isNotEmpty)
                    ClinicalSectionItem(
                      title: 'Diagnosis',
                      content: v.diagnoses!.map((d) => d.icdCode == 'Custom' ? d.diagnosisName : '${d.icdCode} - ${d.diagnosisName}').join(', '),
                    )
                  else if (v.diagnosis != null && v.diagnosis!.isNotEmpty)
                    ClinicalSectionItem(
                      title: 'Diagnosis',
                      content: '${v.diagnosis!}${v.diagnosisCode != null ? " (ICD-10: ${v.diagnosisCode})" : ""}',
                    ),
                  if (v.advice != null && v.advice!.isNotEmpty)
                    ClinicalSectionItem(title: 'Advice', content: v.advice!),
                  if (v.referralTo != null && v.referralTo!.isNotEmpty)
                    ClinicalSectionItem(title: 'Referral', content: v.referralTo!),
                  if (v.followupDate != null && v.followupDate!.isNotEmpty)
                    ClinicalSectionItem(title: 'Follow-up Date', content: DateFormatter.formatDate(v.followupDate!)),
                  if (isEditable) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openEditConsultation,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text('Edit Consultation ($editStatus)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal.shade800,
                            side: BorderSide(color: Colors.teal.shade300),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Standalone Widget for preview modal section items
class ConsultationPreviewSection extends StatelessWidget {
  final String title;
  final String content;

  const ConsultationPreviewSection({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 13)),
          const SizedBox(height: 2),
          Text(content, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Standalone Widget for expanded visit card clinical section items
class ClinicalSectionItem extends StatelessWidget {
  final String title;
  final String content;

  const ClinicalSectionItem({
    super.key,
    required this.title,
    required this.content,
  });

  IconData _getIcon() {
    switch (title) {
      case 'Chief Complaint':
        return Icons.report_problem;
      case 'History':
        return Icons.history_edu;
      case 'Past Medical History':
        return Icons.medical_services;
      case 'Systemic Examination':
        return Icons.accessibility_new;
      case 'Investigations':
        return Icons.science;
      case 'Diagnosis':
        return Icons.search;
      case 'Advice':
        return Icons.recommend;
      case 'Referral':
        return Icons.outbox;
      case 'Follow-up Date':
        return Icons.calendar_month;
      default:
        return Icons.article;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4F3F2), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getIcon(), size: 16, color: Colors.teal.shade700),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade900,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VitalCardItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const VitalCardItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(minWidth: 120),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(51), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VitalsPreviewBlock extends StatelessWidget {
  final String? bp;
  final String? pulse;
  final String? temp;
  final String? saturation;

  const VitalsPreviewBlock({
    super.key,
    this.bp,
    this.pulse,
    this.temp,
    this.saturation,
  });

  @override
  Widget build(BuildContext context) {
    final formattedBp = VitalsFormatter.formatBp(bp, includePlaceholder: false);
    final formattedPulse = VitalsFormatter.formatPulse(pulse, includePlaceholder: false);
    final formattedTemp = VitalsFormatter.formatTemp(temp, includePlaceholder: false);
    final formattedSaturation = VitalsFormatter.formatSaturation(saturation, includePlaceholder: false);

    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart, color: Colors.teal.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'Vitals',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              VitalCardItem(
                icon: Icons.favorite,
                label: 'Blood Pressure',
                value: formattedBp.isEmpty ? 'N/A' : formattedBp,
                color: Colors.red.shade600,
              ),
              VitalCardItem(
                icon: Icons.heart_broken,
                label: 'Pulse Rate',
                value: formattedPulse.isEmpty ? 'N/A' : formattedPulse,
                color: Colors.orange.shade700,
              ),
              VitalCardItem(
                icon: Icons.thermostat,
                label: 'Temperature',
                value: formattedTemp.isEmpty ? 'N/A' : formattedTemp,
                color: Colors.amber.shade800,
              ),
              VitalCardItem(
                icon: Icons.air,
                label: 'SpO2 Saturation',
                value: formattedSaturation.isEmpty ? 'N/A' : formattedSaturation,
                color: Colors.blue.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2. BILLING TAB WIDGET
class BillingTab extends StatelessWidget {
  final Future<List<Bill>> billsFuture;
  final Patient patient;
  final User currentUser;
  final VoidCallback onGenerateBill;
  final VoidCallback onRefresh;

  const BillingTab({
    super.key,
    required this.billsFuture,
    required this.patient,
    required this.currentUser,
    required this.onGenerateBill,
    required this.onRefresh,
  });

  Future<void> _confirmDeleteBill(BuildContext context, Bill bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Invoice'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Invoice "${bill.billNumber}" for ₹${bill.totalAmount.toStringAsFixed(2)}?',
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
            child: const Text('Delete Invoice'),
          ),
        ],
      ),
    );

    if (confirm == true && bill.id != null) {
      try {
        await DatabaseHelper.instance.deleteBill(bill.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice ${bill.billNumber} deleted.'),
              backgroundColor: Colors.green,
            ),
          );
          onRefresh();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting invoice: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Bill>>(
      future: billsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading bills: ${snapshot.error}'));
        }

        final bills = snapshot.data ?? [];
        if (bills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No invoices or billing records found for this patient.'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                  onPressed: onGenerateBill,
                  icon: const Icon(Icons.add),
                  label: const Text('Generate First Bill'),
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
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              child: ListTile(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => BillPrintPreviewDialog(bill: bill, patient: patient),
                  );
                },
                leading: CircleAvatar(
                  backgroundColor: status == 'Paid' ? Colors.green.shade100 : Colors.amber.shade100,
                  child: Icon(
                    status == 'Paid' ? Icons.check_circle : Icons.pending,
                    color: status == 'Paid' ? Colors.green.shade800 : Colors.amber.shade900,
                  ),
                ),
                title: Text('${bill.billNumber} | ₹${bill.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Date: ${DateFormatter.formatDate(bill.billDate ?? DateTime.now().toIso8601String())} | Method: ${bill.paymentMethod ?? "Cash"}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(status),
                      backgroundColor: status == 'Paid' ? Colors.green.shade50 : Colors.amber.shade50,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.teal),
                      tooltip: 'Print Invoice',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => BillPrintPreviewDialog(bill: bill, patient: patient),
                        );
                      },
                    ),
                    Builder(
                      builder: (context) {
                        final isEditable = DateFormatter.isBillEditable(bill.billDate);
                        final editStatus = DateFormatter.getBillEditStatusText(bill.billDate);
                        return IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: isEditable ? Colors.teal.shade700 : Colors.grey.shade400,
                          ),
                          tooltip: isEditable ? 'Edit Bill ($editStatus)' : 'Edit window closed ($editStatus)',
                          onPressed: isEditable ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => BillingView(
                                  patient: patient,
                                  currentUser: currentUser,
                                  existingBill: bill,
                                ),
                              ),
                            ).then((res) {
                              if (res == true || context.mounted) {
                                onRefresh();
                              }
                            });
                          } : null,
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                      tooltip: 'Delete Invoice',
                      onPressed: () => _confirmDeleteBill(context, bill),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 3. INVESTIGATION REPORTS TAB WIDGET
class InvestigationReportsTab extends StatefulWidget {
  final Future<List<InvestigationReport>> reportsFuture;
  final Patient patient;
  final User currentUser;
  final VoidCallback onRefresh;

  const InvestigationReportsTab({
    super.key,
    required this.reportsFuture,
    required this.patient,
    required this.currentUser,
    required this.onRefresh,
  });

  @override
  State<InvestigationReportsTab> createState() => _InvestigationReportsTabState();
}

class _InvestigationReportsTabState extends State<InvestigationReportsTab> {
  String _searchQuery = '';
  String? _selectedCategory;

  void _showAddReportDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddInvestigationReportDialog(
        patient: widget.patient,
        currentUser: widget.currentUser,
        onReportSaved: widget.onRefresh,
      ),
    );
  }

  void _viewReportFile(InvestigationReport rep) {
    showDialog(
      context: context,
      builder: (context) => ViewInvestigationReportDialog(report: rep),
    );
  }

  void _confirmDeleteReport(InvestigationReport rep) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Investigation Report'),
          content: Text('Are you sure you want to delete "${rep.title}"? This will remove the document record and local file from disk.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                navigator.pop();
                try {
                  if (rep.id != null) {
                    await DatabaseHelper.instance.deleteInvestigationReport(rep.id!);
                  }
                  final file = File(rep.filePath);
                  if (await file.exists()) {
                    await file.delete();
                  }
                  widget.onRefresh();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Investigation report deleted successfully.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error deleting report: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InvestigationReport>>(
      future: widget.reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading investigation reports: ${snapshot.error}'));
        }

        final allReports = snapshot.data ?? [];
        final filteredReports = allReports.where((rep) {
          final q = _searchQuery.toLowerCase();
          final matchesQuery = q.isEmpty ||
              rep.title.toLowerCase().contains(q) ||
              (rep.fileName != null && rep.fileName!.toLowerCase().contains(q)) ||
              (rep.notes != null && rep.notes!.toLowerCase().contains(q));
          final matchesCategory = _selectedCategory == null || rep.category == _selectedCategory;
          return matchesQuery && matchesCategory;
        }).toList();

        return Column(
          children: [
            // Search and Category Filter Bar Card
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search investigation reports, notes, or file names...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Categories')),
                          DropdownMenuItem(value: 'Lab Report', child: Text('Lab Report')),
                          DropdownMenuItem(value: 'Radiology / Imaging', child: Text('Radiology / Imaging')),
                          DropdownMenuItem(value: 'Pathology', child: Text('Pathology')),
                          DropdownMenuItem(value: 'ECG / Cardiac', child: Text('ECG / Cardiac')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (val) => setState(() => _selectedCategory = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                      onPressed: _showAddReportDialog,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Document', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

            // Reports List
            Expanded(
              child: filteredReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            allReports.isEmpty
                                ? 'No investigation reports or documents uploaded yet for this patient.'
                                : 'No reports found matching filters.',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                            onPressed: _showAddReportDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Upload First Report'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredReports.length,
                      itemBuilder: (context, index) {
                        final rep = filteredReports[index];
                        return InvestigationReportCard(
                          report: rep,
                          onView: () => _viewReportFile(rep),
                          onDelete: () => _confirmDeleteReport(rep),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Investigation Report Card Widget
class InvestigationReportCard extends StatelessWidget {
  final InvestigationReport report;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const InvestigationReportCard({
    super.key,
    required this.report,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final rep = report;
    IconData categoryIcon = Icons.science;
    Color categoryColor = Colors.teal;
    if (rep.category == 'Radiology / Imaging') {
      categoryIcon = Icons.image;
      categoryColor = Colors.indigo;
    } else if (rep.category == 'Pathology') {
      categoryIcon = Icons.biotech;
      categoryColor = Colors.purple;
    } else if (rep.category == 'ECG / Cardiac') {
      categoryIcon = Icons.monitor_heart;
      categoryColor = Colors.red;
    } else if (rep.category == 'Other') {
      categoryIcon = Icons.description;
      categoryColor = Colors.orange;
    }

    final ext = (rep.fileType ?? path.extension(rep.filePath)).toLowerCase().replaceAll('.', '');
    final isSynced = rep.fileUrl != null && rep.fileUrl!.isNotEmpty;
    final fileSizeStr = rep.fileSize != null ? '${(rep.fileSize! / 1024).toStringAsFixed(1)} KB' : 'Unknown size';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: categoryColor.withValues(alpha: 0.15),
                  foregroundColor: categoryColor,
                  child: Icon(categoryIcon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rep.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Chip(
                            label: Text(rep.category ?? 'General', style: TextStyle(fontSize: 11, color: categoryColor, fontWeight: FontWeight.bold)),
                            backgroundColor: categoryColor.withValues(alpha: 0.1),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          Text('Report Date: ${rep.reportDate ?? "N/A"}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      avatar: Icon(isSynced ? Icons.cloud_done : Icons.sd_storage, size: 14, color: isSynced ? Colors.green.shade800 : Colors.teal.shade800),
                      label: Text(isSynced ? 'Cloud & Local Synced' : 'Local Storage', style: TextStyle(fontSize: 11, color: isSynced ? Colors.green.shade900 : Colors.teal.shade900)),
                      backgroundColor: isSynced ? Colors.green.shade50 : Colors.teal.shade50,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(height: 4),
                    Text('${rep.fileName ?? "File"} ($fileSizeStr)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            // Extraction Status & Measurements Preview
            FutureBuilder<List<InvestigationMeasurement>>(
              future: rep.id != null ? DatabaseHelper.instance.getMeasurementsForReport(rep.id!) : Future.value([]),
              builder: (context, snapshot) {
                final measurements = snapshot.data ?? [];
                final isVerified = rep.extractionStatus == 'verified';
                final needsReview = rep.extractionStatus == 'needs_review' || (measurements.isNotEmpty && !isVerified);
                final statusLabel = isVerified ? 'VERIFIED' : (needsReview ? 'NEEDS REVIEW' : 'NOT PROCESSED');
                final statusColor = isVerified ? Colors.green : (needsReview ? Colors.orange : Colors.grey);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          avatar: Icon(isVerified ? Icons.verified : Icons.analytics, size: 14, color: statusColor.shade900),
                          label: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor.shade900)),
                          backgroundColor: statusColor.shade50,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        if (measurements.isNotEmpty)
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: measurements.take(4).map((m) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.teal.shade200),
                                    ),
                                    child: Text(
                                      '${m.parameterName}: ${m.valueText}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Format: ${ext.toUpperCase()} | File: ${rep.fileName ?? "Document"}',
                            style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.teal.shade800),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => InvestigationReviewDialog(
                                    report: rep,
                                    onSaved: onView,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.biotech, size: 18),
                              label: Text(measurements.isNotEmpty ? 'Medical Data (${measurements.length})' : 'Extract Medical Data'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.teal.shade800),
                              onPressed: onView,
                              icon: const Icon(Icons.visibility, size: 18),
                              label: const Text('Preview Original'),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete Document',
                              onPressed: onDelete,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            if (rep.notes != null && rep.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Notes / Observations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal.shade900)),
              const SizedBox(height: 4),
              Text(rep.notes!, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Add Investigation Report Modal Dialog Widget
class AddInvestigationReportDialog extends StatefulWidget {
  final Patient patient;
  final User currentUser;
  final VoidCallback onReportSaved;

  const AddInvestigationReportDialog({
    super.key,
    required this.patient,
    required this.currentUser,
    required this.onReportSaved,
  });

  @override
  State<AddInvestigationReportDialog> createState() => _AddInvestigationReportDialogState();
}

class _AddInvestigationReportDialogState extends State<AddInvestigationReportDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateController = TextEditingController(
    text: "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}",
  );
  String _selectedCategory = 'Lab Report';

  File? _pickedFile;
  String? _pickedFileName;
  int? _pickedFileSize;
  bool _isSaving = false;
  bool _isScanning = false;

  Future<void> _scanDocument() async {
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document scanning is only supported on Windows devices.')),
      );
      return;
    }

    setState(() => _isScanning = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final tempDir = Directory.systemTemp;
      final tempPath = path.join(tempDir.path, 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final file = File(tempPath);
      if (file.existsSync()) {
        file.deleteSync();
      }

      // WIA PowerShell script to show native scan dialog
      final psScript = '''
\$dialog = New-Object -ComObject WIA.CommonDialog
try {
    \$image = \$dialog.ShowAcquireImage()
    if (\$image) {
        \$image.SaveFile("$tempPath")
        Write-Output "SUCCESS"
    } else {
        Write-Output "CANCEL"
    }
} catch {
    Write-Output "ERROR: \$(\$_.Exception.Message)"
}
''';

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-Command', psScript
      ]);

      final output = result.stdout.toString().trim();
      if (output.contains("SUCCESS") && file.existsSync()) {
        final length = await file.length();
        setState(() {
          _pickedFile = file;
          _pickedFileName = path.basename(tempPath);
          _pickedFileSize = length;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = 'Scanned Investigation Document';
          }
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Document scanned successfully!'), backgroundColor: Colors.green),
        );
      } else if (output.contains("CANCEL")) {
        // User cancelled without scanning
      } else {
        throw Exception(output.isNotEmpty ? output : result.stderr.toString());
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Scanning failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final ext = path.extension(filePath).toLowerCase().replaceAll('.', '');
        final allowed = ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'];
        if (!allowed.contains(ext)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid format. Only PDF, DOC/DOCX, and Images (PNG, JPG, JPEG) are allowed.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final file = File(filePath);
        setState(() {
          _pickedFile = file;
          _pickedFileName = result.files.single.name;
          _pickedFileSize = result.files.single.size;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = path.basenameWithoutExtension(_pickedFileName!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_pickedFile == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select a document file to upload.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a document title.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final reportUuid = 'rep-${DateTime.now().millisecondsSinceEpoch}';
      final ext = path.extension(_pickedFileName!).toLowerCase();

      // 1. Copy to Local App Storage under unified patient directory
      final dirPath = await DatabaseHelper.getPatientDocumentsDir(widget.patient.patientUuid, 'investigations');
      final localPath = path.join(dirPath, '$reportUuid$ext');
      await _pickedFile!.copy(localPath);

      // 2. Firebase Storage Bucket Upload (if configured)
      String? fileUrl;
      String syncStatus = 'pending';
      final proj = await DatabaseHelper.instance.getSetting('firebase_project_id');
      final key = await DatabaseHelper.instance.getSetting('firebase_api_key');

      if (proj != null && proj.isNotEmpty && key != null && key.isNotEmpty) {
        final uploadedUrl = await SyncService.instance.uploadFileToFirebaseBucket(
          file: File(localPath),
          projectId: proj,
          apiKey: key,
          remoteName: 'investigations/$reportUuid$ext',
        );
        if (uploadedUrl != null) {
          fileUrl = uploadedUrl;
          syncStatus = 'synced';
        }
      }

      // 3. Database Insertion
      final report = InvestigationReport(
        reportUuid: reportUuid,
        patientId: widget.patient.id!,
        title: _titleController.text.trim(),
        category: _selectedCategory,
        reportDate: _dateController.text.trim(),
        filePath: localPath,
        fileUrl: fileUrl,
        fileName: _pickedFileName,
        fileType: path.extension(_pickedFileName!).replaceAll('.', ''),
        fileSize: _pickedFileSize,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        uploadedBy: widget.currentUser.id,
        syncStatus: syncStatus,
        createdAt: DateTime.now().toIso8601String(),
      );

      final reportId = await DatabaseHelper.instance.insertInvestigationReport(report);
      final savedReport = report.copyWith(id: reportId);

      // 4. Trigger Automatic Extraction in Background
      try {
        final extractResult = await DocumentTextExtractor.instance.extractText(File(localPath));
        final parsed = InvestigationParserService.instance.parseRawReportText(
          rawText: extractResult.rawText,
          reportId: reportId,
          reportUuid: reportUuid,
        );

        await DatabaseHelper.instance.saveInvestigationExtraction(
          reportId: reportId,
          reportUuid: reportUuid,
          status: 'needs_review',
          rawText: extractResult.rawText,
          studyDate: parsed.studyDate,
          modality: parsed.modality,
          investigationType: parsed.investigationType,
          findingsText: parsed.findingsText,
          impressionText: parsed.impressionText,
          measurements: parsed.measurements,
          diagnoses: parsed.diagnoses,
        );
      } catch (e) {
        debugPrint('Automatic extraction error: $e');
      }

      if (mounted) {
        navigator.pop();
        widget.onReportSaved();

        // Offer immediate medical data verification dialog
        showDialog(
          context: context,
          builder: (context) => InvestigationReviewDialog(
            report: savedReport,
            onSaved: widget.onReportSaved,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Error saving report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.upload_file, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          Text('Upload Investigation Report', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Select File Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedFileName ?? 'No document file selected yet',
                            style: TextStyle(
                              fontWeight: _pickedFileName != null ? FontWeight.bold : FontWeight.normal,
                              color: _pickedFileName != null ? Colors.teal.shade900 : Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Supports PDF, JPG, JPEG, PNG formats.',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                          if (_pickedFileSize != null) ...[
                            const SizedBox(height: 4),
                            Text('Size: ${(_pickedFileSize! / 1024).toStringAsFixed(1)} KB', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isSaving || _isScanning ? null : _pickFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(220, 36),
                          ),
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: Text(_pickedFileName == null ? 'Upload Document / Scanned PDF' : 'Change File'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isSaving || _isScanning ? null : _scanDocument,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade800,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(150, 36),
                          ),
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.document_scanner, size: 16),
                          label: Text(_isScanning ? 'Scanning...' : 'Scan Document'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Title
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Document / Report Title *',
                  hintText: 'e.g. Complete Blood Count (CBC), Chest X-Ray',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Category & Date Picker
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Report Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Lab Report', child: Text('Lab Report')),
                        DropdownMenuItem(value: 'Radiology / Imaging', child: Text('Radiology / Imaging')),
                        DropdownMenuItem(value: 'Pathology', child: Text('Pathology')),
                        DropdownMenuItem(value: 'ECG / Cardiac', child: Text('ECG / Cardiac')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          _dateController.text =
                              "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Report Date',
                        suffixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes / Observations
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes / Observations (Optional)',
                  hintText: 'Enter findings summary or clinical notes...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
          onPressed: _isSaving ? null : _saveReport,
          icon: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save),
          label: const Text('SAVE & STORE REPORT', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// View Investigation Report Details Dialog Widget
class ViewInvestigationReportDialog extends StatelessWidget {
  final InvestigationReport report;

  const ViewInvestigationReportDialog({super.key, required this.report});

  void _openFileExternally(String filePath, String? fileUrl) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        if (Platform.isWindows) {
          Process.run('cmd', ['/c', 'start', '', filePath]);
        } else if (Platform.isMacOS) {
          Process.run('open', [filePath]);
        } else if (Platform.isLinux) {
          Process.run('xdg-open', [filePath]);
        }
      } else if (fileUrl != null && fileUrl.isNotEmpty) {
        if (Platform.isWindows) {
          Process.run('cmd', ['/c', 'start', '', fileUrl]);
        } else if (Platform.isMacOS) {
          Process.run('open', [fileUrl]);
        } else if (Platform.isLinux) {
          Process.run('xdg-open', [fileUrl]);
        }
      }
    } catch (e) {
      debugPrint('Could not open file externally: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rep = report;
    final file = File(rep.filePath);
    final ext = (rep.fileType ?? path.extension(rep.filePath)).toLowerCase().replaceAll('.', '');
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
    final isPdf = ext == 'pdf';
    final isDoc = ['doc', 'docx'].contains(ext);
    final fileNameStr = rep.fileName ?? path.basename(rep.filePath);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(rep.title, style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // PREVIEW SECTION
              if (isImage) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: file.existsSync()
                        ? Image.file(file, fit: BoxFit.contain)
                        : (rep.fileUrl != null && rep.fileUrl!.isNotEmpty)
                            ? Image.network(rep.fileUrl!, fit: BoxFit.contain)
                            : const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Image file unavailable locally.'))),
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (isPdf) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileNameStr,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal.shade900),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PDF Document (${rep.fileSize != null ? (rep.fileSize! / 1024).toStringAsFixed(1) : "N/A"} KB)',
                              style: TextStyle(color: Colors.teal.shade700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade800,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _openFileExternally(rep.filePath, rep.fileUrl),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open PDF'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (isDoc) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.description, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileNameStr,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue.shade900),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Word Document (${rep.fileSize != null ? (rep.fileSize! / 1024).toStringAsFixed(1) : "N/A"} KB)',
                              style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _openFileExternally(rep.filePath, rep.fileUrl),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open DOC'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // METADATA DETAILS (NO RAW FILE PATH DISPLAYED)
              ReportDetailRow(label: 'Category', value: rep.category ?? 'General'),
              ReportDetailRow(label: 'Report Date', value: rep.reportDate ?? 'N/A'),
              ReportDetailRow(label: 'File Name', value: fileNameStr),
              ReportDetailRow(label: 'File Format', value: ext.toUpperCase()),
              if (rep.fileSize != null)
                ReportDetailRow(label: 'File Size', value: '${(rep.fileSize! / 1024).toStringAsFixed(1)} KB'),
              if (rep.fileUrl != null && rep.fileUrl!.isNotEmpty)
                ReportDetailRow(label: 'Cloud Status', value: 'Synced with Cloud Storage'),
              if (rep.notes != null && rep.notes!.isNotEmpty) ...[
                const Divider(height: 20),
                Text('Notes / Observations:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(rep.notes!),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (isImage && file.existsSync())
          TextButton.icon(
            onPressed: () => _openFileExternally(rep.filePath, rep.fileUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Full Image'),
          ),
        if (rep.fileUrl != null && rep.fileUrl!.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: rep.fileUrl!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cloud Storage link copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.cloud_done),
            label: const Text('Copy Cloud Link'),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Standalone Widget for report detail dialog rows
class ReportDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const ReportDetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 13))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
