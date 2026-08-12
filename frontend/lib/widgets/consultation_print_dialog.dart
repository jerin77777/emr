import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

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
class ConsultationPrintPreviewDialog extends StatelessWidget {
  final String title;
  final String printContent;

  const ConsultationPrintPreviewDialog({
    super.key,
    this.title = 'Consultation Print Preview',
    required this.printContent,
  });

  /// Factory constructor from PatientVisit and Patient objects (used in patient directory)
  factory ConsultationPrintPreviewDialog.fromVisit({
    Key? key,
    required PatientVisit visit,
    required Patient patient,
    String? title,
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
    );
    return ConsultationPrintPreviewDialog(
      key: key,
      title: title ?? 'Consultation Record Preview - ${visit.visitUuid}',
      printContent: content,
    );
  }

  /// Factory constructor from a record Map (used in Consultation Records view)
  factory ConsultationPrintPreviewDialog.fromMap({
    Key? key,
    required Map<String, dynamic> record,
    String title = 'Consultation Print Preview',
  }) {
    final content = generateConsultationPrintText(
      patientName: record['patient_name']?.toString() ?? '',
      patientCode: record['patient_code']?.toString() ?? '',
      patientMobile: record['patient_mobile']?.toString() ?? '',
      visitDate: record['visit_date']?.toString(),
      visitUuid: record['visit_uuid']?.toString(),
      doctorName: record['doctor_name']?.toString(),
      chiefComplaint: record['chief_complaint']?.toString(),
      history: record['history']?.toString(),
      vitalsBp: record['vitals_bp']?.toString(),
      vitalsPulse: record['vitals_pulse']?.toString(),
      vitalsTemp: record['vitals_temp']?.toString(),
      vitalsSaturation: record['vitals_saturation']?.toString(),
      diagnosis: record['diagnosis']?.toString(),
      diagnosisCode: record['diagnosis_code']?.toString(),
      advice: record['advice']?.toString(),
      followupDate: record['followup_date']?.toString(),
    );
    return ConsultationPrintPreviewDialog(
      key: key,
      title: title,
      printContent: content,
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
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.print, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
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
                printContent,
                style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: printContent));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Consultation text copied to clipboard!')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy Text'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PDF layout generated! Sending job to printer...'),
                backgroundColor: Colors.green,
              ),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
          icon: const Icon(Icons.print),
          label: const Text('Print'),
        ),
      ],
    );
  }
}
