import 'dart:io';

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

    final frontmatter = lines.sublist(1, endIndex).join('\n');
    final body = lines.sublist(endIndex + 1).join('\n').trim();

    final name = _extractField(frontmatter, 'name');
    final description = _extractField(frontmatter, 'description');
    if (name.isEmpty || description.isEmpty) return null;

    return Skill(
      name: name,
      description: description,
      body: body,
      allowedTools: _extractFieldOrNull(frontmatter, 'allowed-tools'),
      disableModelInvocation:
          _extractField(frontmatter, 'disable-model-invocation') == 'true',
      sourcePath: file.parent.path,
    );
  }

  String _extractField(String yaml, String key) {
    final regex = RegExp('^$key:\\s*(.+)\$', multiLine: true);
    final match = regex.firstMatch(yaml);
    return match?.group(1)?.trim() ?? '';
  }

  String? _extractFieldOrNull(String yaml, String key) {
    final value = _extractField(yaml, key);
    return value.isEmpty ? null : value;
  }
}
