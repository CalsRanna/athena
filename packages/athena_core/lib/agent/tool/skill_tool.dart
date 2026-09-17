import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/util/text_file_reader.dart';
import 'package:path/path.dart' as p;

import 'tool_interface.dart';

class SkillTool implements Tool {
  @override
  ExecutionMode get executionMode => ExecutionMode.sequential;
  @override
  bool canExecuteParallel(Map<String, dynamic> args) => false;
  final SkillRegistry _registry;

  SkillTool(this._registry);

  @override
  ToolRisk get risk => ToolRisk.dangerous;

  @override
  String get name => 'skill';

  @override
  String get description =>
      'Load a skill by name to get specialized '
      'instructions for a specific task. Use when a skill would enhance '
      'your ability to complete the current task. '
      'Available skills are listed in the system prompt. '
      'Pass resource to read a UTF-8 text file inside that skill directory '
      '(references, templates, or script source), with optional offset/limit '
      'pagination. Resource reads do not execute scripts.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'The name of the skill to load.',
      },
      'resource': {
        'type': 'string',
        'description':
            'Optional path relative to the skill directory, such as '
            'references/guide.md. Only files within this skill are accessible. '
            'Omit to load the skill instructions and directory information.',
      },
      'offset': {
        'type': 'integer',
        'minimum': 0,
        'default': 0,
        'description': 'Starting line (0-indexed) when reading a resource.',
      },
      'limit': {
        'type': 'integer',
        'minimum': 1,
        'maximum': TextFileReader.maxReturnLines,
        'default': 200,
        'description':
            'Maximum resource lines to return (default 200, max 2000).',
      },
    },
    'required': ['name'],
  };

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    void Function(String)? onUpdate,
  }) async {
    final name = args['name'] as String;
    final skill = _registry.get(name);
    if (skill == null) {
      return 'Error: Skill "$name" not found.';
    }
    final resource = args['resource'] as String?;
    if (resource != null) {
      return _readResource(
        skill,
        resource,
        offset: args['offset'] as int? ?? 0,
        limit: args['limit'] as int? ?? 200,
      );
    }
    if (args['offset'] != null || args['limit'] != null) {
      return 'Error: offset and limit require a resource path.';
    }
    _registry.pushContext(name);
    final buffer = StringBuffer();
    buffer.writeln('Skill "$name" loaded successfully.');
    if (skill.isBuiltin) {
      buffer.writeln('This built-in skill has no resource directory.');
    } else {
      buffer.writeln('Directory: ${p.normalize(p.absolute(skill.sourcePath))}');
      buffer.writeln(
        'Resolve relative resource paths in these instructions '
        'from this skill directory. Read supporting text files on demand '
        'with the skill tool using this name and a resource path; '
        'offset/limit select a page of lines.',
      );
      buffer.writeln(
        'To execute bundled scripts, use an available shell tool '
        'with the absolute script path and specify workdir when needed.',
      );
    }
    buffer.writeln();
    buffer.writeln('Instructions:');
    buffer.writeln(skill.body);
    return buffer.toString();
  }

  Future<String> _readResource(
    Skill skill,
    String resource, {
    required int offset,
    required int limit,
  }) async {
    if (skill.isBuiltin) {
      return 'Error: Built-in skill "${skill.name}" has no resource directory.';
    }
    if (resource.isEmpty ||
        resource.contains('\u0000') ||
        p.posix.isAbsolute(resource) ||
        p.windows.rootPrefix(resource).isNotEmpty ||
        RegExp(r'^[A-Za-z]:').hasMatch(resource)) {
      return 'Error: resource must be a non-empty relative file path.';
    }
    if (offset < 0 || limit < 1 || limit > TextFileReader.maxReturnLines) {
      return 'Error: offset must be non-negative and limit must be 1-2000.';
    }

    try {
      final root = await Directory(skill.sourcePath).resolveSymbolicLinks();
      // Accept either separator style for resources on all supported platforms.
      final path = p.normalize(p.joinAll([root, ...p.windows.split(resource)]));
      if (!p.isWithin(root, path)) {
        return 'Error: Resource must stay inside the skill directory.';
      }
      final resolved = await File(path).resolveSymbolicLinks();
      if (!p.isWithin(root, resolved)) {
        return 'Error: Resource resolves outside the skill directory.';
      }
      if (await FileSystemEntity.type(resolved) != FileSystemEntityType.file) {
        return 'Error: Resource must be a text file.';
      }
      final content = await TextFileReader().read(
        File(resolved),
        offset: offset,
        limit: limit,
      );
      return 'Skill: ${skill.name}\nResource: $resource\nPath: $resolved\n\n$content';
    } on FileSystemException catch (error) {
      return 'Error: Cannot read resource "$resource" for skill "${skill.name}": '
          '${error.message}';
    } on FormatException {
      return 'Error: Skill resources must be UTF-8 text files.';
    }
  }
}
