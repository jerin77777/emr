import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../database/database_helper.dart';
import '../models/models.dart';

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
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    if (widget.items != null) {
      _items = widget.items!;
    } else if (widget.bill.id != null) {
      _fetchItems();
    }
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

  Future<Uint8List> _generateBillPdf() async {
    final b = widget.bill;
    final p = widget.patient;
    final pdf = pw.Document();

    final billDateStr = b.billDate ?? DateTime.now().toString().split(' ')[0];
    final paymentStatus = b.paymentStatus ?? 'Paid';
    final paymentMethod = b.paymentMethod ?? 'Cash';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('ANYTHING EMR CLINIC', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.SizedBox(height: 4),
                    pw.Text('PATIENT INVOICE & RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                    pw.SizedBox(height: 16),
                  ],
                ),
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Invoice #: ${b.billNumber}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('Date: $billDateStr', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Status: $paymentStatus', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: paymentStatus == 'Paid' ? PdfColors.green900 : PdfColors.amber900)),
                      pw.SizedBox(height: 2),
                      pw.Text('Method: $paymentMethod', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
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
                        pw.Text('Patient: ${p.fullName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                        pw.SizedBox(height: 2),
                        pw.Text('Code: ${p.patientCode}', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Mobile: ${p.mobileNumber}', style: const pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 2),
                        pw.Text('${p.gender} | ${p.age ?? "N/A"} yrs', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Itemized Charges Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.SizedBox(height: 8),
              if (_items.isNotEmpty)
                pw.TableHelper.fromTextArray(
                  headers: ['#', 'Description', 'Amount (INR)'],
                  data: _items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    return [
                      '$idx',
                      item.itemDescription,
                      'INR ${item.amount.toStringAsFixed(2)}',
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                  cellStyle: const pw.TextStyle(fontSize: 11),
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Description', 'Amount (INR)'],
                  data: [
                    if ((b.consultationCharges ?? 0) > 0)
                      ['Doctor Consultation Fee', 'INR ${b.consultationCharges!.toStringAsFixed(2)}'],
                    if ((b.procedureCharges ?? 0) > 0)
                      ['Procedure Charges', 'INR ${b.procedureCharges!.toStringAsFixed(2)}'],
                    if ((b.additionalCharges ?? 0) > 0)
                      ['Additional Charges', 'INR ${b.additionalCharges!.toStringAsFixed(2)}'],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                  cellStyle: const pw.TextStyle(fontSize: 11),
                ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 8),
              if ((b.discountAmount ?? 0) > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount Applied:', style: pw.TextStyle(color: PdfColors.red900, fontSize: 11)),
                    pw.Text('- INR ${b.discountAmount!.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ],
                ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL AMOUNT PAYABLE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text('INR ${b.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.teal900)),
                ],
              ),
              pw.Spacer(),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('Thank you for visiting Anything EMR Clinic!', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  void _openFileExternally(String filePath) {
    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', '', filePath]);
      } else if (Platform.isMacOS) {
        Process.run('open', [filePath]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [filePath]);
      }
    } catch (e) {
      debugPrint('Could not open PDF file externally: $e');
    }
  }

  Future<void> _handlePdfPrint() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await _generateBillPdf();

      Directory? downloadsDir;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final docDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory(path.join(docDir.parent.path, 'Downloads'));
        if (!await downloadsDir.exists()) {
          downloadsDir = docDir;
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final fileName = 'Invoice_${widget.bill.billNumber}.pdf';
      final filePath = path.join(downloadsDir.path, fileName);
      final pdfFile = File(filePath);
      await pdfFile.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice PDF generated & downloaded: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => _openFileExternally(filePath),
            ),
          ),
        );
      }
      _openFileExternally(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  String _generatePrintText() {
    final b = widget.bill;
    final p = widget.patient;
    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('          ANYTHING EMR CLINIC & HEALTHCARE          ');
    buffer.writeln('             PATIENT INVOICE & RECEIPT              ');
    buffer.writeln('====================================================');
    buffer.writeln('Invoice No   : ${b.billNumber}');
    buffer.writeln('Date         : ${b.billDate ?? DateTime.now().toString().split(' ')[0]}');
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
    buffer.writeln('     Thank you for visiting Anything EMR Clinic!    ');
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
                    Center(
                      child: Column(
                        children: [
                          Text('ANYTHING EMR CLINIC', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          const Text('INVOICE / RECEIPT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black87)),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Info Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Invoice #: ${b.billNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Date: ${b.billDate ?? "N/A"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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
                              Text('Code: ${p.patientCode}', style: const TextStyle(fontSize: 12)),
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
          onPressed: _isGeneratingPdf ? null : _handlePdfPrint,
          icon: _isGeneratingPdf
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.print),
          label: const Text('Print', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
