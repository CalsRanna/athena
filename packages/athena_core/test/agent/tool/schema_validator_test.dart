import 'package:athena_core/agent/tool/ask_user_question_tool.dart';
import 'package:athena_core/agent/tool/schema_validator.dart';
import 'package:athena_core/agent/tool/skill_evolve_tool.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:test/test.dart';

void main() {
  test('missing, null and wrong-typed required values are rejected', () {
    final schema = {
      'type': 'object',
      'required': ['path'],
      'properties': {
        'path': {'type': 'string'},
      },
    };
    for (final args in <Map<String, dynamic>>[
      {},
      {'path': null},
      {'path': 4},
    ]) {
      expect(SchemaValidator.validate(schema, args), isNotNull);
    }
    expect(SchemaValidator.validate(schema, {'path': 'a.dart'}), isNull);
  });

  test('unknown skill actions fail before execution', () {
    final tool = SkillEvolveTool(skillRegistry: SkillRegistry());
    expect(
      SchemaValidator.validate(tool.parameters, {
        'name': 'demo',
        'action': 'delete',
        'body': 'demo',
      }),
      contains('action'),
    );
  });

  test('nested questions, option types and header lengths are checked', () {
    final schema = AskUserQuestionTool().parameters;
    final question = {
      'question': 'Choose',
      'header': 'Question',
      'options': [
        {'label': 'A', 'description': 'First'},
        {'label': 'B', 'description': 'Second'},
      ],
    };
    expect(
      SchemaValidator.validate(schema, {
        'questions': [question],
      }),
      isNull,
    );
    expect(
      SchemaValidator.validate(schema, {'questions': <Object?>[]}),
      isNotNull,
    );
    expect(
      SchemaValidator.validate(schema, {
        'questions': [
          {...question, 'header': 'x' * 13},
        ],
      }),
      isNotNull,
    );
    expect(
      SchemaValidator.validate(schema, {
        'questions': [
          {
            ...question,
            'options': [
              {'label': 1, 'description': 'First'},
              {'label': 'B', 'description': 'Second'},
            ],
          },
        ],
      }),
      contains('questions[0].options[0].label'),
    );
  });

  test('numeric ranges and optional null values are checked', () {
    final schema = {
      'properties': {
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 10},
      },
    };
    for (final limit in [0, 11, null]) {
      expect(SchemaValidator.validate(schema, {'limit': limit}), isNotNull);
    }
    expect(SchemaValidator.validate(schema, {}), isNull);
  });
}
