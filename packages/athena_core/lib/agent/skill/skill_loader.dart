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

  /// 代码注册的内置 Skill（非文件系统来源），不可编辑/删除。
  bool get isBuiltin => sourcePath == '(builtin)';
}

class SkillLoader {
  static bool isValidSkillName(String name) {
    if (name.isEmpty || name.length > 64) return false;
    for (final code in name.codeUnits) {
      if (code < 0x20 || code == 0x7f) return false; // 控制字符
      if (code == 0x2f || code == 0x5c) return false; // / \
      if (code == 0x3a || // :
          code == 0x2a || // *
          code == 0x3f || // ?
          code == 0x22 || // "
          code == 0x3c || // <
          code == 0x3e || // >
          code == 0x7c) {
        return false; // Windows 文件名非法字符
      }
    }
    if (name == '.' || name == '..') return false;
    return true;
  }

  /// 写入 SKILL.md（front matter + body），目录不存在时递归创建。
  ///
  /// 与 [parseSkillFile] 互为逆操作；标量统一用双引号包裹并转义，
  /// 避免 description 含冒号/井号/引号/换行时破坏 YAML。
  /// 调用方应先以 [isValidSkillName] 校验 name。
  void saveSkill({
    required String name,
    required String description,
    String? allowedTools,
    required String body,
    required String targetDir,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('name: ${_yamlScalar(name)}');
    buffer.writeln('description: ${_yamlScalar(description)}');
    if (allowedTools != null && allowedTools.isNotEmpty) {
      buffer.writeln('allowed-tools: ${_yamlScalar(allowedTools)}');
    }
    buffer.writeln('---');
    buffer.writeln();
    buffer.write(body.trim());
    if (!body.endsWith('\n')) {
      buffer.writeln();
    }

    final dir = Directory(targetDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    File('$targetDir/SKILL.md').writeAsStringSync(buffer.toString());
  }

  /// YAML 双引号标量：转义反斜杠/引号/换行/回车/制表符。
  static String _yamlScalar(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return '"$escaped"';
  }

  /// 解析 YAML；语法错误返回 null（与"跳过非法 Skill 目录"的容错一致）。
  static Object? _tryLoadYaml(String yaml) {
    try {
      return loadYaml(yaml);
    } catch (_) {
      return null;
    }
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

    final frontmatter = _tryLoadYaml(frontmatterYaml);
    if (frontmatter is! YamlMap) return null;

    final name = frontmatter['name'] as String?;
    final description = frontmatter['description'] as String?;
    if (name == null || description == null || name.isEmpty || description.isEmpty) {
      return null;
    }
    if (!isValidSkillName(name)) return null;

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
