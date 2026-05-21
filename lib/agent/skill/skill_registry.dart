import 'dart:io';

import 'package:athena/agent/skill/skill_loader.dart';

class SkillRegistry {
  final SkillLoader _loader = SkillLoader();
  final Map<String, Skill> _skills = {};

  void loadAll() {
    _skills.clear();

    final projectPath = '${Directory.current.path}/.athena/skills';
    for (final skill in _loader.loadFromDirectory(projectPath)) {
      _skills[skill.name] = skill;
    }

    final home = _homePath;
    final userPath = '$home/.athena/skills';
    for (final skill in _loader.loadFromDirectory(userPath)) {
      _skills[skill.name] = skill;
    }
  }

  String get level1Prompt {
    if (_skills.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('## Available Skills');
    buffer.writeln('You have access to the following skills. '
        'Use the "skill" tool to load one when it would help with the task.');
    buffer.writeln();
    for (final skill in _skills.values) {
      buffer.writeln('- **${skill.name}**: ${skill.description}');
    }
    return buffer.toString();
  }

  String? getLevel2Content(String name) {
    return _skills[name]?.body;
  }

  Skill? get(String name) => _skills[name];

  List<Skill> get all => _skills.values.toList();

  static String get _homePath {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
  }
}
