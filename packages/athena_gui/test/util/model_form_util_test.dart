import 'package:athena_gui/util/format/model_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strips the Released prefix', () {
    expect(ModelForm.stripModelReleasedAt('Released 2026-09-10'), '2026-09-10');
    expect(ModelForm.stripModelReleasedAt('2026-09-10'), '2026-09-10');
    expect(ModelForm.stripModelReleasedAt(''), '');
  });

  test('strips price display text back to a bare number', () {
    expect(ModelForm.stripModelPrice(r'$0.15/M'), '0.15');
    expect(ModelForm.stripModelPrice(r'$0.15/M input tokens'), '0.15');
    expect(ModelForm.stripModelPrice('0.15'), '0.15');
    expect(ModelForm.stripModelPrice('free-ish'), 'free-ish');
  });

  test('formats a bare price for display', () {
    expect(ModelForm.formatModelPrice('0.15'), r'$0.15/M');
    expect(ModelForm.formatModelPrice('0.6000'), r'$0.6/M');
    expect(ModelForm.formatModelPrice('1'), r'$1/M');
    expect(ModelForm.formatModelPrice(''), '');
    expect(ModelForm.formatModelPrice('free-ish'), 'free-ish');
  });
}
