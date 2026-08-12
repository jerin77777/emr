import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../services/document_pdf_generator.dart';

/// Helper function to format a consultation record into a standard printable document string.
String generateConsultationPrintText({
  required String patientName,
  required String patientCode,
  required String patientMobile,
  String? visitDate,
  String? visitUuid,
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
  buffer.writeln('Patient Code  : $patientCode');
  buffer.writeln('Mobile Number : $patientMobile');
  buffer.writeln('Visit Date    : ${visitDate ?? "N/A"}');
  if (visitUuid != null && visitUuid.isNotEmpty) {
    buffer.writeln('Visit UUID    : $visitUuid');
  }
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
  final diagStr = diagnosis != null && diagnosis.trim().isNotEmpty ? diagnosis : 'None documented';
  final codeStr = diagnosisCode != null && diagnosisCode.trim().isNotEmpty ? ' ($diagnosisCode)' : '';
  buffer.writeln('$diagStr$codeStr');
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
  buffer.writeln(followupDate != null && followupDate.trim().isNotEmpty ? followupDate : 'None');
  buffer.writeln('------------------------------------------------------');
  buffer.writeln('Generated via Clinic EMR - Cloud Synced Backup');
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
      patientMobile: patient.mobileNumber,
      visitDate: visit.visitDate,
      visitUuid: visit.visitUuid,
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
      isDraft: isDraft,
    );
    return ConsultationPrintPreviewDialog(
      key: key,
      title: title ?? (isDraft ? 'Consultation Draft Preview' : 'Consultation Record Preview - ${visit.visitUuid.substring(0, 8)}...'),
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
      patientMobile: patient.mobileNumber,
      visitDate: visit.visitDate,
      visitUuid: visit.visitUuid,
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

  Future<void> _handleNativePrint() async {
    setState(() => _isPrinting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // 1. Fetch Doctor info if available
      String? doctorName;
      if (widget.visit.doctorId != null) {
        final docUser = await DatabaseHelper.instance.getUserById(widget.visit.doctorId!);
        doctorName = docUser?.fullName;
      }

      // 2. Generate PDF bytes
      final pdfBytes = await DocumentPdfGenerator.generateConsultationPdf(
        patient: widget.patient,
        visit: widget.visit,
        doctorName: doctorName,
      );

      // 3. Open System Native Print Preview & Dialog
      final printed = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Consultation_${widget.visit.visitUuid}.pdf',
      );

      // 4. Save Copy Locally and Record in SQLite (only if not a draft)
      if (printed && !widget.isDraft) {
        final dirPath = await DatabaseHelper.getPatientDocumentsDir(widget.patient.patientUuid, 'consultations');
        final fileName = 'Consultation_${widget.visit.visitUuid}.pdf';
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

  @override
  Widget build(BuildContext context) {
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This document is formatted and ready for printing:'),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            width: 500,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                widget.printContent,
                style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),
            ),
          ),
        ],
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
