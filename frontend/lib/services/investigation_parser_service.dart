import '../models/models.dart';

class ParsedMedicalData {
  final String investigationType;
  final String? modality;
  final String? studyDate;
  final String? reportDate;
  final String? extractedPatientName;
  final String? extractedAgeSex;
  final String? findingsText;
  final String? impressionText;
  final List<InvestigationMeasurement> measurements;
  final List<InvestigationDiagnosis> diagnoses;
  final String cleanClinicalText;

  const ParsedMedicalData({
    required this.investigationType,
    this.modality,
    this.studyDate,
    this.reportDate,
    this.extractedPatientName,
    this.extractedAgeSex,
    this.findingsText,
    this.impressionText,
    required this.measurements,
    required this.diagnoses,
    required this.cleanClinicalText,
  });
}

class InvestigationParserService {
  static final InvestigationParserService instance = InvestigationParserService._internal();
  InvestigationParserService._internal();

  /// Extract structured medical data from raw report text
  ParsedMedicalData parseRawReportText({
    required String rawText,
    required int reportId,
    required String reportUuid,
  }) {
    if (rawText.trim().isEmpty) {
      return ParsedMedicalData(
        investigationType: 'General Investigation',
        measurements: [],
        diagnoses: [],
        cleanClinicalText: '',
      );
    }

    // 1. Noise Filtering: Remove hospital branding, addresses, phone numbers, footers, website artifacts
    final lines = rawText.split('\n');
    final List<String> cleanLines = [];
    final List<String> filteredHeaderNoise = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (_isHeaderFooterNoise(trimmed)) {
        filteredHeaderNoise.add(trimmed);
        continue;
      }
      cleanLines.add(trimmed);
    }

    final cleanText = cleanLines.join('\n');

    // 2. Extract Study Metadata (Dates, Modality, Patient Name)
    final modality = _extractModality(cleanText);
    final studyDate = _extractDate(cleanText, ['study date', 'date of study', 'reported on', 'test date', 'date']);
    final reportDate = _extractDate(cleanText, ['report date', 'reported date', 'dated', 'result date']);
    final patientName = _extractPatientName(cleanText);
    final ageSex = _extractAgeSex(cleanText);

    // 3. Classify Investigation Type
    final type = _classifyInvestigationType(cleanText);

    // 4. Extract Structured Measurements
    final measurements = _extractMeasurements(
      cleanLines: cleanLines,
      reportId: reportId,
      reportUuid: reportUuid,
      type: type,
    );

    // 5. Extract Findings & Impression
    final findings = _extractSection(cleanText, ['FINDINGS', 'CLINICAL FINDINGS', 'OBSERVATIONS']);
    final impression = _extractSection(cleanText, ['IMPRESSION', 'CONCLUSION', 'OPINION', 'DIAGNOSTIC IMPRESSION', 'SUMMARY']);

    // 6. Extract Explicit Diagnoses
    final diagnoses = _extractExplicitDiagnoses(
      cleanText: cleanText,
      reportId: reportId,
      reportUuid: reportUuid,
    );

    return ParsedMedicalData(
      investigationType: type,
      modality: modality,
      studyDate: studyDate,
      reportDate: reportDate,
      extractedPatientName: patientName,
      extractedAgeSex: ageSex,
      findingsText: findings,
      impressionText: impression,
      measurements: measurements,
      diagnoses: diagnoses,
      cleanClinicalText: cleanText,
    );
  }

  bool _isHeaderFooterNoise(String line) {
    final lower = line.toLowerCase();
    
    // Check contact & registration noise
    if (RegExp(r'(phone|tel|mobile|fax|email|website|www\.|http|cin:|gstin|regd office|address|street|road|pincode|zip|copyright|all rights reserved|page \d+ of \d+|printed on)').hasMatch(lower)) {
      return true;
    }
    // Check common hospital footer disclaimers
    if (lower.contains('electronically signed') ||
        lower.contains('computer generated') ||
        lower.contains('please correlate clinically') ||
        lower.contains('end of report') ||
        lower.contains('not for medico-legal')) {
      return true;
    }
    return false;
  }

  String? _extractModality(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('modality') && lower.contains('us')) return 'US (Ultrasound)';
    if (lower.contains('echocardiogram') || lower.contains('echo')) return 'US (Echocardiography)';
    if (lower.contains('ct scan') || lower.contains('computed tomography')) return 'CT Scan';
    if (lower.contains('mri') || lower.contains('magnetic resonance')) return 'MRI';
    if (lower.contains('x-ray') || lower.contains('radiograph')) return 'X-Ray';
    if (lower.contains('ecg') || lower.contains('ekg')) return 'ECG';
    return 'LAB';
  }

  String? _extractDate(String text, List<String> keywords) {
    final datePattern = RegExp(r'(\d{1,2}[-/\.]([0-9]{1,2}|[A-Za-z]{3})[-/\.]\d{2,4})');
    final lines = text.split('\n');

    for (var line in lines) {
      final lower = line.toLowerCase();
      for (var kw in keywords) {
        if (lower.contains(kw)) {
          final match = datePattern.firstMatch(line);
          if (match != null) {
            return _normalizeDate(match.group(1)!);
          }
        }
      }
    }

    final match = datePattern.firstMatch(text);
    return match != null ? _normalizeDate(match.group(1)!) : null;
  }

  String _normalizeDate(String rawDate) {
    final clean = rawDate.replaceAll('.', '-').replaceAll('/', '-');
    return clean;
  }

  String _truncateMetadataLine(String remainingText, List<String> stopKeywords) {
    var cleaned = remainingText.trim();
    if (cleaned.startsWith(':') || cleaned.startsWith('-')) {
      cleaned = cleaned.substring(1).trim();
    }
    
    final lower = cleaned.toLowerCase();
    int minIndex = cleaned.length;
    
    for (final kw in stopKeywords) {
      final index = lower.indexOf(kw.toLowerCase());
      if (index != -1 && index < minIndex) {
        minIndex = index;
      }
    }
    
    return cleaned.substring(0, minIndex).trim();
  }

  bool _matchesAlias(String lowerLine, String alias) {
    final lowerAlias = alias.toLowerCase();
    if (!lowerLine.contains(lowerAlias)) return false;
    
    if (lowerAlias.length <= 3) {
      int index = 0;
      while (true) {
        index = lowerLine.indexOf(lowerAlias, index);
        if (index == -1) return false;
        
        bool beforeOk = true;
        if (index > 0) {
          final charBefore = lowerLine.codeUnitAt(index - 1);
          if ((charBefore >= 97 && charBefore <= 122) || (charBefore >= 48 && charBefore <= 57)) {
            beforeOk = false;
          }
        }
        
        bool afterOk = true;
        final endIdx = index + lowerAlias.length;
        if (endIdx < lowerLine.length) {
          final charAfter = lowerLine.codeUnitAt(endIdx);
          if ((charAfter >= 97 && charAfter <= 122) || (charAfter >= 48 && charAfter <= 57)) {
            afterOk = false;
          }
        }
        
        if (beforeOk && afterOk) {
          return true;
        }
        
        index += lowerAlias.length;
      }
    }
    
    return true;
  }

  String? _extractPatientName(String text) {
    final lowerText = text.toLowerCase();
    final labels = ['patient name', 'pt name', 'name'];
    
    for (final label in labels) {
      final labelIndex = lowerText.indexOf(label);
      if (labelIndex != -1) {
        final remaining = text.substring(labelIndex + label.length);
        final name = _truncateMetadataLine(remaining, [
          'study date',
          'reported on',
          'reported date',
          'hospital no',
          'hospital',
          'accession',
          'modality',
          'referred',
          'age',
          'sex',
          'date',
        ]);
        if (name.length > 2) {
          return name;
        }
      }
    }
    return null;
  }

  String? _extractAgeSex(String text) {
    final lowerText = text.toLowerCase();
    final labels = ['age/sex', 'age / sex', 'age'];
    
    for (final label in labels) {
      final labelIndex = lowerText.indexOf(label);
      if (labelIndex != -1) {
        final remaining = text.substring(labelIndex + label.length);
        final ageSex = _truncateMetadataLine(remaining, [
          'hospital no',
          'hospital',
          'modality',
          'referred',
          'study date',
          'reported',
          'accession',
          'date',
          'sex',
        ]);
        if (ageSex.isNotEmpty) {
          return ageSex;
        }
      }
    }
    return null;
  }

  String _classifyInvestigationType(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('transthoracic') || lower.contains('echo') || lower.contains('lvid')) {
      return 'Echocardiography';
    }
    if (lower.contains('complete blood count') || lower.contains('cbc') || lower.contains('hemoglobin')) {
      return 'Complete Blood Count (CBC)';
    }
    if (lower.contains('lipid') || lower.contains('cholesterol') || lower.contains('triglyceride')) {
      return 'Lipid Profile';
    }
    if (lower.contains('liver function') || lower.contains('lft') || lower.contains('bilirubin')) {
      return 'Liver Function Test (LFT)';
    }
    if (lower.contains('kidney function') || lower.contains('kft') || lower.contains('renal') || lower.contains('creatinine')) {
      return 'Renal / Kidney Function Test';
    }
    if (lower.contains('thyroid') || lower.contains('tsh') || lower.contains('t3') || lower.contains('t4')) {
      return 'Thyroid Profile';
    }
    if (lower.contains('ecg') || lower.contains('electrocardiogram') || lower.contains('heart rate')) {
      return 'ECG / Electrocardiogram';
    }
    if (lower.contains('chest') || lower.contains('x-ray') || lower.contains('radiology')) {
      return 'Radiology / Imaging';
    }
    return 'General Pathology';
  }

  List<InvestigationMeasurement> _extractMeasurements({
    required List<String> cleanLines,
    required int reportId,
    required String reportUuid,
    required String type,
  }) {
    final List<InvestigationMeasurement> list = [];

    // Target Medical Parameter Libraries
    final Map<String, List<String>> parameterAliases = {
      'LVIDd': ['lvidd', 'lvid (d)', 'lvid d', 'lvid-d', 'lv end diastolic diameter'],
      'LVIDs': ['lvids', 'lvid (s)', 'lvid s', 'lvid-s', 'lv end systolic diameter'],
      'IVSD': ['ivsd', 'ivs (d)', 'ivs d', 'interventricular septum'],
      'LVPWd': ['lvpwd', 'lvpw (d)', 'lvpw d', 'posterior wall thickness'],
      'EDV': ['edv', 'end diastolic volume'],
      'ESV': ['esv', 'end systolic volume'],
      'EF': ['ef', 'ejection fraction', 'lvef', 'ef%'],
      'FS': ['fs', 'fractional shortening', 'fs (%)'],
      'LV GLS': ['lv gls', 'gls'],
      'RV Basal Diameter': ['basal diameter', 'rv basal'],
      'RV Mid Diameter': ['mid diameter', 'rv mid'],
      'TAPSE': ['tapse', 'tricuspid annular plane systolic excursion'],
      'RV Fractional Area Change': ['fractional area change', 'rv fac', 'fac'],
      'Aorta': ['aorta', 'ao root', 'aortic root'],
      'Annulus': ['annulus', 'aortic annulus'],
      'Sinus of Valsalva': ['sinus of valsalva', 'sinus valsalva'],
      'Sinotubular Junction': ['sinotubular junction', 'st junction'],
      'Ascending Aorta': ['ascending aorta'],
      'LA Dimension': ['la dimension', 'left atrium', 'la'],
      'RA Dimension': ['ra dimension', 'right atrium', 'ra'],
      'Hemoglobin': ['hemoglobin', 'hb', 'hgb'],
      'WBC': ['wbc', 'total leucocyte count', 'tlc', 'white blood cells'],
      'RBC': ['rbc', 'total rbc count', 'red blood cells'],
      'Platelets': ['platelet count', 'platelets', 'plt'],
      'Creatinine': ['serum creatinine', 'creatinine', 'creat'],
      'Urea': ['blood urea', 'urea', 'bun'],
      'eGFR': ['egfr', 'estimated gfr'],
      'Total Cholesterol': ['total cholesterol', 'cholesterol total', 's.cholesterol'],
      'HDL': ['hdl', 'hdl cholesterol'],
      'LDL': ['ldl', 'ldl cholesterol'],
      'Triglycerides': ['triglycerides', 'tg', 's.triglycerides'],
      'Bilirubin (Total)': ['total bilirubin', 'bilirubin total', 's.bilirubin'],
      'SGOT / AST': ['sgot', 'ast', 'sgot (ast)'],
      'SGPT / ALT': ['sgpt', 'alt', 'sgpt (alt)'],
      'Alkaline Phosphatase': ['alkaline phosphatase', 'alp'],
      'TSH': ['tsh', 'thyroid stimulating hormone'],
      'Heart Rate': ['heart rate', 'hr', 'pulse rate'],
      'PR Interval': ['pr interval', 'p-r interval'],
      'QRS Duration': ['qrs duration', 'qrs interval', 'qrs'],
      'QT/QTc': ['qt/qtc', 'qtc', 'qt interval'],
    };

    final numberPattern = RegExp(r'(-?\d+(?:\.\d+)?)');
    final rangePattern = RegExp(r'([<>≤≥]\s*-?\d+(?:\.\d+)?(?:\s*[a-zA-Z/%]+)?|\d+(?:\.\d+)?\s*[-–to:]+\s*\d+(?:\.\d+)?(?:\s*[a-zA-Z/%]+)?)');

    for (var line in cleanLines) {
      final lowerLine = line.toLowerCase();
      if (lowerLine.contains('parameters') || lowerLine.contains('measured values') || lowerLine.contains('normal values')) {
        continue;
      }

      parameterAliases.forEach((stdName, aliases) {
        for (var alias in aliases) {
          if (_matchesAlias(lowerLine, alias)) {
            // Check if line has a dash '-' indicating unmeasured/none
            if (line.trim().endsWith('-') || line.contains('\t-\t')) {
              // Parameter listed with no value (-)
              break;
            }

            final numbers = numberPattern.allMatches(line).map((m) => m.group(1)!).toList();
            if (numbers.isNotEmpty) {
              final valStr = numbers.first;
              final valNum = double.tryParse(valStr);

              // Extract Unit
              String? unit = _extractUnit(line);
              if (unit == null && (stdName == 'EF' || stdName == 'FS')) unit = '%';
              if (unit == null && (stdName.contains('LVID') || stdName.contains('IVS') || stdName.contains('LVPW') || stdName.contains('Aorta') || stdName.contains('LA') || stdName.contains('RA') || stdName.contains('Diameter') || stdName.contains('TAPSE'))) {
                unit = 'mm';
              }

              // Extract Reference Range
              final rangeMatch = rangePattern.firstMatch(line);
              String? refRange = rangeMatch?.group(1);
              if (refRange == valStr && numbers.length > 1) {
                // If first match matched the value, check if range is after value
                final afterVal = line.substring(line.indexOf(valStr) + valStr.length);
                final rangeMatchAfter = rangePattern.firstMatch(afterVal);
                if (rangeMatchAfter != null) {
                  refRange = rangeMatchAfter.group(1);
                }
              }

              // Check Abnormal Flag
              String? flag;
              if (lowerLine.contains('high') || lowerLine.contains(' (h)') || lowerLine.contains('*h*')) flag = 'HIGH';
              if (lowerLine.contains('low') || lowerLine.contains(' (l)') || lowerLine.contains('*l*')) flag = 'LOW';
              if (lowerLine.contains('abnormal') || lowerLine.contains('critical')) flag = 'ABNORMAL';

              // Calculate confidence
              double confidence = 0.95;

              // Avoid duplicate parameter entry for same line
              if (!list.any((item) => item.parameterName == stdName)) {
                list.add(InvestigationMeasurement(
                  reportId: reportId,
                  reportUuid: reportUuid,
                  parameterName: stdName,
                  valueNumeric: valNum,
                  valueText: valStr + (unit != null && !valStr.contains(unit) ? ' $unit' : ''),
                  unit: unit,
                  referenceRange: refRange,
                  abnormalFlag: flag,
                  confidence: confidence,
                  verified: false,
                  pageNumber: 1,
                ));
              }
            }
            break;
          }
        }
      });
    }

    // 6. Generic Parameter Fallback Extractor (for new/unknown parameters)
    for (var line in cleanLines) {
      final lowerLine = line.toLowerCase();
      
      // Skip header lines or lines containing noise keywords
      if (lowerLine.contains('parameters') || 
          lowerLine.contains('measured values') || 
          lowerLine.contains('normal values') ||
          lowerLine.contains('patient') ||
          lowerLine.contains('study') ||
          lowerLine.contains('reported') ||
          lowerLine.contains('physician') ||
          lowerLine.contains('doctor') ||
          lowerLine.contains('hospital') ||
          lowerLine.contains('referred') ||
          lowerLine.contains('address') ||
          lowerLine.contains('date') ||
          lowerLine.contains('page') ||
          lowerLine.contains('about:')) {
        continue;
      }
      
      // Check if this line was already matched to a known parameter
      final isAlreadyMatched = list.any((m) => lowerLine.contains(m.parameterName.toLowerCase()));
      if (isAlreadyMatched) continue;
      
      // Find the first number in the line
      final numbers = numberPattern.allMatches(line).map((m) => m.group(1)!).toList();
      if (numbers.isNotEmpty) {
        final valStr = numbers.first;
        final valNum = double.tryParse(valStr);
        
        // Find index of the first number to extract parameter name
        final valIndex = line.indexOf(valStr);
        if (valIndex <= 1) continue; // Must have a name before the value
        
        var paramName = line.substring(0, valIndex).trim();
        
        // Clean paramName: remove trailing colons, dashes, spaces, tabs
        paramName = paramName.replaceAll(RegExp(r'[:\-\s\t]+$'), '').trim();
        
        // Validate parameter name length and content
        if (paramName.length < 2 || paramName.length > 40) continue;
        if (RegExp(r'^\d+$').hasMatch(paramName)) continue; // Can't be just numbers
        
        // Extract Unit
        String? unit = _extractUnit(line);
        
        // Extract Reference Range
        final rangeMatch = rangePattern.firstMatch(line);
        String? refRange = rangeMatch?.group(1);
        if (refRange == valStr && numbers.length > 1) {
          final afterVal = line.substring(valIndex + valStr.length);
          final rangeMatchAfter = rangePattern.firstMatch(afterVal);
          if (rangeMatchAfter != null) {
            refRange = rangeMatchAfter.group(1);
          }
        }
        
        // Add to list with a slightly lower confidence since it's a generic extraction
        if (!list.any((item) => item.parameterName.toLowerCase() == paramName.toLowerCase())) {
          list.add(InvestigationMeasurement(
            reportId: reportId,
            reportUuid: reportUuid,
            parameterName: paramName,
            valueNumeric: valNum,
            valueText: valStr + (unit != null && !valStr.contains(unit) ? ' $unit' : ''),
            unit: unit,
            referenceRange: refRange,
            confidence: 0.80,
            verified: false,
            pageNumber: 1,
          ));
        }
      }
    }

    return list;
  }

  String? _extractUnit(String line) {
    // 1. Dynamic unit extraction based on value position
    final numberPattern = RegExp(r'(-?\d+(?:\.\d+)?)');
    final match = numberPattern.firstMatch(line);
    if (match != null) {
      final valStr = match.group(1)!;
      final valIndex = line.indexOf(valStr);
      final remaining = line.substring(valIndex + valStr.length).trim();
      final words = remaining.split(RegExp(r'\s+'));
      if (words.isNotEmpty && words.first.isNotEmpty) {
        final firstWord = words.first;
        // Check if first word is a valid unit string (letters, slashes, percent, parentheses)
        // Ensure it doesn't contain digits or comparison operators
        if (RegExp(r'^[a-zA-Z%/\(\)]+$').hasMatch(firstWord) && 
            !RegExp(r'[0-9<>≤≥]').hasMatch(firstWord)) {
          // Normalize common unit casings
          final lowerWord = firstWord.toLowerCase();
          if (lowerWord == 'g/dl' || lowerWord == 'gm/dl') return 'g/dL';
          if (lowerWord == 'mg/dl') return 'mg/dL';
          if (lowerWord == 'ml') return 'mL';
          if (lowerWord == 'u/l' || lowerWord == 'iu/l') return 'U/L';
          if (lowerWord == '/ul') return '/uL';
          return firstWord;
        }
      }
    }

    // 2. Predefined fallback checks
    final lower = line.toLowerCase();
    if (lower.contains('g/dl') || lower.contains('gm/dl')) return 'g/dL';
    if (lower.contains('mg/dl')) return 'mg/dL';
    if (lower.contains('mm')) return 'mm';
    if (lower.contains('ml')) return 'mL';
    if (lower.contains('%')) return '%';
    if (lower.contains('u/l') || lower.contains('iu/l')) return 'U/L';
    if (lower.contains('ms')) return 'ms';
    if (lower.contains('bpm')) return 'bpm';
    if (lower.contains('cumm') || lower.contains('/ul')) return '/uL';
    if (lower.contains('lakhs')) return 'lakhs/uL';
    return null;
  }

  String? _extractSection(String text, List<String> headers) {
    final lines = text.split('\n');
    bool capturing = false;
    final List<String> captured = [];

    for (var line in lines) {
      final upper = line.trim().toUpperCase();

      if (!capturing) {
        for (var h in headers) {
          if (upper == h || upper.startsWith('$h:') || upper.startsWith('$h -')) {
            capturing = true;
            final content = line.substring(line.indexOf(h) + h.length).replaceAll(RegExp(r'^[:\-\s]+'), '').trim();
            if (content.isNotEmpty) captured.add(content);
            break;
          }
        }
      } else {
        // Stop capturing if next section starts
        if (upper.contains('IMPRESSION') ||
            upper.contains('FINDINGS') ||
            upper.contains('CONCLUSION') ||
            upper.contains('DIAGNOSIS') ||
            upper.contains('RECOMMENDATION')) {
          if (!headers.any((h) => upper.contains(h))) {
            break;
          }
        }
        captured.add(line.trim());
      }
    }

    return captured.isNotEmpty ? captured.join('\n') : null;
  }

  List<InvestigationDiagnosis> _extractExplicitDiagnoses({
    required String cleanText,
    required int reportId,
    required String reportUuid,
  }) {
    final List<InvestigationDiagnosis> list = [];
    final lines = cleanText.split('\n');
    bool inDiag = false;

    for (var line in lines) {
      final upper = line.trim().toUpperCase();
      if (upper.startsWith('DIAGNOSIS:') || upper == 'DIAGNOSIS' || upper.startsWith('CLINICAL DIAGNOSIS:')) {
        inDiag = true;
        final content = line.substring(line.indexOf('DIAGNOSIS') + 9).replaceAll(RegExp(r'^[:\-\s]+'), '').trim();
        if (content.isNotEmpty) {
          list.add(InvestigationDiagnosis(
            reportId: reportId,
            reportUuid: reportUuid,
            diagnosisText: content,
            confidence: 0.95,
            verified: false,
          ));
        }
      } else if (inDiag) {
        if (upper.contains('IMPRESSION') || upper.contains('FINDINGS') || upper.isEmpty) {
          break;
        }
        list.add(InvestigationDiagnosis(
          reportId: reportId,
          reportUuid: reportUuid,
          diagnosisText: line.trim(),
          confidence: 0.90,
          verified: false,
        ));
      }
    }

    return list;
  }
}
