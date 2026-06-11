import 'dart:io';

import 'package:athena/agent/skill/skill_loader.dart';
import 'package:athena/agent/skill/skill_trust_store.dart';
import 'package:athena/agent/tool/tool_interface.dart';
import 'package:athena/util/logger_util.dart';

class SkillRegistry {
  SkillRegistry({SkillTrustStore? trustStore})
      : _trustStore = trustStore ?? SkillTrustStore();

  /// Level 1 技能列表最大条数。超过此数量后，仅显示最近使用的技能。
  static const int maxLevel1Skills = 20;

  /// 这些工具会修改文件系统、执行代码或外泄数据，因此 Skill 的 allowedTools
  /// 永远不能把它们降级为 safe（用户必须始终获得审批提示）。
  static const Set<String> dangerousTools = {
    'bash',
    'powershell',
    'file_write',
    'file_update',
    'file_delete',
    'web_fetch',
  };

  final SkillLoader _loader = SkillLoader();
  final SkillTrustStore _trustStore;
  final Map<String, Skill> _skills = {};

  /// 内置 Skill：不来自文件系统，由代码注册，始终可用。
  final Map<String, Skill> _builtinSkills = {};

  /// Skill 最近访问时间戳（毫秒），用于 level1 排序。
  final Map<String, int> _skillAccessTimestamps = {};

  /// 未被信任的项目级 Skill：已解析但保持 INERT（不可加载、不出现在任何
  /// 列表中、不覆盖用户级 Skill），直到用户信任当前项目目录。
  final Map<String, Skill> _pendingProjectSkills = {};
  String? _pendingProjectDir;

  /// 当前 Agent 工具调用栈对应的 Skill 上下文。
  /// SkillTool 进入时 push，本轮工具调用结束后由 AgentService pop。
  final List<String> _contextStack = [];

  void loadAll({String? homeDir, String? projectDir}) {
    final home = homeDir ?? _homePath;
    final project = projectDir ?? Directory.current.path;

    _skills.clear();
    _pendingProjectSkills.clear();
    _pendingProjectDir = null;
    // 清除文件系统 skill 的时间戳，但保留内置 skill 的时间戳
    _skillAccessTimestamps.removeWhere((k, _) => !_builtinSkills.containsKey(k));

    final userSkillsPath = '$home/.athena/skills';
    final userSkills = _loader.loadFromDirectory(userSkillsPath);
    for (final skill in userSkills) {
      _skills[skill.name] = skill;
    }

    final projectSkillsPath = '$project/.athena/skills';
    // cwd 即 home：项目级路径与用户级路径相同，已作为用户级加载，跳过项目阶段。
    if (_normalizePath(projectSkillsPath) == _normalizePath(userSkillsPath)) {
      return;
    }

    final projectSkills = _loader.loadFromDirectory(projectSkillsPath);
    if (projectSkills.isEmpty) return;

    if (_trustStore.isTrusted(project)) {
      for (final skill in projectSkills) {
        _mergeProjectSkill(skill);
      }
    } else {
      // 未信任：保持 INERT，不并入 _skills。
      for (final skill in projectSkills) {
        _pendingProjectSkills[skill.name] = skill;
      }
      _pendingProjectDir = project;
    }
  }

  void _mergeProjectSkill(Skill skill) {
    if (_skills.containsKey(skill.name)) {
      LoggerUtil.i(
        'Skill "${skill.name}" project-level override at ${skill.sourcePath}',
      );
    }
    _skills[skill.name] = skill;
  }

  /// 注册内置 Skill（不依赖文件系统，代码中定义）。
  ///
  /// 内置 Skill 始终参与 level1 提示词且不会被文件系统中的同名 Skill 覆盖。
  void registerBuiltin(Skill skill) {
    _builtinSkills[skill.name] = skill;
    _skillAccessTimestamps[skill.name] = DateTime.now().millisecondsSinceEpoch;
  }

  /// 是否存在等待用户信任的项目级 Skill。
  bool get hasPendingProjectSkills => _pendingProjectSkills.isNotEmpty;

  /// 当前待信任的项目级 Skill 列表。
  List<Skill> get pendingProjectSkills => _pendingProjectSkills.values.toList();

  /// 当前待信任的项目目录（无则为 null）。
  String? get pendingProjectDir => _pendingProjectDir;

  /// 信任当前待审项目目录：持久化信任，并将待审 Skill 激活（并入 _skills）。
  Future<void> trustCurrentProject() async {
    final dir = _pendingProjectDir;
    if (dir == null) return;
    await _trustStore.trust(dir);
    for (final skill in _pendingProjectSkills.values) {
      _mergeProjectSkill(skill);
    }
    _pendingProjectSkills.clear();
    _pendingProjectDir = null;
  }

  /// 规范化路径：去除末尾斜杠，使 `/a/b` 与 `/a/b/` 比较相等。
  static String _normalizePath(String p) {
    var path = p;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  String get level1Prompt {
    // 合并内置 Skill 和文件系统 Skill（内置优先，不会被覆盖）
    final allSkills = <String, Skill>{};
    allSkills.addAll(_skills);
    allSkills.addAll(_builtinSkills);

    if (allSkills.isEmpty) return '';

    // 按最近访问时间排序（未访问过的排在最后）
    final sorted = allSkills.values.toList()
      ..sort((a, b) {
        final tA = _skillAccessTimestamps[a.name] ?? 0;
        final tB = _skillAccessTimestamps[b.name] ?? 0;
        return tB.compareTo(tA);
      });

    final display = sorted.take(maxLevel1Skills).toList();
    final remaining = sorted.length - display.length;

    final buffer = StringBuffer();
    buffer.writeln('## Available Skills');
    buffer.writeln('You have access to the following skills. '
        'Use the "skill" tool to load one when it would help with the task.');
    if (remaining > 0) {
      buffer.writeln('(${display.length} shown, $remaining more available. '
          'Use the "skill" tool to load any by name.)');
    }
    buffer.writeln();
    for (final skill in display) {
      buffer.writeln('- **${skill.name}**: ${skill.description}');
    }
    return buffer.toString();
  }

  String? getLevel2Content(String name) {
    // 访问时记录时间戳，用于 level1 排序
    _skillAccessTimestamps[name] = DateTime.now().millisecondsSinceEpoch;
    return _skills[name]?.body ?? _builtinSkills[name]?.body;
  }

  Skill? get(String name) {
    _skillAccessTimestamps[name] = DateTime.now().millisecondsSinceEpoch;
    return _skills[name] ?? _builtinSkills[name];
  }

  List<Skill> get all {
    final result = <Skill>[];
    result.addAll(_skills.values);
    result.addAll(_builtinSkills.values);
    return result;
  }

  void pushContext(String skillName) {
    _contextStack.add(skillName);
  }

  void popContext() {
    if (_contextStack.isNotEmpty) _contextStack.removeLast();
  }

  void clearContext() {
    _contextStack.clear();
  }

  /// 重新加载单个 Skill（创建或更新后调用）。
  ///
  /// 解析指定目录下的 SKILL.md 并更新到 _skills 映射中。
  /// 项目级 Skill 需要该项目目录已被信任。
  void reloadSkill(String skillName, String directoryPath) {
    final skillFile = File('$directoryPath/SKILL.md');
    if (!skillFile.existsSync()) {
      // SKILL.md 不存在：从映射中移除
      _skills.remove(skillName);
      _pendingProjectSkills.remove(skillName);
      return;
    }
    final skill = _loader.parseSkillFile(skillFile);
    if (skill == null) return;

    // 判断是项目级还是用户级
    final home = _homePath;
    final normalizedDir = _normalizePath(directoryPath);
    final normalizedHome = _normalizePath('$home/.athena/skills');

    if (normalizedDir.startsWith(normalizedHome)) {
      // 用户级，直接合并
      _skills[skillName] = skill;
    } else {
      // 项目级：只有信任了才合并
      final projectRoot = _findProjectRoot(normalizedDir);
      if (projectRoot != null && _trustStore.isTrusted(projectRoot)) {
        _mergeProjectSkill(skill);
      } else {
        // 未信任：放入 pending
        _pendingProjectSkills[skillName] = skill;
        _pendingProjectDir ??= projectRoot ?? Directory.current.path;
      }
    }
  }

  /// 推断项目根目录（从 skill 路径中提取 .athena 的父目录）。
  String? _findProjectRoot(String skillDir) {
    final idx = skillDir.indexOf('/.athena/');
    if (idx > 0) return skillDir.substring(0, idx);
    return null;
  }

  /// 当前 Agent 处于的最近一个 Skill 上下文。
  Skill? get currentContext {
    if (_contextStack.isEmpty) return null;
    return _skills[_contextStack.last];
  }

  /// 在当前 Skill 上下文下重新解释工具的危险等级：
  /// - 不在任何 Skill 上下文中：返回工具默认等级；
  /// - SkillTool 自身不受约束：返回默认等级；
  /// - forbidden 永远不变；
  /// - 当前 Skill 声明了 allowedTools 且工具在列表中：降级为 safe；
  ///   但危险工具（dangerousTools）永不降级，保持其默认等级；
  /// - 当前 Skill 声明了 allowedTools 但工具不在列表中：强制 needsApproval（即便默认 safe）；
  /// - 当前 Skill 未声明 allowedTools：保持默认等级，行为不变。
  DangerLevel effectiveDangerLevel(String toolName, DangerLevel defaultLevel) {
    if (defaultLevel == DangerLevel.forbidden) return defaultLevel;
    if (toolName == 'skill') return defaultLevel;
    final skill = currentContext;
    if (skill == null) return defaultLevel;

    final allowed = _parseAllowedTools(skill.allowedTools);
    if (allowed == null) return defaultLevel;

    if (allowed.contains(toolName)) {
      // 危险工具硬下限：Skill 不能将其降级为 safe，保留原始等级。
      if (dangerousTools.contains(toolName)) return defaultLevel;
      return DangerLevel.safe;
    }
    return DangerLevel.needsApproval;
  }

  static Set<String>? _parseAllowedTools(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return trimmed
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  static String get _homePath {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
  }
}
