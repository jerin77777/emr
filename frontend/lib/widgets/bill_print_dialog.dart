import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:printing/printing.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../services/document_pdf_generator.dart';
import '../utils/date_formatter.dart';

/// Common Invoice / Bill Print Preview Dialog Widget
class BillPrintPreviewDialog extends StatefulWidget {
  final Bill bill;
  final Patient patient;
  final List<BillItem>? items;

  const BillPrintPreviewDialog({
    super.key,
    required this.bill,
    required this.patient,
    this.items,
  });

  /// Helper static method to open the dialog easily
  static Future<void> show(
    BuildContext context, {
    required Bill bill,
    required Patient patient,
    List<BillItem>? items,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => BillPrintPreviewDialog(bill: bill, patient: patient, items: items),
    );
  }

  @override
  State<BillPrintPreviewDialog> createState() => _BillPrintPreviewDialogState();
}

class _BillPrintPreviewDialogState extends State<BillPrintPreviewDialog> {
  List<BillItem> _items = [];
  bool _isLoading = false;
  bool _isPrinting = false;
  String _clinicName = 'Neuron - The Clinic';
  String _clinicPhone = '8105129750';
  String _clinicWebsite = 'www.drsrajamani.in';
  String _developerName = 'Anything Ventures';
  String _developerWebsite = 'www.anythingventures.in';
  String? _doctorName;
  String? _resolvedSigPath;
  String? _doctorSpec;
  String? _doctorLicense;
  String? _doctorDegree;
  String? _doctorDesignation;

  @override
  void initState() {
    super.initState();
    _loadClinicSettings();
    if (widget.items != null) {
      _items = widget.items!;
    } else if (widget.bill.id != null) {
      _fetchItems();
    }
  }

  Future<void> _loadClinicSettings() async {
    try {
      final settings = await DatabaseHelper.instance.getClinicSettings();
      
      String? docName;
      String? sigPath;
      String? spec;
      String? license;
      String? degree;
      String? designation;
      if (widget.bill.visitId != null) {
        final visit = await DatabaseHelper.instance.getPatientVisitById(widget.bill.visitId!);
        if (visit?.doctorId != null) {
          final docUser = await DatabaseHelper.instance.getUserById(visit!.doctorId!);
          docName = docUser?.fullName;
          spec = docUser?.specialization;
          license = docUser?.licenseNumber;
          degree = docUser?.degree;
          designation = docUser?.designation;
          
          if (docUser != null) {
            if (visit.doctorSignatureVersion != null) {
              final appDir = await DatabaseHelper.getAppDirectoryPath();
              final versionedPath = path.join(
                appDir,
                'ClinicData',
                'users',
                docUser.userUuid,
                'signature',
                'processed',
                'signature_v${visit.doctorSignatureVersion}.png',
              );
              if (File(versionedPath).existsSync()) {
                sigPath = versionedPath;
              }
            }
            sigPath ??= docUser.signatureFilePath;
          }
        }
      }

      if (mounted) {
        setState(() {
          _clinicName = settings.clinicName;
          _clinicPhone = settings.telephone;
          _clinicWebsite = settings.website;
          _developerName = settings.developerName;
          _developerWebsite = settings.developerWebsite;
          _doctorName = docName;
          _resolvedSigPath = sigPath;
          _doctorSpec = spec;
          _doctorLicense = license;
          _doctorDegree = degree;
          _doctorDesignation = designation;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final list = await DatabaseHelper.instance.getBillItemsForBill(widget.bill.id!);
      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleNativePrint() async {
    setState(() => _isPrinting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // 1. Fetch Doctor details if available
      String? doctorName;
      if (widget.bill.visitId != null) {
        final visit = await DatabaseHelper.instance.getPatientVisitById(widget.bill.visitId!);
        if (visit?.doctorId != null) {
          final docUser = await DatabaseHelper.instance.getUserById(visit!.doctorId!);
          doctorName = docUser?.fullName;
        }
      }

      // 2. Generate PDF bytes using the reusable DocumentPdfGenerator
      final pdfBytes = await DocumentPdfGenerator.generateBillPdf(
        patient: widget.patient,
        bill: widget.bill,
        items: _items,
        doctorName: doctorName,
      );

      // 3. Trigger native printing
      final printed = await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Invoice_${widget.bill.billNumber}.pdf',
      );

      // 4. Save local copy and record in SQLite
      if (printed) {
        final dirPath = await DatabaseHelper.getPatientDocumentsDir(widget.patient.patientUuid, 'bills');
        final fileName = 'Invoice_${widget.bill.billNumber}.pdf';
        final filePath = path.join(dirPath, fileName);

        // Save PDF file locally
        final pdfFile = File(filePath);
        await pdfFile.writeAsBytes(pdfBytes);

        // Record document metadata in SQLite
        final docUuid = 'doc-${DateTime.now().millisecondsSinceEpoch}';
        final doc = Document(
          documentUuid: docUuid,
          patientId: widget.patient.id!,
          visitId: widget.bill.visitId,
          billId: widget.bill.id,
          documentType: 'bill',
          fileName: fileName,
          filePath: filePath,
        );
        await DatabaseHelper.instance.insertDocument(doc);

        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Invoice PDF saved and registered successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Print job failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  String _generatePrintText() {
    final b = widget.bill;
    final p = widget.patient;
    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('               ${_clinicName.toUpperCase()}         ');
    buffer.writeln('             PATIENT INVOICE & RECEIPT              ');
    buffer.writeln('====================================================');
    buffer.writeln('Invoice No   : ${b.billNumber}');
    buffer.writeln('Date         : ${DateFormatter.formatDate(b.billDate ?? DateTime.now().toIso8601String())}');
    buffer.writeln('Payment Stat : ${b.paymentStatus ?? "Paid"}');
    buffer.writeln('Payment Meth : ${b.paymentMethod ?? "Cash"}');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('PATIENT DETAILS:');
    buffer.writeln('Name   : ${p.fullName}');
    buffer.writeln('Code   : ${p.patientCode}');
    buffer.writeln('Mobile : ${p.mobileNumber}');
    buffer.writeln('Gender : ${p.gender} | Age: ${p.age ?? "N/A"} yrs');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('ITEMIZED CHARGES:');
    if (_items.isNotEmpty) {
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        buffer.writeln('${i + 1}. ${item.itemDescription.padRight(35)} ₹${item.amount.toStringAsFixed(2)}');
      }
    } else {
      if ((b.consultationCharges ?? 0) > 0) {
        buffer.writeln('1. Doctor Consultation Fee           ₹${b.consultationCharges!.toStringAsFixed(2)}');
      }
      if ((b.procedureCharges ?? 0) > 0) {
        buffer.writeln('2. Procedure Charges                ₹${b.procedureCharges!.toStringAsFixed(2)}');
      }
      if ((b.additionalCharges ?? 0) > 0) {
        buffer.writeln('3. Additional Charges               ₹${b.additionalCharges!.toStringAsFixed(2)}');
      }
    }
    buffer.writeln('----------------------------------------------------');
    if ((b.discountAmount ?? 0) > 0) {
      buffer.writeln('Discount Applied                   : -₹${b.discountAmount!.toStringAsFixed(2)}');
    }
    buffer.writeln('TOTAL AMOUNT PAYABLE               : ₹${b.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('AMOUNT PAID                        : ₹${b.paidAmount?.toStringAsFixed(2) ?? b.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('====================================================');
    buffer.writeln(' Powered by $_developerName ($_developerWebsite) ');
    buffer.writeln('====================================================');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final p = widget.patient;
    final printText = _generatePrintText();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt_long, color: Colors.teal.shade700, size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice ${b.billNumber}', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Billing & Payment Record', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Styled Printable Receipt Preview Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_clinicName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900, letterSpacing: 0.5)),
                              const SizedBox(height: 2),
                              Text('Phone: $_clinicPhone | Website: $_clinicWebsite', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              const SizedBox(height: 4),
                              const Text('INVOICE / RECEIPT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black87)),
                            ],
                          ),
                        ),
                        Container(
                          width: 70,
                          height: 35,
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('LOGO', style: TextStyle(fontSize: 8, color: Colors.grey), textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    // Info Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Invoice #: ${b.billNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Date: ${DateFormatter.formatDate(b.billDate ?? DateTime.now().toIso8601String())}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Chip(
                              label: Text(b.paymentStatus ?? 'Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (b.paymentStatus == 'Paid') ? Colors.green.shade900 : Colors.amber.shade900)),
                              backgroundColor: (b.paymentStatus == 'Paid') ? Colors.green.shade50 : Colors.amber.shade50,
                              visualDensity: VisualDensity.compact,
                            ),
                            Text('Method: ${b.paymentMethod ?? "Cash"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Patient Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('Patient ID: ${p.patientCode}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Mobile: ${p.mobileNumber}', style: const TextStyle(fontSize: 12)),
                              Text('${p.gender} | ${p.age ?? "N/A"} yrs', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Itemized Charges:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                    else if (_items.isNotEmpty)
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(4),
                          1: FlexColumnWidth(2),
                        },
                        border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.teal.shade100),
                            children: const [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                            ],
                          ),
                          ..._items.map((item) {
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(8.0), child: Text(item.itemDescription)),
                                Padding(padding: const EdgeInsets.all(8.0), child: Text('₹${item.amount.toStringAsFixed(2)}', textAlign: TextAlign.right)),
                              ],
                            );
                          }),
                        ],
                      )
                    else
                      Column(
                        children: [
                          if ((b.consultationCharges ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Doctor Consultation Fee'),
                                  Text('₹${b.consultationCharges!.toStringAsFixed(2)}'),
                                ],
                              ),
                            ),
                          if ((b.procedureCharges ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Procedure Charges'),
                                  Text('₹${b.procedureCharges!.toStringAsFixed(2)}'),
                                ],
                              ),
                            ),
                          if ((b.additionalCharges ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Additional Charges'),
                                  Text('₹${b.additionalCharges!.toStringAsFixed(2)}'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    const Divider(height: 24),
                    if ((b.discountAmount ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Discount:', style: TextStyle(color: Colors.red)),
                            Text('-₹${b.discountAmount!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL PAYABLE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('₹${b.totalAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal.shade900)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Receipt Generated via clinic billing portal', style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
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
                              Text(
                                '${_doctorName!}${_doctorDegree != null && _doctorDegree!.trim().isNotEmpty ? ", $_doctorDegree" : ""}',
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                              ),
                              if (_doctorDesignation != null && _doctorDesignation!.trim().isNotEmpty)
                                Text(_doctorDesignation!, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
                              Text(_doctorSpec ?? 'General Medicine', style: TextStyle(fontSize: 7, color: Colors.grey.shade700)),
                              if (_doctorLicense != null)
                                Text('License No: $_doctorLicense', style: TextStyle(fontSize: 7, color: Colors.grey.shade700)),
                            ] else ...[
                              Text('Authorized Signature', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
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
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: printText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invoice text copied to clipboard!')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy Text'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
          ),
          onPressed: _isPrinting ? null : _handleNativePrint,
          icon: _isPrinting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.print),
          label: const Text('Print', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
