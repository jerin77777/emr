import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../database/database_helper.dart';
import '../models/models.dart';

class DocumentPdfGenerator {
  /// Fetches clinic details from Settings. Fallbacks to default values if not defined.
  static Future<Map<String, String>> getClinicDetails() async {
    final name = await DatabaseHelper.instance.getSetting('clinic_name') ?? 'Anything EMR Clinic';
    final address = await DatabaseHelper.instance.getSetting('clinic_address') ?? '123 Health Ave, Medical City';
    final phone = await DatabaseHelper.instance.getSetting('clinic_phone') ?? '+1-555-0199';
    final email = await DatabaseHelper.instance.getSetting('clinic_email') ?? 'contact@anythingemr.com';
    final license = await DatabaseHelper.instance.getSetting('clinic_license') ?? 'REG-2026-9923';
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'license': license,
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
    final generatedAt = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

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
                  pw.Text('Visit UUID: ${visit.visitUuid}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
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
              children: [
                pw.Text('Generated: $generatedAt | Powered by Anything EMR', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
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
                    pw.Text(clinic['address']!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    pw.Text('Phone: ${clinic['phone']!} | Email: ${clinic['email']!}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('Reg/License No: ${clinic['license']!}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
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
                      pw.Expanded(child: _infoRow('Consultation Date', visit.visitDate?.split(' ')[0] ?? 'N/A')),
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
            _sectionHeader('1. CLINICAL SYMPTOMS & HISTORY'),
            _clinicalBlock('Chief Complaint', visit.chiefComplaint),
            _clinicalBlock('History of Present Illness', visit.history),
            _clinicalBlock('Past Medical History', visit.pastMedicalHistory),
            pw.SizedBox(height: 15),

            // 5. Vitals Section
            _sectionHeader('2. VITAL SIGNS & MEASUREMENTS'),
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
                    _tableCell(visit.vitalsBp != null && visit.vitalsBp!.trim().isNotEmpty ? visit.vitalsBp! : 'N/A'),
                    _tableCell(visit.vitalsPulse != null && visit.vitalsPulse!.trim().isNotEmpty ? visit.vitalsPulse! : 'N/A'),
                    _tableCell(visit.vitalsTemp != null && visit.vitalsTemp!.trim().isNotEmpty ? visit.vitalsTemp! : 'N/A'),
                    _tableCell(visit.vitalsSaturation != null && visit.vitalsSaturation!.trim().isNotEmpty ? visit.vitalsSaturation! : 'N/A'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // 6. Examination & Investigations
            _sectionHeader('3. EXAMINATION & INVESTIGATIONS'),
            _clinicalBlock('Systemic Examination', visit.systemicExamination),
            _clinicalBlock('Investigations Ordered', visit.investigations),
            pw.SizedBox(height: 15),

            // 7. Diagnosis & Plan
            _sectionHeader('4. DIAGNOSIS & PRESCRIPTION PLAN'),
            _clinicalBlock('Diagnosis', visit.diagnosis != null && visit.diagnosis!.isNotEmpty 
                ? '${visit.diagnosis!}${visit.diagnosisCode != null ? " (ICD-10: ${visit.diagnosisCode})" : ""}' 
                : null),
            _clinicalBlock('Advice & Prescriptions', visit.advice),
            _clinicalBlock('Referral To', visit.referralTo),
            _clinicalBlock('Follow-up Date', visit.followupDate),
            
            pw.SizedBox(height: 40),

            // 8. Sign-off Section (Will automatically wrap cleanly)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Generated by: Clinic ERP Portal', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('Visit UUID: ${visit.visitUuid}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 150,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                      ),
                      padding: const pw.EdgeInsets.only(bottom: 4),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Doctor\'s Authorized Signature', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    if (doctorName != null)
                      pw.Text(doctorName, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
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
    final generatedAt = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final billDateStr = bill.billDate ?? DateTime.now().toString().split(' ')[0];
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
              children: [
                pw.Text('Generated: $generatedAt | Thank you for your visit!', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
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
                    pw.Text(clinic['address']!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    pw.Text('Phone: ${clinic['phone']!} | Email: ${clinic['email']!}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
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
                    pw.Container(
                      width: 150,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                      ),
                      padding: const pw.EdgeInsets.only(bottom: 4),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
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
