import 'package:athena_gui/util/model_form_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strips the Released prefix', () {
    expect(stripModelReleasedAt('Released 2026-09-10'), '2026-09-10');
    expect(stripModelReleasedAt('2026-09-10'), '2026-09-10');
    expect(stripModelReleasedAt(''), '');
  });

  test('strips price display text back to a bare number', () {
    expect(stripModelPrice(r'$0.15/M'), '0.15');
    expect(stripModelPrice(r'$0.15/M input tokens'), '0.15');
    expect(stripModelPrice('0.15'), '0.15');
    expect(stripModelPrice('free-ish'), 'free-ish');
  });

  test('formats a bare price for display', () {
    expect(formatModelPrice('0.15'), r'$0.15/M');
    expect(formatModelPrice('0.6000'), r'$0.6/M');
    expect(formatModelPrice('1'), r'$1/M');
    expect(formatModelPrice(''), '');
    expect(formatModelPrice('free-ish'), 'free-ish');
  });
}
