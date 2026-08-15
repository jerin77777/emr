import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../database/database_helper.dart';

class SpellCheckService {
  static final SpellCheckService instance = SpellCheckService._internal();
  SpellCheckService._internal();

  final Set<String> _dictionary = {};
  final Set<String> _ignoredWords = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // Initialize the dictionary asynchronously
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Add common English words
    _dictionary.addAll(_commonWords);

    // 2. Add common medical abbreviations and drug names
    _dictionary.addAll(_medicalTerms);

    // 2b. Add Oxford 3000 English word list from assets
    try {
      final dictionaryData = await rootBundle.loadString('assets/dictionary.txt');
      final words = dictionaryData.split(RegExp(r'\r?\n'));
      for (var word in words) {
        final cleanWord = word.trim().toLowerCase();
        if (cleanWord.isNotEmpty) {
          _dictionary.add(cleanWord);
        }
      }
    } catch (e) {
      debugPrint('SpellCheckService: Error loading assets/dictionary.txt: $e');
    }

    try {
      // 3. Load user-added dictionary words from settings
      final customWordsJson = await DatabaseHelper.instance.getSetting('user_custom_words');
      if (customWordsJson != null && customWordsJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(customWordsJson);
        for (var word in decoded) {
          if (word is String) {
            _dictionary.add(word.toLowerCase());
          }
        }
      }

      // 4. Load ICD-10 codes and names from SQLite
      final db = await DatabaseHelper.instance.database;
      final icdList = await db.rawQuery('SELECT code, name_en FROM icd10_diagnoses');
      for (final row in icdList) {
        final code = row['code'] as String? ?? '';
        final name = row['name_en'] as String? ?? '';
        _dictionary.add(code.toLowerCase());
        
        // Split name into words and add them
        final nameWords = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').split(RegExp(r'\s+'));
        for (var w in nameWords) {
          if (w.trim().isNotEmpty) {
            _dictionary.add(w.trim().toLowerCase());
          }
        }
      }

      // 5. Load Doctor & Patient names
      final users = await db.rawQuery('SELECT full_name FROM users');
      for (final row in users) {
        final name = row['full_name'] as String? ?? '';
        final parts = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').split(RegExp(r'\s+'));
        for (var p in parts) {
          if (p.trim().isNotEmpty) {
            _dictionary.add(p.trim().toLowerCase());
          }
        }
      }

      final patients = await db.rawQuery('SELECT full_name FROM patients');
      for (final row in patients) {
        final name = row['full_name'] as String? ?? '';
        final parts = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').split(RegExp(r'\s+'));
        for (var p in parts) {
          if (p.trim().isNotEmpty) {
            _dictionary.add(p.trim().toLowerCase());
          }
        }
      }
    } catch (e) {
      debugPrint('SpellCheckService: Error loading database words: $e');
    }

    _isInitialized = true;
  }

  // Check if a word is spelled correctly or ignored
  bool isValidWord(String word) {
    final clean = word.toLowerCase().trim();
    if (clean.isEmpty) return true;
    
    // Ignore words that are purely numbers, abbreviations with dots/slashes, or short single characters
    if (RegExp(r'^\d+$').hasMatch(clean)) return true;
    if (clean.length <= 1) return true;
    
    // Check main dictionary and ignored list
    if (_dictionary.contains(clean) || _ignoredWords.contains(clean)) {
      return true;
    }
    
    // Suffix stripping rules to check inflected forms dynamically
    if (clean.endsWith('s') && clean.length > 2) {
      final base = clean.substring(0, clean.length - 1);
      if (_dictionary.contains(base)) return true;
    }
    if (clean.endsWith('es') && clean.length > 3) {
      final base = clean.substring(0, clean.length - 2);
      if (_dictionary.contains(base)) return true;
    }
    if (clean.endsWith('ed') && clean.length > 3) {
      final base1 = clean.substring(0, clean.length - 2);
      if (_dictionary.contains(base1)) return true;
      final base2 = clean.substring(0, clean.length - 1);
      if (_dictionary.contains(base2)) return true;
    }
    if (clean.endsWith('ing') && clean.length > 4) {
      final base1 = clean.substring(0, clean.length - 3);
      if (_dictionary.contains(base1)) return true;
      final base2 = '${clean.substring(0, clean.length - 3)}e';
      if (_dictionary.contains(base2)) return true;
    }
    if (clean.endsWith('ly') && clean.length > 3) {
      final base = clean.substring(0, clean.length - 2);
      if (_dictionary.contains(base)) return true;
    }
    
    return false;
  }

  // Generate suggestions using Levenshtein distance
  List<String> getSuggestions(String misspelledWord) {
    final cleanWord = misspelledWord.toLowerCase().trim();
    if (cleanWord.isEmpty) return [];

    final List<MapEntry<String, int>> candidates = [];

    for (final dictWord in _dictionary) {
      // Optimizations: skip words with length difference > 2
      if ((dictWord.length - cleanWord.length).abs() > 2) continue;

      final dist = _levenshtein(cleanWord, dictWord);
      if (dist <= 2) {
        candidates.add(MapEntry(dictWord, dist));
      }
    }

    // Sort by distance and then length difference
    candidates.sort((a, b) {
      final cmp = a.value.compareTo(b.value);
      if (cmp != 0) return cmp;
      return (a.key.length - cleanWord.length).abs().compareTo((b.key.length - cleanWord.length).abs());
    });

    return candidates.map((e) => e.key).take(5).toList();
  }

  // Add word permanently to user dictionary
  Future<void> addToDictionary(String word) async {
    final clean = word.toLowerCase().trim();
    if (clean.isEmpty) return;

    _dictionary.add(clean);

    try {
      final customWordsJson = await DatabaseHelper.instance.getSetting('user_custom_words');
      List<String> customWords = [];
      if (customWordsJson != null && customWordsJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(customWordsJson);
        customWords = decoded.whereType<String>().toList();
      }
      
      if (!customWords.contains(clean)) {
        customWords.add(clean);
        await DatabaseHelper.instance.saveSetting('user_custom_words', json.encode(customWords));
      }
    } catch (e) {
      debugPrint('SpellCheckService: Error saving word to dictionary: $e');
    }
  }

  // Ignore word for current application run session
  void ignoreWord(String word) {
    final clean = word.toLowerCase().trim();
    if (clean.isNotEmpty) {
      _ignoredWords.add(clean);
    }
  }

  // Levenshtein distance algorithm
  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }

  int _min3(int a, int b, int c) {
    int m = a < b ? a : b;
    return m < c ? m : c;
  }

  // Built-in list of common English words
  static const List<String> _commonWords = [
    'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i', 'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at', 'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her', 'she', 'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their', 'what', 'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me', 'when', 'make', 'can', 'like', 'time', 'no', 'just', 'him', 'know', 'take', 'people', 'into', 'year', 'your', 'good', 'some', 'could', 'them', 'see', 'other', 'than', 'then', 'now', 'look', 'only', 'come', 'its', 'over', 'think', 'also', 'back', 'after', 'use', 'two', 'how', 'our', 'work', 'first', 'well', 'way', 'even', 'new', 'want', 'because', 'any', 'these', 'give', 'day', 'most', 'us',
    'is', 'am', 'are', 'was', 'were', 'been', 'being', 'has', 'had', 'having', 'does', 'did', 'doing', 'can', 'could', 'will', 'would', 'shall', 'should', 'may', 'might', 'must',
    'my', 'your', 'his', 'her', 'its', 'our', 'their', 'mine', 'yours', 'hers', 'ours', 'theirs', 'me', 'him', 'us', 'them', 'myself', 'yourself', 'himself', 'herself', 'itself', 'ourselves', 'themselves',
    'who', 'whom', 'whose', 'which', 'what', 'that', 'this', 'these', 'those', 'each', 'every', 'either', 'neither', 'some', 'any', 'none', 'both', 'all', 'few', 'many', 'much', 'more', 'most', 'other', 'another',
    'about', 'above', 'across', 'after', 'against', 'along', 'among', 'around', 'at', 'before', 'behind', 'below', 'beneath', 'beside', 'between', 'beyond', 'by', 'despite', 'down', 'during', 'except', 'for', 'from', 'in', 'inside', 'into', 'like', 'near', 'of', 'off', 'on', 'onto', 'out', 'outside', 'over', 'past', 'since', 'through', 'throughout', 'till', 'to', 'toward', 'towards', 'under', 'underneath', 'until', 'up', 'upon', 'with', 'within', 'without',
    'although', 'because', 'before', 'if', 'since', 'unless', 'until', 'when', 'whenever', 'where', 'wherever', 'while', 'whereas', 'whether',
    'day', 'days', 'week', 'weeks', 'month', 'months', 'year', 'years', 'hour', 'hours', 'minute', 'minutes', 'second', 'seconds', 'today', 'tomorrow', 'yesterday', 'tonight', 'morning', 'afternoon', 'evening', 'night', 'midnight', 'noon', 'daily', 'weekly', 'monthly', 'yearly', 'once', 'twice', 'thrice', 'first', 'second', 'third', 'fourth', 'fifth', 'last', 'next', 'previous',
    'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'zero',
    'complain', 'complaining', 'complains', 'complaint', 'complaints', 'pain', 'fever', 'cough', 'cold', 'headache', 'swelling', 'nausea', 'vomiting', 'diarrhea', 'constipation', 'weakness', 'fatigue', 'dizziness', 'itching', 'rash', 'bleeding', 'injury', 'wound', 'history', 'chronic', 'acute', 'severe', 'mild', 'moderate', 'normal', 'abnormal', 'patient', 'doctor', 'clinic', 'visit', 'treatment', 'medicine', 'prescription', 'advice', 'referral', 'followup', 'vitals', 'saturation', 'pulse', 'temperature', 'blood', 'pressure', 'heart', 'rate', 'respiratory', 'system', 'exam', 'examination', 'investigation', 'reports', 'laboratory', 'test', 'scan', 'xray', 'ultrasound', 'mri', 'ct', 'urine', 'stool', 'negative', 'positive', 'reactive', 'nonreactive', 'elevated', 'decreased', 'within', 'limits', 'stable', 'improving', 'worse', 'unchanged',
    'present', 'presented', 'presenting', 'presents', 'report', 'reported', 'reporting', 'reports', 'state', 'stated', 'stating', 'states', 'show', 'showed', 'showing', 'shows', 'observe', 'observed', 'observing', 'observes', 'feel', 'feels', 'feeling', 'felt', 'give', 'gave', 'given', 'giving', 'gives', 'take', 'took', 'taken', 'taking', 'takes', 'prescribe', 'prescribed', 'prescribing', 'prescribes', 'recommend', 'recommended', 'recommending', 'recommends',
    'clear', 'lung', 'heart', 'breath', 'sound', 'sounds', 'murmur', 'chest', 'abdomen', 'soft', 'tender', 'tenderness', 'guarding', 'rigidity', 'bowel', 'organ', 'liver', 'spleen', 'kidney', 'kidneys', 'skin', 'dry', 'warm', 'moist', 'pale', 'icteric', 'cyanotic', 'edema', 'pedal', 'joint', 'swelling', 'motion', 'range', 'reflex', 'reflexes', 'pupil', 'pupils', 'equal', 'round', 'reactive', 'light', 'throat', 'congested', 'congestion', 'tonsil', 'tonsils', 'ear', 'ears', 'discharge', 'tympanic', 'membrane', 'intact',
    'advised', 'avoid', 'diet', 'exercise', 'rest', 'sleep', 'fluid', 'intake', 'water', 'follow', 'up', 'in', 'week', 'weeks', 'month', 'months', 'day', 'days', 'need', 'needed', 'prn', 'emergency', 'symptoms', 'worsen', 'increase', 'decrease', 'stop', 'continue', 'dosage', 'daily', 'twice', 'times', 'meals', 'before', 'after', 'with', 'food',
    'left', 'right', 'both', 'upper', 'lower', 'anterior', 'posterior', 'lateral', 'medial', 'proximal', 'distal', 'superior', 'inferior', 'bilateral', 'unilateral', 'generalized', 'localized', 'radiating', 'referred', 'dull', 'sharp', 'throbbing', 'burning', 'aching', 'cramp', 'cramping', 'spasm', 'spasms'
  ];

  // Common medical terms, abbreviations, and units
  static const List<String> _medicalTerms = [
    'paracetamol', 'aspirin', 'ibuprofen', 'amoxicillin', 'metformin', 'atorvastatin', 'omeprazole', 'losartan', 'albuterol', 'gabapentin', 'sertraline', 'amlodipine',
    'bp', 'bpm', 'mmhg', 'od', 'bd', 'tds', 'prn', 'hs', 'po', 'iv', 'im', 'sc', 'pr', 'pc', 'ac', 'qd', 'bid', 'tid', 'qid', 'mcg', 'mg', 'ml', 'g', 'kg',
    'temp', 'sat', 'sao2', 'spo2', 'hr', 'rr', 'c', 'f', 'nad', 'soap', 'sob', 'oe', 'ho', 'hx', 'tx', 'rx', 'dx', 'px', 'hx', 'complans', 'complaning'
  ];
}
