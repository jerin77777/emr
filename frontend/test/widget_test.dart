// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/models.dart';

void main() {
  test('VitalsFormatter formats values with units correctly', () {
    expect(VitalsFormatter.formatBp('120/80'), '120/80 mmHg');
    expect(VitalsFormatter.formatBp('120/80 mmHg'), '120/80 mmHg');
    expect(VitalsFormatter.formatPulse('72'), '72 bpm');
    expect(VitalsFormatter.formatPulse('72 bpm'), '72 bpm');
    expect(VitalsFormatter.formatTemp('98.6'), '98.6 °F');
    expect(VitalsFormatter.formatTemp('37'), '37 °C');
    expect(VitalsFormatter.formatSaturation('98'), '98%');
    expect(VitalsFormatter.formatWeight('70'), '70 kg');
    expect(VitalsFormatter.formatWeight('70 kg'), '70 kg');
  });

  test('VitalsFormatter generates placeholders when values are missing', () {
    final formatted = VitalsFormatter.formatAll(
      bp: null,
      pulse: '',
      temp: null,
      saturation: '',
      weight: '',
      includePlaceholders: true,
    );
    expect(formatted, 'BP: ___ mmHg | Pulse: ___ bpm | Temp: ___ °C/°F | SPO2: ___ % | Weight: ___ kg');
  });
}
