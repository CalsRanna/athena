import 'dart:io';

import 'package:athena_core/util/logger_util.dart';
import 'package:yaml/yaml.dart';

class Skill {
  final String name;
  final String description;
  final String body;
  final String sourcePath;

  const Skill({
    required this.name,
    required this.description,
    required this.body,
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
    required String body,
    required String targetDir,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('name: ${_yamlScalar(name)}');
    buffer.writeln('description: ${_yamlScalar(description)}');
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

  /// 解析 YAML；语法错误返回 null，由调用方连同原因一起报出去。
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
        // 内容非法由 parseSkillFile 记原因后返回 null（见那里的注释）
        final skill = parseSkillFile(skillFile);
        if (skill != null) skills.add(skill);
      } catch (error) {
        // 读不出来（权限、非 UTF-8……）同样只跳过这一个，但要留痕：
        // 一声不响地少一个技能，用户无从查起。
        LoggerUtil.w('Skill unreadable (${skillFile.path}): $error');
      }
    }
    return skills;
  }

  /// 解析 SKILL.md；内容非法时记一条日志并返回 null。
  ///
  /// 非法的 Skill 只跳过、不中断整目录扫描，但**不能没有声音**：用户手写的
  /// SKILL.md 少一个 description 就整条消失，没有日志时只能靠猜。口径与坏
  /// 权限规则一致（PermissionService._ruleHits 也是跳过 + 记日志）。
  ///
  /// 文件本身读不出来时 I/O 异常照常冒泡，交给调用方按工具错误处理——那不是
  /// 「内容不合法」，不该被这里吞成 null。
  Skill? parseSkillFile(File file) {
    try {
      return _parseSkill(file);
    } on FormatException catch (error) {
      LoggerUtil.w('Skill skipped (${file.path}): ${error.message}');
      return null;
    }
  }

  /// 内容不合法时抛 [FormatException]，message 即原因。
  Skill _parseSkill(File file) {
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    if (lines.isEmpty || lines.first.trim() != '---') {
      throw const FormatException('missing the opening --- of front matter');
    }

    var endIndex = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        endIndex = i;
        break;
      }
    }
    if (endIndex == -1) {
      throw const FormatException('front matter is not closed with ---');
    }

    final frontmatterYaml = lines.sublist(1, endIndex).join('\n');
    final body = lines.sublist(endIndex + 1).join('\n').trim();

    final frontmatter = _tryLoadYaml(frontmatterYaml);
    if (frontmatter is! YamlMap) {
      throw const FormatException('front matter is not a YAML mapping');
    }

    // 逐个判类型而不是 `as String?`：name 写成数字会让 cast 抛 TypeError，
    // 那不在 FormatException 的捕获范围里，一条坏技能就能炸掉整个扫描。
    final name = frontmatter['name'];
    final description = frontmatter['description'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('name is missing, empty or not a string');
    }
    if (description is! String || description.isEmpty) {
      throw const FormatException(
        'description is missing, empty or not a string',
      );
    }
    if (!isValidSkillName(name)) {
      throw FormatException('name is not a valid skill name: $name');
    }

    return Skill(
      name: name,
      description: description,
      body: body,
      sourcePath: file.parent.path,
    );
  }
}
