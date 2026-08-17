import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' show join;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/date_formatter.dart';

class DocumentPdfGenerator {
  /// Fetches clinic details from Settings. Fallbacks to default values if not defined.
  static Future<Map<String, String>> getClinicDetails() async {
    final settings = await DatabaseHelper.instance.getClinicSettings();
    return {
      'name': settings.clinicName,
      'address': settings.address,
      'phone': settings.telephone,
      'website': settings.website,
      'developer_name': settings.developerName,
      'developer_website': settings.developerWebsite,
    };
  }

  /// Generates a professional PDF document for a Consultation
  static Future<Uint8List> generateConsultationPdf({
    required Patient patient,
    required PatientVisit visit,
    String? doctorName,
  }) async {
    final pdf = pw.Document();
    final clinic = await getClinicDetails();
    final now = DateTime.now();

    User? doctor;
    if (visit.doctorId != null) {
      doctor = await DatabaseHelper.instance.getUserById(visit.doctorId!);
    }

    String? resolvedSigPath;
    if (doctor != null) {
      if (visit.doctorSignatureVersion != null) {
        final appDir = await DatabaseHelper.getAppDirectoryPath();
        final versionedPath = join(
          appDir,
          'ClinicData',
          'users',
          doctor.userUuid,
          'signature',
          'processed',
          'signature_v${visit.doctorSignatureVersion}.png',
        );
        if (File(versionedPath).existsSync()) {
          resolvedSigPath = versionedPath;
        }
      }
      resolvedSigPath ??= doctor.signatureFilePath;
    }

    pw.ImageProvider? sigImage;
    if (resolvedSigPath != null && resolvedSigPath.isNotEmpty) {
      try {
        final sigFile = File(resolvedSigPath);
        if (sigFile.existsSync()) {
          sigImage = pw.MemoryImage(sigFile.readAsBytesSync());
        }
      } catch (e) {
        // Log or handle error gracefully
      }
    }
    final generatedAt = DateFormatter.formatDateTime(now.toString());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              ),
              padding: const pw.EdgeInsets.only(bottom: 8),
              margin: const pw.EdgeInsets.only(bottom: 15),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Consultation Record: ${patient.fullName}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            );
          }
          return pw.SizedBox.shrink();
        },
        footer: (pw.Context context) {
          return pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            padding: const pw.EdgeInsets.only(top: 8),
            margin: const pw.EdgeInsets.only(top: 15),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Generated: $generatedAt', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    pw.Text('Powered by Anything Ventures (www.anythingventures.in)', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Clinic Header (Reserved Area for Logo + Info)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(clinic['name']!, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.SizedBox(height: 4),
                    if (clinic['address']!.isNotEmpty) ...[
                      pw.Text(clinic['address']!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      pw.SizedBox(height: 2),
                    ],
                    pw.Text('Phone: ${clinic['phone']!} | Website: ${clinic['website']!}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                // Reserved space for logo placeholder on the right
                pw.Container(
                  width: 80,
                  height: 40,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, style: pw.BorderStyle.dashed),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text('CLINIC LOGO', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500), textAlign: pw.TextAlign.center),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1.5, color: PdfColors.teal700),
            pw.SizedBox(height: 10),

            // 2. Title Header
            pw.Center(
              child: pw.Text('CONSULTATION RECORD', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2, color: PdfColors.teal900)),
            ),
            pw.SizedBox(height: 15),

            // 3. Patient Information Grid
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: _infoRow('Patient Name', patient.fullName)),
                      pw.Expanded(child: _infoRow('Patient ID', patient.patientCode)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _infoRow('Age / Gender', '${patient.age ?? "N/A"} yrs / ${patient.gender}')),
                      pw.Expanded(child: _infoRow('Date of Birth', patient.dateOfBirth)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _infoRow('Mobile Number', patient.mobileNumber)),
                      pw.Expanded(child: _infoRow('Consultation Date', DateFormatter.formatDate(visit.visitDate))),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _infoRow('Address', patient.address ?? 'N/A')),
                      pw.Expanded(child: _infoRow('Consultant Doctor', doctorName ?? 'N/A')),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 4. Clinical Details Section
            if ((visit.chiefComplaint != null && visit.chiefComplaint!.trim().isNotEmpty) ||
                (visit.pastMedicalHistory != null && visit.pastMedicalHistory!.trim().isNotEmpty)) ...[
              _sectionHeader('CLINICAL SYMPTOMS & HISTORY'),
              _clinicalBlock('Chief Complaint', visit.chiefComplaint),
              _clinicalBlock('Past Medical History', visit.pastMedicalHistory),
              pw.SizedBox(height: 10),
            ],

            if (visit.history != null && visit.history!.trim().isNotEmpty) ...[
              _sectionHeader('HISTORY OF PRESENT ILLNESS'),
              pw.Text(visit.history!, style: const pw.TextStyle(fontSize: 9.5), textAlign: pw.TextAlign.justify),
              pw.SizedBox(height: 10),
            ],

            // 5. Vitals Section
            if (VitalsFormatter.formatBp(visit.vitalsBp, includePlaceholder: false).isNotEmpty ||
                VitalsFormatter.formatPulse(visit.vitalsPulse, includePlaceholder: false).isNotEmpty ||
                VitalsFormatter.formatTemp(visit.vitalsTemp, includePlaceholder: false).isNotEmpty ||
                VitalsFormatter.formatSaturation(visit.vitalsSaturation, includePlaceholder: false).isNotEmpty) ...[
              _sectionHeader('VITAL SIGNS & MEASUREMENTS'),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _tableHeaderCell('Blood Pressure (mmHg)'),
                      _tableHeaderCell('Pulse Rate (bpm)'),
                      _tableHeaderCell('Temperature (°F/°C)'),
                      _tableHeaderCell('Oxygen Saturation (%)'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableCell(VitalsFormatter.formatBp(visit.vitalsBp, includePlaceholder: false).isEmpty ? 'N/A' : VitalsFormatter.formatBp(visit.vitalsBp, includePlaceholder: false)),
                      _tableCell(VitalsFormatter.formatPulse(visit.vitalsPulse, includePlaceholder: false).isEmpty ? 'N/A' : VitalsFormatter.formatPulse(visit.vitalsPulse, includePlaceholder: false)),
                      _tableCell(VitalsFormatter.formatTemp(visit.vitalsTemp, includePlaceholder: false).isEmpty ? 'N/A' : VitalsFormatter.formatTemp(visit.vitalsTemp, includePlaceholder: false)),
                      _tableCell(VitalsFormatter.formatSaturation(visit.vitalsSaturation, includePlaceholder: false).isEmpty ? 'N/A' : VitalsFormatter.formatSaturation(visit.vitalsSaturation, includePlaceholder: false)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
            ],

            // 6. Examination & Investigations
            if ((visit.systemicExamination != null && visit.systemicExamination!.trim().isNotEmpty) ||
                (visit.investigations != null && visit.investigations!.trim().isNotEmpty)) ...[
              _sectionHeader('EXAMINATION & INVESTIGATIONS'),
              _clinicalBlock('Systemic Examination', visit.systemicExamination),
              _clinicalBlock('Investigations Ordered', visit.investigations),
              pw.SizedBox(height: 15),
            ],

            // 7. Diagnosis & Plan
            if (visit.diagnoses != null && visit.diagnoses!.isNotEmpty) ...[
              _sectionHeader('DIAGNOSIS'),
              pw.Text(
                visit.diagnoses!.map((d) => d.icdCode == 'Custom' ? d.diagnosisName : '${d.icdCode} - ${d.diagnosisName}').join('\n'),
                style: const pw.TextStyle(fontSize: 9.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 10),
            ] else if (visit.diagnosis != null && visit.diagnosis!.isNotEmpty) ...[
              _sectionHeader('DIAGNOSIS'),
              pw.Text(
                '${visit.diagnosis!}${visit.diagnosisCode != null ? " (ICD-10: ${visit.diagnosisCode})" : ""}',
                style: const pw.TextStyle(fontSize: 9.5),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 10),
            ],

            ..._buildAdviceAndPrescription(visit.advice),

            if ((visit.referralTo != null && visit.referralTo!.trim().isNotEmpty) ||
                (visit.followupDate != null && visit.followupDate!.trim().isNotEmpty)) ...[
              _sectionHeader('FOLLOW-UP & REFERRALS'),
              _clinicalBlock('Referral To', visit.referralTo),
              _clinicalBlock('Follow-up Date', DateFormatter.formatDate(visit.followupDate)),
            ],
            
            pw.SizedBox(height: 40),

            // 8. Sign-off Section (Will automatically wrap cleanly)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Generated by: Clinic ERP Portal', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (sigImage != null) ...[
                      pw.Container(
                        height: 50,
                        width: 120,
                        child: pw.Image(sigImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(height: 4),
                    ] else ...[
                      pw.SizedBox(height: 50),
                    ],
                    pw.Container(
                      width: 150,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                      ),
                      padding: const pw.EdgeInsets.only(bottom: 4),
                    ),
                    pw.SizedBox(height: 4),
                    if (doctor != null) ...[
                      pw.Text(doctor.fullName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                      pw.Text(doctor.specialization ?? 'General Medicine', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                      if (doctor.licenseNumber != null)
                        pw.Text('License No: ${doctor.licenseNumber!}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                    ] else ...[
                      pw.Text('Doctor\'s Authorized Signature', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                      if (doctorName != null)
                        pw.Text(doctorName, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a professional PDF document for an Invoice / Bill
  static Future<Uint8List> generateBillPdf({
    required Patient patient,
    required Bill bill,
    required List<BillItem> items,
    String? doctorName,
  }) async {
    final pdf = pw.Document();
    final clinic = await getClinicDetails();
    final now = DateTime.now();

    User? doctor;
    PatientVisit? visit;
    if (bill.visitId != null) {
      visit = await DatabaseHelper.instance.getPatientVisitById(bill.visitId!);
      if (visit != null && visit.doctorId != null) {
        doctor = await DatabaseHelper.instance.getUserById(visit.doctorId!);
      }
    }

    String? resolvedSigPath;
    if (doctor != null) {
      if (visit != null && visit.doctorSignatureVersion != null) {
        final appDir = await DatabaseHelper.getAppDirectoryPath();
        final versionedPath = join(
          appDir,
          'ClinicData',
          'users',
          doctor.userUuid,
          'signature',
          'processed',
          'signature_v${visit.doctorSignatureVersion}.png',
        );
        if (File(versionedPath).existsSync()) {
          resolvedSigPath = versionedPath;
        }
      }
      resolvedSigPath ??= doctor.signatureFilePath;
    }

    pw.ImageProvider? sigImage;
    if (resolvedSigPath != null && resolvedSigPath.isNotEmpty) {
      try {
        final sigFile = File(resolvedSigPath);
        if (sigFile.existsSync()) {
          sigImage = pw.MemoryImage(sigFile.readAsBytesSync());
        }
      } catch (_) {}
    }
    final generatedAt = DateFormatter.formatDateTime(now.toString());

    final billDateStr = DateFormatter.formatDate(bill.billDate ?? DateTime.now().toIso8601String());
    final paymentStatus = bill.paymentStatus ?? 'Paid';
    final paymentMethod = bill.paymentMethod ?? 'Cash';

    // Calculation fields
    final double consultation = bill.consultationCharges ?? 0.0;
    final double procedures = bill.procedureCharges ?? 0.0;
    final double additional = bill.additionalCharges ?? 0.0;
    final double discount = bill.discountAmount ?? 0.0;
    final double total = bill.totalAmount;
    final double paid = bill.paidAmount ?? total;
    final double balance = total - paid;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              ),
              padding: const pw.EdgeInsets.only(bottom: 8),
              margin: const pw.EdgeInsets.only(bottom: 15),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice #: ${bill.billNumber}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.Text('Patient Name: ${patient.fullName}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            );
          }
          return pw.SizedBox.shrink();
        },
        footer: (pw.Context context) {
          return pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            padding: const pw.EdgeInsets.only(top: 8),
            margin: const pw.EdgeInsets.only(top: 15),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Generated: $generatedAt | Thank you for your visit!', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    pw.Text('Powered by Anything Ventures (www.anythingventures.in)', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Clinic Header (Reserved Area for Logo + Info)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(clinic['name']!, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.SizedBox(height: 4),
                    if (clinic['address']!.isNotEmpty) ...[
                      pw.Text(clinic['address']!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      pw.SizedBox(height: 2),
                    ],
                    pw.Text('Phone: ${clinic['phone']!} | Website: ${clinic['website']!}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  width: 80,
                  height: 40,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, style: pw.BorderStyle.dashed),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text('CLINIC LOGO', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500), textAlign: pw.TextAlign.center),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1.5, color: PdfColors.teal700),
            pw.SizedBox(height: 10),

            // 2. Title Header
            pw.Center(
              child: pw.Text('PATIENT INVOICE & RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2, color: PdfColors.teal900)),
            ),
            pw.SizedBox(height: 15),

            // 3. Invoice Metadata Info Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Invoice Number : ${bill.billNumber}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Invoice Date    : $billDateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Payment Status: ${paymentStatus.toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: paymentStatus == 'Paid' ? PdfColors.green900 : PdfColors.amber900)),
                    pw.Text('Payment Method: $paymentMethod', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // 4. Patient Information Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Patient Name: ${patient.fullName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('Patient ID: ${patient.patientCode}', style: const pw.TextStyle(fontSize: 9)),
                      if (patient.address != null && patient.address!.isNotEmpty)
                        pw.Text('Address: ${patient.address!}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Mobile: ${patient.mobileNumber}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Gender / Age: ${patient.gender} / ${patient.age ?? "N/A"} yrs', style: const pw.TextStyle(fontSize: 9)),
                      if (doctorName != null)
                        pw.Text('Referring Doctor: $doctorName', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 5. Itemized Table
            pw.Text('Itemized Charges Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.teal900)),
            pw.SizedBox(height: 8),
            
            _buildChargesTable(bill, items, consultation, procedures, additional),
            
            pw.SizedBox(height: 15),

            // 6. Cost Summary Block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 200), // Left padding space
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      if (discount > 0)
                        _summaryRow('Subtotal', 'INR ${(total + discount).toStringAsFixed(2)}'),
                      if (discount > 0)
                        _summaryRow('Discount Applied', '- INR ${discount.toStringAsFixed(2)}', color: PdfColors.red900),
                      pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                      _summaryRow('TOTAL PAYABLE', 'INR ${total.toStringAsFixed(2)}', isBold: true, fontSize: 12),
                      _summaryRow('Amount Paid', 'INR ${paid.toStringAsFixed(2)}'),
                      pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                      _summaryRow('BALANCE DUE', 'INR ${balance.toStringAsFixed(2)}', isBold: true, color: balance > 0 ? PdfColors.red900 : PdfColors.teal900),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            pw.SizedBox(height: 40),

            // 7. Signature area
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Receipt Generated via clinic billing portal', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (sigImage != null) ...[
                      pw.Container(
                        height: 50,
                        width: 120,
                        child: pw.Image(sigImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(height: 4),
                    ] else ...[
                      pw.SizedBox(height: 50),
                    ],
                    pw.Container(
                      width: 150,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                      ),
                      padding: const pw.EdgeInsets.only(bottom: 4),
                    ),
                    pw.SizedBox(height: 4),
                    if (doctor != null) ...[
                      pw.Text(doctor.fullName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                      pw.Text(doctor.specialization ?? 'General Medicine', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                      if (doctor.licenseNumber != null)
                        pw.Text('License No: ${doctor.licenseNumber!}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                    ] else ...[
                      pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    ],
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // --- PDF Widget Helper Builders ---

  static Map<String, String?> _splitAdviceAndPrescription(String? fullAdvice) {
    if (fullAdvice == null || fullAdvice.trim().isEmpty) {
      return {'advice': null, 'prescription': null};
    }

    final lines = fullAdvice.split('\n');
    final adviceLines = <String>[];
    final prescriptionLines = <String>[];
    bool inPrescription = false;

    // Regular expression to match common prescription headers like:
    // "Prescription", "Prescriptions", "Rx", "Rx:", "Prescription:", etc.
    final rxRegExp = RegExp(r'^\s*(prescriptions?|rx)\s*:?\s*$', caseSensitive: false);

    for (final line in lines) {
      if (rxRegExp.hasMatch(line)) {
        inPrescription = true;
        continue;
      }
      if (inPrescription) {
        prescriptionLines.add(line);
      } else {
        adviceLines.add(line);
      }
    }

    String? advice = adviceLines.join('\n').trim();
    String? prescription = prescriptionLines.join('\n').trim();

    // If we never found a prescription header, check if a line starts with a prescription prefix
    if (!inPrescription) {
      int rxIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        final lowerLine = lines[i].toLowerCase().trim();
        if (lowerLine.startsWith('prescription:') || lowerLine.startsWith('prescriptions:') || lowerLine.startsWith('rx:')) {
          rxIndex = i;
          break;
        }
      }

      if (rxIndex != -1) {
        final beforeLines = lines.sublist(0, rxIndex);
        final afterLines = lines.sublist(rxIndex);
        final firstRxLine = afterLines[0];
        final colonIndex = firstRxLine.indexOf(':');
        afterLines[0] = firstRxLine.substring(colonIndex + 1).trim();

        advice = beforeLines.join('\n').trim();
        prescription = afterLines.join('\n').trim();
      }
    }

    // Clean up "Advice:" prefix from advice if it exists
    final lowerAdvice = advice.toLowerCase().trim();
    if (lowerAdvice.startsWith('advice:')) {
      final colonIndex = advice.indexOf(':');
      advice = advice.substring(colonIndex + 1).trim();
    }

    return {
      'advice': advice.isEmpty ? null : advice,
      'prescription': prescription.isEmpty ? null : prescription,
    };
  }

  static List<pw.Widget> _buildAdviceAndPrescription(String? rawAdvice) {
    final adviceParts = _splitAdviceAndPrescription(rawAdvice);
    final adviceText = adviceParts['advice'];
    final prescriptionText = adviceParts['prescription'];
    return [
      if (adviceText != null && adviceText.isNotEmpty) ...[
        _sectionHeader('ADVICE'),
        pw.Text(adviceText, style: const pw.TextStyle(fontSize: 9.5), textAlign: pw.TextAlign.justify),
        pw.SizedBox(height: 10),
      ],
      if (prescriptionText != null && prescriptionText.isNotEmpty) ...[
        _sectionHeader('PRESCRIPTION'),
        pw.Text(prescriptionText, style: const pw.TextStyle(fontSize: 9.5), textAlign: pw.TextAlign.justify),
        pw.SizedBox(height: 10),
      ],
    ];
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.teal900)),
          pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900)),
        ],
      ),
    );
  }

  static pw.Widget _sectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      margin: const pw.EdgeInsets.only(bottom: 6, top: 12),
      decoration: const pw.BoxDecoration(
        color: PdfColors.teal700,
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      ),
    );
  }

  static pw.Widget _clinicalBlock(String label, String? content) {
    if (content == null || content.trim().isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.teal800, fontSize: 9.5)),
          pw.SizedBox(height: 2),
          pw.Text(content, style: const pw.TextStyle(fontSize: 9.5), textAlign: pw.TextAlign.justify),
        ],
      ),
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey800),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildChargesTable(Bill bill, List<BillItem> items, double consultation, double procedures, double additional) {
    if (items.isNotEmpty) {
      return pw.TableHelper.fromTextArray(
        headers: ['#', 'Description', 'Amount (INR)'],
        data: items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value;
          return [
            '$idx',
            item.itemDescription,
            'INR ${item.amount.toStringAsFixed(2)}',
          ];
        }).toList(),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
        cellStyle: const pw.TextStyle(fontSize: 9.5),
        cellAlignment: pw.Alignment.centerLeft,
      );
    } else {
      return pw.TableHelper.fromTextArray(
        headers: ['Description', 'Amount (INR)'],
        data: [
          if (consultation > 0) ['Doctor Consultation Fee', 'INR ${consultation.toStringAsFixed(2)}'],
          if (procedures > 0) ['Procedure Charges', 'INR ${procedures.toStringAsFixed(2)}'],
          if (additional > 0) ['Additional Charges', 'INR ${additional.toStringAsFixed(2)}'],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
        cellStyle: const pw.TextStyle(fontSize: 9.5),
        cellAlignment: pw.Alignment.centerLeft,
      );
    }
  }

  static pw.Widget _summaryRow(String label, String value, {bool isBold = false, double fontSize = 9.5, PdfColor? color}) {
    final style = pw.TextStyle(
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: fontSize,
      color: color ?? PdfColors.black,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
