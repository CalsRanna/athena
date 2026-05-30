import 'package:athena/extension/json_map_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getString', () {
    test('String value returns as-is', () {
      expect({'k': 'hello'}.getString('k'), 'hello');
    });

    test('int value returns its string form', () {
      expect({'k': 42}.getString('k'), '42');
    });

    test('null returns defaultValue', () {
      expect({'k': null}.getString('k', defaultValue: 'fallback'), 'fallback');
    });

    test('missing key returns defaultValue', () {
      expect(<String, dynamic>{}.getString('k', defaultValue: 'fallback'),
          'fallback');
    });
  });

  group('getInt', () {
    test('int returns as-is', () {
      expect({'k': 7}.getInt('k'), 7);
    });

    test('String "42" returns 42', () {
      expect({'k': '42'}.getInt('k'), 42);
    });

    test('double 3.0 returns 3', () {
      expect({'k': 3.0}.getInt('k'), 3);
    });

    test('non-numeric String "abc" returns defaultValue', () {
      expect({'k': 'abc'}.getInt('k', defaultValue: -1), -1);
    });

    test('null returns defaultValue', () {
      expect({'k': null}.getInt('k', defaultValue: 99), 99);
    });
  });

  group('getIntOrNull', () {
    test('int returns it', () {
      expect({'k': 5}.getIntOrNull('k'), 5);
    });

    test('String "42" returns 42', () {
      expect({'k': '42'}.getIntOrNull('k'), 42);
    });

    test('non-numeric String returns null', () {
      expect({'k': 'abc'}.getIntOrNull('k'), isNull);
    });

    test('null returns null', () {
      expect({'k': null}.getIntOrNull('k'), isNull);
    });
  });
}
