import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../services/document_pdf_generator.dart';
import '../utils/date_formatter.dart';

/// Helper function to format a consultation record into a standard printable document string.
String generateConsultationPrintText({
  required String patientName,
  required String patientCode,
  String? visitDate,
  String? doctorName,
  String? chiefComplaint,
  String? history,
  String? pastMedicalHistory,
  String? vitalsBp,
  String? vitalsPulse,
  String? vitalsTemp,
  String? vitalsSaturation,
  String? systemicExamination,
  String? investigations,
  List<ConsultationDiagnosis>? diagnoses,
  String? diagnosis,
  String? diagnosisCode,
  String? advice,
  String? referralTo,
  String? followupDate,
  bool isDraft = false,
}) {
  final formattedVitals = VitalsFormatter.formatAll(
    bp: vitalsBp,
    pulse: vitalsPulse,
    temp: vitalsTemp,
    saturation: vitalsSaturation,
    includePlaceholders: true,
  );

  final buffer = StringBuffer();
  buffer.writeln('======================================================');
  buffer.writeln(isDraft
      ? '                  CLINIC VISIT RECORD DRAFT'
      : '                  CLINIC VISIT RECORD');
  buffer.writeln('======================================================');
  buffer.writeln('Patient Name  : $patientName');
  buffer.writeln('Patient ID    : $patientCode');
  buffer.writeln('Visit Date    : ${DateFormatter.formatDate(visitDate)}');
  if (doctorName != null && doctorName.isNotEmpty) {
    buffer.writeln('Consultant    : $doctorName');
  }
  buffer.writeln('------------------------------------------------------');

  buffer.writeln('CHIEF COMPLAINT:');
  buffer.writeln(chiefComplaint != null && chiefComplaint.trim().isNotEmpty ? chiefComplaint : 'None documented');
  buffer.writeln();

  buffer.writeln('HISTORY:');
  buffer.writeln(history != null && history.trim().isNotEmpty ? history : 'None documented');
  buffer.writeln();

  if (pastMedicalHistory != null && pastMedicalHistory.trim().isNotEmpty) {
    buffer.writeln('PAST MEDICAL HISTORY:');
    buffer.writeln(pastMedicalHistory);
    buffer.writeln();
  }

  buffer.writeln('VITALS:');
  buffer.writeln(formattedVitals);
  buffer.writeln();

  if (systemicExamination != null && systemicExamination.trim().isNotEmpty) {
    buffer.writeln('SYSTEMIC EXAMINATION:');
    buffer.writeln(systemicExamination);
    buffer.writeln();
  }

  if (investigations != null && investigations.trim().isNotEmpty) {
    buffer.writeln('INVESTIGATIONS ORDERED:');
    buffer.writeln(investigations);
    buffer.writeln();
  }

  buffer.writeln('DIAGNOSIS:');
  if (diagnoses != null && diagnoses.isNotEmpty) {
    for (final d in diagnoses) {
      buffer.writeln(d.icdCode == 'Custom' ? d.diagnosisName : '${d.icdCode} - ${d.diagnosisName}');
    }
  } else {
    final diagStr = diagnosis != null && diagnosis.trim().isNotEmpty ? diagnosis : 'None documented';
    final codeStr = diagnosisCode != null && diagnosisCode.trim().isNotEmpty ? ' ($diagnosisCode)' : '';
    buffer.writeln('$diagStr$codeStr');
  }
  buffer.writeln();

  buffer.writeln('ADVICE & PRESCRIPTION:');
  buffer.writeln(advice != null && advice.trim().isNotEmpty ? advice : 'None documented');
  buffer.writeln();

  if (referralTo != null && referralTo.trim().isNotEmpty) {
    buffer.writeln('REFERRAL TO:');
    buffer.writeln(referralTo);
    buffer.writeln();
  }

  buffer.writeln('FOLLOW-UP DATE:');
  buffer.writeln(followupDate != null && followupDate.trim().isNotEmpty ? DateFormatter.formatDate(followupDate) : 'None');
  buffer.writeln('------------------------------------------------------');
  buffer.writeln('Powered by Anything Ventures');
  buffer.writeln('www.anythingventures.in');
  buffer.writeln('======================================================');

  return buffer.toString();
}

/// A common popup dialog widget for displaying and printing consultation records.
class ConsultationPrintPreviewDialog extends StatefulWidget {
  final String title;
  final String printContent;
  final Patient patient;
  final PatientVisit visit;
  final User? currentUser;
  final bool isDraft;

  const ConsultationPrintPreviewDialog({
    super.key,
    required this.title,
    required this.printContent,
    required this.patient,
    required this.visit,
    this.currentUser,
    this.isDraft = false,
  });

  /// Factory constructor from PatientVisit and Patient objects
  factory ConsultationPrintPreviewDialog.fromVisit({
    Key? key,
    required PatientVisit visit,
    required Patient patient,
    User? currentUser,
    String? title,
    bool isDraft = false,
  }) {
    final content = generateConsultationPrintText(
      patientName: patient.fullName,
      patientCode: patient.patientCode,
      visitDate: visit.visitDate,
      chiefComplaint: visit.chiefComplaint,
      history: visit.history,
      pastMedicalHistory: visit.pastMedicalHistory,
      vitalsBp: visit.vitalsBp,
      vitalsPulse: visit.vitalsPulse,
      vitalsTemp: visit.vitalsTemp,
      vitalsSaturation: visit.vitalsSaturation,
      systemicExamination: visit.systemicExamination,
      investigations: visit.investigations,
      diagnoses: visit.diagnoses,
      diagnosis: visit.diagnosis,
      diagnosisCode: visit.diagnosisCode,
      advice: visit.advice,
      referralTo: visit.referralTo,
      followupDate: visit.followupDate,
      isDraft: isDraft,
    );
    return ConsultationPrintPreviewDialog(
      key: key,
      title: title ?? (isDraft ? 'Consultation Draft Preview' : 'Consultation Record Preview'),
      printContent: content,
      patient: patient,
      visit: visit,
      currentUser: currentUser,
      isDraft: isDraft,
    );
  }

  /// Factory constructor from a record Map
  factory ConsultationPrintPreviewDialog.fromMap({
    Key? key,
    required Map<String, dynamic> record,
    User? currentUser,
    String title = 'Consultation Print Preview',
  }) {
    final patient = Patient(
      id: record['patient_id'] != null ? (record['patient_id'] as num).toInt() : null,
      patientUuid: record['patient_uuid']?.toString() ?? '',
      patientCode: record['patient_code']?.toString() ?? '',
      fullName: record['patient_name']?.toString() ?? '',
      dateOfBirth: record['patient_dob']?.toString() ?? '',
      age: record['patient_age'] != null ? (record['patient_age'] as num).toInt() : null,
      gender: record['patient_gender']?.toString() ?? '',
      mobileNumber: record['patient_mobile']?.toString() ?? '',
      address: record['patient_address']?.toString() ?? '',
    );
    final visit = PatientVisit(
      id: record['id'] != null ? (record['id'] as num).toInt() : null,
      visitUuid: record['visit_uuid']?.toString() ?? '',
      patientId: record['patient_id'] != null ? (record['patient_id'] as num).toInt() : 0,
      doctorId: record['doctor_id'] != null ? (record['doctor_id'] as num).toInt() : null,
      visitDate: record['visit_date']?.toString() ?? DateTime.now().toString().split('.')[0],
      chiefComplaint: record['chief_complaint']?.toString(),
      history: record['history']?.toString(),
      pastMedicalHistory: record['past_medical_history']?.toString(),
      vitalsBp: record['vitals_bp']?.toString(),
      vitalsPulse: record['vitals_pulse']?.toString(),
      vitalsTemp: record['vitals_temp']?.toString(),
      vitalsSaturation: record['vitals_saturation']?.toString(),
      systemicExamination: record['systemic_examination']?.toString(),
      investigations: record['investigations']?.toString(),
      diagnosis: record['diagnosis']?.toString(),
      diagnosisCode: record['diagnosis_code']?.toString(),
      advice: record['advice']?.toString(),
      referralTo: record['referral_to']?.toString(),
      followupDate: record['followup_date']?.toString(),
    );

    final content = generateConsultationPrintText(
      patientName: patient.fullName,
      patientCode: patient.patientCode,
      visitDate: visit.visitDate,
      doctorName: record['doctor_name']?.toString(),
      chiefComplaint: visit.chiefComplaint,
      history: visit.history,
      pastMedicalHistory: visit.pastMedicalHistory,
      vitalsBp: visit.vitalsBp,
      vitalsPulse: visit.vitalsPulse,
      vitalsTemp: visit.vitalsTemp,
      vitalsSaturation: visit.vitalsSaturation,
      systemicExamination: visit.systemicExamination,
      investigations: visit.investigations,
      diagnosis: visit.diagnosis,
      diagnosisCode: visit.diagnosisCode,
      advice: visit.advice,
      referralTo: visit.referralTo,
      followupDate: visit.followupDate,
      isDraft: false,
    );
    return ConsultationPrintPreviewDialog(
      key: key,
      title: title,
      printContent: content,
      patient: patient,
      visit: visit,
      currentUser: currentUser,
      isDraft: false,
    );
  }

  /// Helper static method to trigger dialog directly
  static Future<void> show(BuildContext context, {required ConsultationPrintPreviewDialog dialog}) {
    return showDialog(
      context: context,
      builder: (context) => dialog,
    );
  }

  @override
  State<ConsultationPrintPreviewDialog> createState() => _ConsultationPrintPreviewDialogState();
}

class _ConsultationPrintPreviewDialogState extends State<ConsultationPrintPreviewDialog> {
  bool _isPrinting = false;
  String _clinicName = 'Neuron - The Clinic';
  String _clinicAddress = '';
  String _clinicPhone = '8105129750';
  String _clinicWebsite = 'www.drsrajamani.in';
  String _developerName = 'Anything Ventures';
  String _developerWebsite = 'www.anythingventures.in';
  List<ConsultationDiagnosis> _diagnoses = [];
  String? _doctorName;
  String? _resolvedSigPath;
  String? _doctorSpec;
  String? _doctorLicense;

  @override
  void initState() {
    super.initState();
    _loadClinicSettings();
  }

  Future<void> _loadClinicSettings() async {
    try {
      final settings = await DatabaseHelper.instance.getClinicSettings();
      final diags = await DatabaseHelper.instance.getDiagnosesForVisit(widget.visit.id ?? 0);

      String? docName;
      String? sigPath;
      String? spec;
      String? license;
      if (widget.visit.doctorId != null) {
        final docUser = await DatabaseHelper.instance.getUserById(widget.visit.doctorId!);
        docName = docUser?.fullName;
        spec = docUser?.specialization;
        license = docUser?.licenseNumber;
        
        if (docUser != null) {
          if (widget.visit.doctorSignatureVersion != null) {
            final appDir = await DatabaseHelper.getAppDirectoryPath();
            final versionedPath = path.join(
              appDir,
              'ClinicData',
              'users',
              docUser.userUuid,
              'signature',
              'processed',
              'signature_v${widget.visit.doctorSignatureVersion}.png',
            );
            if (File(versionedPath).existsSync()) {
              sigPath = versionedPath;
            }
          }
          sigPath ??= docUser.signatureFilePath;
        }
      }

      if (mounted) {
        setState(() {
          _clinicName = settings.clinicName;
          _clinicAddress = settings.address;
          _clinicPhone = settings.telephone;
          _clinicWebsite = settings.website;
          _developerName = settings.developerName;
          _developerWebsite = settings.developerWebsite;
          _diagnoses = diags;
          _doctorName = docName;
          _resolvedSigPath = sigPath;
          _doctorSpec = spec;
          _doctorLicense = license;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleNativePrint() async {
    setState(() => _isPrinting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Generate PDF bytes
      final pdfBytes = await DocumentPdfGenerator.generateConsultationPdf(
        patient: widget.patient,
        visit: widget.visit.copyWith(diagnoses: _diagnoses.isNotEmpty ? _diagnoses : widget.visit.diagnoses),
        doctorName: _doctorName,
      );

      // Open System Native Print Preview & Dialog
      final printed = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Consultation_${widget.visit.id ?? "draft"}.pdf',
      );

      // Save Copy Locally and Record in SQLite (only if not a draft)
      if (printed && !widget.isDraft) {
        final dirPath = await DatabaseHelper.getPatientDocumentsDir(widget.patient.patientUuid, 'consultations');
        final fileName = 'Consultation_${widget.visit.id ?? DateTime.now().millisecondsSinceEpoch}.pdf';
        final filePath = path.join(dirPath, fileName);

        // Write PDF file to app support path
        final pdfFile = File(filePath);
        await pdfFile.writeAsBytes(pdfBytes);

        // Record document metadata in SQLite documents table
        final docUuid = 'doc-${DateTime.now().millisecondsSinceEpoch}';
        final doc = Document(
          documentUuid: docUuid,
          patientId: widget.patient.id!,
          visitId: widget.visit.id,
          documentType: 'consultation',
          fileName: fileName,
          filePath: filePath,
          createdBy: widget.currentUser?.id,
        );
        await DatabaseHelper.instance.insertDocument(doc);
        
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Consultation PDF saved and registered successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Print job failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Widget _previewInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 10, color: Colors.black87))),
      ],
    );
  }

  Widget _previewSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
      ),
    );
  }

  Widget _previewClinicalBlock(String label, String? content) {
    if (content == null || content.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black54)),
          const SizedBox(height: 1),
          Text(content, style: const TextStyle(fontSize: 10, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _previewTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black87),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _previewTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 9, color: Colors.black87),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finalDiagnoses = _diagnoses.isNotEmpty ? _diagnoses : (widget.visit.diagnoses ?? []);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.print, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        width: 600,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Clinic Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_clinicName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                          const SizedBox(height: 4),
                          if (_clinicAddress.isNotEmpty) ...[
                            Text(_clinicAddress, style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
                            const SizedBox(height: 2),
                          ],
                          Text('Phone: $_clinicPhone | Website: $_clinicWebsite', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 35,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('LOGO', style: TextStyle(fontSize: 8, color: Colors.grey), textAlign: TextAlign.center),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(thickness: 1.5, color: Colors.teal.shade700),
                const SizedBox(height: 8),

                // 2. Title
                Center(
                  child: Text(
                    widget.isDraft ? 'CLINIC VISIT RECORD DRAFT' : 'CLINIC VISIT RECORD',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.teal.shade900),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Patient Info Grid
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _previewInfoRow('Patient Name', widget.patient.fullName)),
                          Expanded(child: _previewInfoRow('Patient ID', widget.patient.patientCode)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _previewInfoRow('Age / Gender', '${widget.patient.age ?? "N/A"} yrs / ${widget.patient.gender}')),
                          Expanded(child: _previewInfoRow('Date of Birth', DateFormatter.formatDate(widget.patient.dateOfBirth))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _previewInfoRow('Consultation Date', DateFormatter.formatDate(widget.visit.visitDate))),
                          Expanded(child: _previewInfoRow('Consultant Doctor', _doctorName ?? 'N/A')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Clinical Details Section
                _previewSectionHeader('1. CLINICAL SYMPTOMS & HISTORY'),
                _previewClinicalBlock('Chief Complaint', widget.visit.chiefComplaint),
                _previewClinicalBlock('History of Present Illness', widget.visit.history),
                _previewClinicalBlock('Past Medical History', widget.visit.pastMedicalHistory),

                // 5. Vitals Section
                _previewSectionHeader('2. VITAL SIGNS & MEASUREMENTS'),
                const SizedBox(height: 6),
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: [
                        _previewTableHeaderCell('BP (mmHg)'),
                        _previewTableHeaderCell('Pulse (bpm)'),
                        _previewTableHeaderCell('Temp'),
                        _previewTableHeaderCell('SPO2 (%)'),
                      ],
                    ),
                    TableRow(
                      children: [
                        _previewTableCell(VitalsFormatter.formatBp(widget.visit.vitalsBp, includePlaceholder: false).isEmpty ? 'N/A' : VitalsFormatter.formatBp(widget.visit.vitalsBp, includePlaceholder: false)),
                        _previewTableCell(VitalsFormatter.formatPulse(widget.visit.vitalsPulse, includePlaceholder: false).isEmpty ? 'N/A' : VitalsFormatter.formatPulse(widget.visit.vitalsPulse, includePlaceholder: false)),
                        _previewTableCell(VitalsFormatter.formatTemp(widget.visit.vitalsTemp, includePlaceholder: false).isEmpty ? 'N/A' : VitalsFormatter.formatTemp(widget.visit.vitalsTemp, includePlaceholder: false)),
                        _previewTableCell(VitalsFormatter.formatSaturation(widget.visit.vitalsSaturation, includePlaceholder: false).isEmpty ? 'N/A' : VitalsFormatter.formatSaturation(widget.visit.vitalsSaturation, includePlaceholder: false)),
                      ],
                    ),
                  ],
                ),

                // 6. Examination & Investigations
                _previewSectionHeader('3. EXAMINATION & INVESTIGATIONS'),
                _previewClinicalBlock('Systemic Examination', widget.visit.systemicExamination),
                _previewClinicalBlock('Investigations Ordered', widget.visit.investigations),

                // 7. Diagnosis & Plan
                _previewSectionHeader('4. DIAGNOSIS & PRESCRIPTION PLAN'),
                _previewClinicalBlock(
                  'Diagnosis',
                  finalDiagnoses.isNotEmpty
                      ? finalDiagnoses.map((d) => d.icdCode == 'Custom' ? d.diagnosisName : '${d.icdCode} - ${d.diagnosisName}').join('\n')
                      : (widget.visit.diagnosis != null && widget.visit.diagnosis!.isNotEmpty
                          ? '${widget.visit.diagnosis!}${widget.visit.diagnosisCode != null ? " (ICD-10: ${widget.visit.diagnosisCode})" : ""}'
                          : null),
                ),
                _previewClinicalBlock('Advice & Prescriptions', widget.visit.advice),
                _previewClinicalBlock('Referral To', widget.visit.referralTo),
                _previewClinicalBlock('Follow-up Date', DateFormatter.formatDate(widget.visit.followupDate)),
                
                const SizedBox(height: 24),

                // 8. Sign-off Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Generated by: Clinic ERP Portal', style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_resolvedSigPath != null && File(_resolvedSigPath!).existsSync()) ...[
                          SizedBox(
                            height: 40,
                            width: 100,
                            child: Image.file(File(_resolvedSigPath!), fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 4),
                        ] else ...[
                          const SizedBox(height: 40),
                        ],
                        Container(
                          width: 140,
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade400, width: 0.8)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_doctorName != null) ...[
                          Text(_doctorName!, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                          Text(_doctorSpec ?? 'General Medicine', style: TextStyle(fontSize: 7, color: Colors.grey.shade700)),
                          if (_doctorLicense != null)
                            Text('License No: $_doctorLicense', style: TextStyle(fontSize: 7, color: Colors.grey.shade700)),
                        ] else ...[
                          Text('Doctor\'s Authorized Signature', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                        ],
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32),
                Center(
                  child: Column(
                    children: [
                      Text('Powered by $_developerName', style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                      Text(_developerWebsite, style: TextStyle(fontSize: 8, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.printContent));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Consultation text copied to clipboard!')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy Text'),
        ),
        ElevatedButton.icon(
          onPressed: _isPrinting ? null : _handleNativePrint,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
          icon: _isPrinting 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.print),
          label: const Text('Print'),
        ),
      ],
    );
  }
}
