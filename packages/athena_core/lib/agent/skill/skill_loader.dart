import 'dart:io';

import 'package:yaml/yaml.dart';

class Skill {
  final String name;
  final String description;
  final String body;
  final String? allowedTools;
  final bool disableModelInvocation;
  final String sourcePath;

  const Skill({
    required this.name,
    required this.description,
    required this.body,
    this.allowedTools,
    this.disableModelInvocation = false,
    required this.sourcePath,
  });
}

class SkillLoader {
  static bool _isValidSkillName(String name) {
    if (name.length > 64) return false;
    for (final code in name.codeUnits) {
      if (code < 0x20 || code == 0x7f) return false; // 控制字符
      if (code == 0x2f || code == 0x5c) return false; // / \
    }
    if (name == '.' || name == '..') return false;
    return true;
  }

  List<Skill> loadFromDirectory(String directoryPath) {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return [];

    final skills = <Skill>[];
    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;
      final skillFile = File('${entity.path}/SKILL.md');
      if (!skillFile.existsSync()) continue;
      try {
        final skill = _parseSkill(skillFile);
        if (skill != null) skills.add(skill);
      } catch (_) {
        // Skip invalid skill directories
      }
    }
    return skills;
  }

  Skill? parseSkillFile(File file) {
    return _parseSkill(file);
  }

  Skill? _parseSkill(File file) {
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    if (lines.isEmpty || lines.first.trim() != '---') return null;

    var endIndex = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        endIndex = i;
        break;
      }
    }
    if (endIndex == -1) return null;

    final frontmatterYaml = lines.sublist(1, endIndex).join('\n');
    final body = lines.sublist(endIndex + 1).join('\n').trim();

    final frontmatter = loadYaml(frontmatterYaml);
    if (frontmatter is! YamlMap) return null;

    final name = frontmatter['name'] as String?;
    final description = frontmatter['description'] as String?;
    if (name == null || description == null || name.isEmpty || description.isEmpty) {
      return null;
    }
    if (!_isValidSkillName(name)) return null;

    return Skill(
      name: name,
      description: description,
      body: body,
      allowedTools: frontmatter['allowed-tools'] as String?,
      disableModelInvocation:
          frontmatter['disable-model-invocation'] == true ||
              frontmatter['disable-model-invocation'] == 'true',
      sourcePath: file.parent.path,
    );
  }
}
