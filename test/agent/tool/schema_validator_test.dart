import 'package:athena/agent/tool/schema_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SchemaValidator', () {
    test('passes when args match schema', () {
      final schema = {
        'type': 'object',
        'required': ['name'],
        'properties': {
          'name': {'type': 'string'},
          'age': {'type': 'integer'},
        },
      };
      expect(
        SchemaValidator.validate(schema, {'name': 'Alice', 'age': 30}),
        isNull,
      );
    });

    test('passes with only required fields', () {
      final schema = {
        'type': 'object',
        'required': ['path'],
        'properties': {
          'path': {'type': 'string'},
          'offset': {'type': 'integer'},
        },
      };
      expect(
        SchemaValidator.validate(schema, {'path': '/tmp/test.txt'}),
        isNull,
      );
    });

    test('fails when required field is missing', () {
      final schema = {
        'type': 'object',
        'required': ['command'],
        'properties': {
          'command': {'type': 'string'},
        },
      };
      final error = SchemaValidator.validate(schema, {});
      expect(error, isNotNull);
      expect(error, contains('Missing required parameter'));
      expect(error, contains('"command"'));
    });

    test('fails on type mismatch', () {
      final schema = {
        'type': 'object',
        'required': ['path'],
        'properties': {
          'path': {'type': 'string'},
        },
      };
      final error = SchemaValidator.validate(schema, {'path': 123});
      expect(error, isNotNull);
      expect(error, contains('expected type "string"'));
    });

    test('fails when integer expected but number given', () {
      final schema = {
        'type': 'object',
        'required': ['limit'],
        'properties': {
          'limit': {'type': 'integer'},
        },
      };
      final error = SchemaValidator.validate(schema, {'limit': 3.14});
      expect(error, isNotNull);
      expect(error, contains('expected type "integer"'));
    });

    test('passes when boolean matches', () {
      final schema = {
        'type': 'object',
        'properties': {
          'enabled': {'type': 'boolean'},
        },
      };
      expect(
        SchemaValidator.validate(schema, {'enabled': true}),
        isNull,
      );
    });

    test('fails when boolean expected but string given', () {
      final schema = {
        'type': 'object',
        'properties': {
          'enabled': {'type': 'boolean'},
        },
      };
      final error = SchemaValidator.validate(schema, {'enabled': 'yes'});
      expect(error, isNotNull);
    });

    test('passes with no required fields', () {
      final schema = {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
        },
      };
      expect(
        SchemaValidator.validate(schema, {}),
        isNull,
      );
    });

    test('passes when properties section is missing', () {
      final schema = {'type': 'object'};
      expect(
        SchemaValidator.validate(schema, {'anything': 42}),
        isNull,
      );
    });
  });
}
