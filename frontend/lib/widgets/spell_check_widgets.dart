import 'package:flutter/material.dart';
import '../services/spell_check_service.dart';

class SpellCheckTextEditingController extends TextEditingController {
  final Map<String, bool> _wordCache = {};

  void revalidate() {
    _wordCache.clear();
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final textVal = text;

    if (textVal.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    // Split by word characters (a-zA-Z) vs non-word characters
    final RegExp regExp = RegExp(r'([a-zA-Z]+)|([^a-zA-Z]+)');
    final matches = regExp.allMatches(textVal);

    for (final match in matches) {
      final matchStr = match.group(0)!;
      final isWord = RegExp(r'^[a-zA-Z]+$').hasMatch(matchStr);

      if (isWord) {
        final lower = matchStr.toLowerCase();
        bool? cached = _wordCache[lower];
        if (cached == null) {
          cached = SpellCheckService.instance.isValidWord(matchStr);
          _wordCache[lower] = cached;
        }

        if (!cached) {
          children.add(TextSpan(
            text: matchStr,
            style: style?.copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: Colors.red,
            ) ?? const TextStyle(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: Colors.red,
            ),
          ));
        } else {
          children.add(TextSpan(text: matchStr, style: style));
        }
      } else {
        children.add(TextSpan(text: matchStr, style: style));
      }
    }

    return TextSpan(style: style, children: children);
  }
}

// Guided spell check dialog
class SpellCheckDialog extends StatefulWidget {
  final SpellCheckTextEditingController controller;
  final String fieldName;

  const SpellCheckDialog({
    super.key,
    required this.controller,
    required this.fieldName,
  });

  @override
  State<SpellCheckDialog> createState() => _SpellCheckDialogState();
}

class _SpellCheckDialogState extends State<SpellCheckDialog> {
  final List<String> _misspelledWords = [];
  int _currentIndex = 0;
  List<String> _suggestions = [];
  String? _selectedSuggestion;
  final _replacementController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _findMisspelledWords();
    _loadCurrentMisspelledWord();
  }

  @override
  void dispose() {
    _replacementController.dispose();
    super.dispose();
  }

  void _findMisspelledWords() {
    final textVal = widget.controller.text;
    final RegExp regExp = RegExp(r'\b[a-zA-Z]+\b');
    final matches = regExp.allMatches(textVal);

    _misspelledWords.clear();
    for (final match in matches) {
      final word = match.group(0)!;
      if (!SpellCheckService.instance.isValidWord(word)) {
        if (!_misspelledWords.contains(word)) {
          _misspelledWords.add(word);
        }
      }
    }
  }

  void _loadCurrentMisspelledWord() {
    if (_currentIndex < _misspelledWords.length) {
      final word = _misspelledWords[_currentIndex];
      _suggestions = SpellCheckService.instance.getSuggestions(word);
      _replacementController.text = _suggestions.isNotEmpty ? _suggestions.first : word;
      _selectedSuggestion = _suggestions.isNotEmpty ? _suggestions.first : null;
    } else {
      _suggestions = [];
      _selectedSuggestion = null;
    }
  }

  void _replaceWord() {
    final wordToReplace = _misspelledWords[_currentIndex];
    final replacement = _replacementController.text.trim();
    if (replacement.isEmpty) return;

    final currentText = widget.controller.text;
    // Replace all instances of the misspelled word (respecting word boundaries)
    final replacedText = currentText.replaceAll(RegExp('\\b$wordToReplace\\b'), replacement);
    
    widget.controller.text = replacedText;
    widget.controller.revalidate();

    _nextWord();
  }

  void _ignoreWord() {
    final wordToIgnore = _misspelledWords[_currentIndex];
    SpellCheckService.instance.ignoreWord(wordToIgnore);
    widget.controller.revalidate();
    _nextWord();
  }

  Future<void> _addToDictionary() async {
    final wordToAdd = _misspelledWords[_currentIndex];
    await SpellCheckService.instance.addToDictionary(wordToAdd);
    widget.controller.revalidate();
    _nextWord();
  }

  void _nextWord() {
    setState(() {
      _currentIndex++;
      _loadCurrentMisspelledWord();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasErrors = _misspelledWords.isNotEmpty && _currentIndex < _misspelledWords.length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            hasErrors ? Icons.spellcheck : Icons.check_circle,
            color: hasErrors ? Colors.teal : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(
            hasErrors ? 'Spell Check: ${widget.fieldName}' : 'Spell Check Complete',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: hasErrors
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unrecognized Word (${_currentIndex + 1} of ${_misspelledWords.length}):',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _misspelledWords[_currentIndex],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Correction / Replacement:',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _replacementController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _selectedSuggestion = _suggestions.contains(val) ? val : null;
                      });
                    },
                  ),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Suggestions:',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestions.map((suggestion) {
                        final isSelected = _selectedSuggestion == suggestion;
                        return ChoiceChip(
                          label: Text(suggestion),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedSuggestion = suggestion;
                                _replacementController.text = suggestion;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              )
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('No misspelled clinical words found in this field!'),
              ),
      ),
      actions: [
        if (hasErrors) ...[
          OutlinedButton(
            onPressed: _ignoreWord,
            child: const Text('Ignore'),
          ),
          OutlinedButton(
            onPressed: _addToDictionary,
            child: const Text('Add to Dict'),
          ),
          ElevatedButton(
            onPressed: _replaceWord,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Replace'),
          ),
        ] else
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
      ],
    );
  }
}
