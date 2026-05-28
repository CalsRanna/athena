import 'package:athena/agent/skill/skill_registry.dart';
import 'tool_interface.dart';

class SkillTool implements Tool {
  final SkillRegistry _registry;

  SkillTool(this._registry);

  @override
  String get name => 'skill';

  @override
  String get description => 'Load a skill by name to get specialized '
      'instructions for a specific task. Use when a skill would enhance '
      'your ability to complete the current task. '
      'Available skills are listed in the system prompt.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'The name of the skill to load.',
      },
    },
    'required': ['name'],
  };

  @override
  DangerLevel get dangerLevel => DangerLevel.safe;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final skill = _registry.get(name);
    if (skill == null) {
      return 'Error: Skill "$name" not found.';
    }
    _registry.pushContext(name);
    final buffer = StringBuffer();
    buffer.writeln('Skill "$name" loaded successfully.');
    buffer.writeln();
    if (skill.allowedTools != null && skill.allowedTools!.isNotEmpty) {
      buffer.writeln(
        'Permission scope: tools listed in allowed-tools '
        '(${skill.allowedTools}) may auto-approve; others require user '
        'approval even if they are normally safe.',
      );
      buffer.writeln();
    }
    buffer.writeln('Instructions:');
    buffer.writeln(skill.body);
    return buffer.toString();
  }
}
