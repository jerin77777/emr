import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../database/database_helper.dart';
import '../services/document_text_extractor.dart';
import '../services/investigation_parser_service.dart';

class InvestigationReviewDialog extends StatefulWidget {
  final InvestigationReport report;
  final VoidCallback onSaved;

  const InvestigationReviewDialog({
    super.key,
    required this.report,
    required this.onSaved,
  });

  @override
  State<InvestigationReviewDialog> createState() => _InvestigationReviewDialogState();
}

class _InvestigationReviewDialogState extends State<InvestigationReviewDialog> {
  late TextEditingController _typeController;
  late TextEditingController _modalityController;
  late TextEditingController _studyDateController;
  late TextEditingController _findingsController;
  late TextEditingController _impressionController;

  List<InvestigationMeasurement> _measurements = [];
  List<InvestigationDiagnosis> _diagnoses = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _status = 'needs_review';

  @override
  void initState() {
    super.initState();
    _typeController = TextEditingController(text: widget.report.investigationType ?? widget.report.category ?? 'General');
    _modalityController = TextEditingController(text: widget.report.modality ?? 'LAB');
    _studyDateController = TextEditingController(text: widget.report.studyDate ?? widget.report.reportDate ?? '');
    _findingsController = TextEditingController(text: widget.report.findingsText ?? '');
    _impressionController = TextEditingController(text: widget.report.impressionText ?? '');
    _status = widget.report.extractionStatus ?? 'needs_review';

    _loadExistingOrProcess();
  }

  @override
  void dispose() {
    _typeController.dispose();
    _modalityController.dispose();
    _studyDateController.dispose();
    _findingsController.dispose();
    _impressionController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingOrProcess() async {
    setState(() => _isLoading = true);

    if (widget.report.id != null) {
      final existingMeasurements = await DatabaseHelper.instance.getMeasurementsForReport(widget.report.id!);
      final existingDiagnoses = await DatabaseHelper.instance.getDiagnosesForReport(widget.report.id!);

      if (existingMeasurements.isNotEmpty || (widget.report.rawText != null && widget.report.rawText!.isNotEmpty)) {
        setState(() {
          _measurements = existingMeasurements;
          _diagnoses = existingDiagnoses;
          _isLoading = false;
        });
        return;
      }
    }

    // Run fresh extraction if no measurements exist
    await _runExtraction();
  }

  Future<void> _runExtraction() async {
    setState(() => _isLoading = true);

    try {
      final file = File(widget.report.filePath);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _status = 'failed';
        });
        return;
      }

      // 1. Unified text extraction & hash fingerprinting
      final extractResult = await DocumentTextExtractor.instance.extractText(file);
      final hash = await DocumentTextExtractor.instance.calculateFileHash(file);
      final duplicate = await DatabaseHelper.instance.getInvestigationReportByHash(hash);
      if (duplicate != null && duplicate.id != widget.report.id) {
        debugPrint('Existing duplicate report detected for hash: $hash');
      }

      // 2. Medical parsing
      final parsed = InvestigationParserService.instance.parseRawReportText(
        rawText: extractResult.rawText,
        reportId: widget.report.id ?? 0,
        reportUuid: widget.report.reportUuid,
      );

      setState(() {
        _typeController.text = parsed.investigationType;
        if (parsed.modality != null) _modalityController.text = parsed.modality!;
        if (parsed.studyDate != null) _studyDateController.text = parsed.studyDate!;
        if (parsed.findingsText != null) _findingsController.text = parsed.findingsText!;
        if (parsed.impressionText != null) _impressionController.text = parsed.impressionText!;
        _measurements = parsed.measurements;
        _diagnoses = parsed.diagnoses;
        _status = 'needs_review';
        _isLoading = false;
      });

      // Save raw extraction state
      if (widget.report.id != null) {
        await DatabaseHelper.instance.saveInvestigationExtraction(
          reportId: widget.report.id!,
          reportUuid: widget.report.reportUuid,
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
      }
    } catch (e) {
      debugPrint('Error running extraction: $e');
      setState(() {
        _isLoading = false;
        _status = 'failed';
      });
    }
  }

  Future<void> _saveAndVerify() async {
    if (widget.report.id == null) return;
    setState(() => _isSaving = true);

    try {
      final verifiedMeasurements = _measurements.map((m) => m.copyWith(verified: true)).toList();
      final verifiedDiagnoses = _diagnoses.map((d) => InvestigationDiagnosis(
        id: d.id,
        reportId: d.reportId,
        reportUuid: d.reportUuid,
        diagnosisText: d.diagnosisText,
        icd10Code: d.icd10Code,
        confidence: d.confidence,
        verified: true,
      )).toList();

      await DatabaseHelper.instance.saveInvestigationExtraction(
        reportId: widget.report.id!,
        reportUuid: widget.report.reportUuid,
        status: 'verified',
        rawText: widget.report.rawText ?? '',
        studyDate: _studyDateController.text.trim(),
        modality: _modalityController.text.trim(),
        investigationType: _typeController.text.trim(),
        findingsText: _findingsController.text.trim(),
        impressionText: _impressionController.text.trim(),
        measurements: verifiedMeasurements,
        diagnoses: verifiedDiagnoses,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical data verified & saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving verification: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addMeasurementRow() {
    showDialog(
      context: context,
      builder: (context) {
        final nameCtrl = TextEditingController();
        final valCtrl = TextEditingController();
        final unitCtrl = TextEditingController();
        final refCtrl = TextEditingController();

        return AlertDialog(
          title: const Text('Add Clinical Measurement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Parameter Name (e.g. EF, LVIDd, Hb)')),
              TextField(controller: valCtrl, decoration: const InputDecoration(labelText: 'Measured Value (e.g. 60, 40, 13.5)')),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit (e.g. %, mm, g/dL)')),
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference Range (e.g. >50%, 37-53 mm)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty && valCtrl.text.trim().isNotEmpty) {
                  final numVal = double.tryParse(valCtrl.text.trim());
                  setState(() {
                    _measurements.add(InvestigationMeasurement(
                      reportId: widget.report.id ?? 0,
                      reportUuid: widget.report.reportUuid,
                      parameterName: nameCtrl.text.trim(),
                      valueNumeric: numVal,
                      valueText: valCtrl.text.trim() + (unitCtrl.text.trim().isNotEmpty ? ' ${unitCtrl.text.trim()}' : ''),
                      unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : null,
                      referenceRange: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                      confidence: 1.0,
                      verified: true,
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rep = widget.report;
    final isVerified = _status == 'verified';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.biotech, color: Colors.teal.shade800, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medical Data Extraction & Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                        Text('Document: ${rep.title} (${rep.fileName ?? "File"})', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
                Chip(
                  avatar: Icon(isVerified ? Icons.check_circle : Icons.error_outline, size: 16, color: isVerified ? Colors.green.shade900 : Colors.orange.shade900),
                  label: Text(isVerified ? 'VERIFIED DATA' : 'NEEDS REVIEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isVerified ? Colors.green.shade900 : Colors.orange.shade900)),
                  backgroundColor: isVerified ? Colors.green.shade50 : Colors.orange.shade50,
                ),
              ],
            ),
            const Divider(height: 24),

            // Content Area: Side-by-side or Main Panel
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Extracting medical values & structuring data...', style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Document File Info & Quick Actions
                        SizedBox(
                          width: 300,
                          child: Card(
                            color: Colors.teal.shade50.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Original Document Info', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                                  const SizedBox(height: 12),
                                  _infoTile('Title', rep.title),
                                  _infoTile('Format', (rep.fileType ?? 'pdf').toUpperCase()),
                                  _infoTile('Category', rep.category ?? 'General'),
                                  _infoTile('Report Date', rep.reportDate ?? 'N/A'),
                                  const Spacer(),
                                  const Divider(),
                                  const Text(
                                    'Authoritative Source Rule:\nOriginal uploaded report is never modified. Extracted values are derived clinical records.',
                                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _runExtraction,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Reprocess OCR'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Right Column: Editable Medical Extraction Data
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Editable Meta
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _typeController,
                                        decoration: const InputDecoration(labelText: 'Investigation Type', border: OutlineInputBorder()),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _modalityController,
                                        decoration: const InputDecoration(labelText: 'Modality (US, CT, MRI, ECG, LAB)', border: OutlineInputBorder()),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _studyDateController,
                                        decoration: const InputDecoration(labelText: 'Study / Test Date', border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Measurements Section
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Extracted Clinical Measurements (${_measurements.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal.shade900)),
                                    ElevatedButton.icon(
                                      onPressed: _addMeasurementRow,
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Add Parameter'),
                                      style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                if (_measurements.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                    child: const Text('No structured numerical measurements detected. You can manually add parameters using the button above.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  )
                                else
                                  Table(
                                    border: TableBorder.all(color: Colors.teal.shade200, width: 1),
                                    columnWidths: const {
                                      0: FlexColumnWidth(2),
                                      1: FlexColumnWidth(1.5),
                                      2: FlexColumnWidth(1),
                                      3: FlexColumnWidth(2),
                                      4: FlexColumnWidth(1),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(color: Colors.teal.shade100),
                                        children: const [
                                          Padding(padding: EdgeInsets.all(8), child: Text('Parameter', style: TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: EdgeInsets.all(8), child: Text('Value', style: TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: EdgeInsets.all(8), child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: EdgeInsets.all(8), child: Text('Reference Range', style: TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: EdgeInsets.all(8), child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                      ..._measurements.asMap().entries.map((entry) {
                                        final idx = entry.key;
                                        final m = entry.value;
                                        return TableRow(
                                          children: [
                                            Padding(padding: const EdgeInsets.all(8), child: Text(m.parameterName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                            Padding(padding: const EdgeInsets.all(8), child: Text(m.valueText)),
                                            Padding(padding: const EdgeInsets.all(8), child: Text(m.unit ?? '-')),
                                            Padding(padding: const EdgeInsets.all(8), child: Text(m.referenceRange ?? '-')),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                              onPressed: () {
                                                setState(() {
                                                  _measurements.removeAt(idx);
                                                });
                                              },
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                const SizedBox(height: 20),

                                // Findings
                                TextFormField(
                                  controller: _findingsController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Clinical Findings / Observations',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Impression
                                TextFormField(
                                  controller: _impressionController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Diagnostic Impression / Conclusion',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Footer Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAndVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.verified),
                  label: Text(_isSaving ? 'Saving...' : 'Verify Extraction'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
