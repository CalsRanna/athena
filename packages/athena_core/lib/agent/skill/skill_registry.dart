import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_trust_store.dart';
import 'package:athena_core/util/logger_util.dart';

class SkillRegistry {
  SkillRegistry({SkillTrustStore? trustStore})
      : _trustStore = trustStore ?? SkillTrustStore();

  /// Level 1 技能列表最大条数。超过此数量后，仅显示最近使用的技能。
  static const int maxLevel1Skills = 20;

  final SkillLoader _loader = SkillLoader();
  final SkillTrustStore _trustStore;
  final Map<String, Skill> _skills = {};

  /// loadAll 传入的用户级 Skill 目录（供 reloadSkill 复用，避免与
  /// 环境变量 HOME 不一致——测试与自定义 home 场景下两者可能不同）。
  String? _homeDir;

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
    _homeDir = home;
    final project = projectDir ?? Directory.current.path;

    _skills.clear();
    _pendingProjectSkills.clear();
    _pendingProjectDir = null;
    _skillAccessTimestamps.removeWhere((k, _) => !_builtinSkills.containsKey(k));

    final userSkillsPath = '$home/.athena/skills';
    final userSkills = _loader.loadFromDirectory(userSkillsPath);
    for (final skill in userSkills) {
      _skills[skill.name] = skill;
    }

    final projectSkillsPath = '$project/.athena/skills';
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

  void registerBuiltin(Skill skill) {
    _builtinSkills[skill.name] = skill;
    _skillAccessTimestamps[skill.name] = DateTime.now().millisecondsSinceEpoch;
  }

  bool get hasPendingProjectSkills => _pendingProjectSkills.isNotEmpty;

  List<Skill> get pendingProjectSkills => _pendingProjectSkills.values.toList();

  String? get pendingProjectDir => _pendingProjectDir;

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

  /// 路径归一化：统一分隔符为 '/' 并去除末尾斜杠，使比较与搜索
  /// 不依赖平台（Windows 原生路径为反斜杠）。
  static String _normalizePath(String p) {
    var path = p.replaceAll('\\', '/');
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  String get level1Prompt {
    final allSkills = <String, Skill>{};
    allSkills.addAll(_skills);
    allSkills.addAll(_builtinSkills);

    if (allSkills.isEmpty) return '';

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

  void reloadSkill(String skillName, String directoryPath) {
    final skillFile = File('$directoryPath/SKILL.md');
    if (!skillFile.existsSync()) {
      _skills.remove(skillName);
      _pendingProjectSkills.remove(skillName);
      return;
    }
    final skill = _loader.parseSkillFile(skillFile);
    if (skill == null) return;

    final home = _homeDir ?? _homePath;
    final normalizedDir = _normalizePath(directoryPath);
    final normalizedHome = _normalizePath('$home/.athena/skills');

    if (normalizedDir.startsWith(normalizedHome)) {
      _skills[skillName] = skill;
    } else {
      final projectRoot = _findProjectRoot(normalizedDir);
      if (projectRoot != null && _trustStore.isTrusted(projectRoot)) {
        _mergeProjectSkill(skill);
      } else {
        _pendingProjectSkills[skillName] = skill;
        _pendingProjectDir ??= projectRoot ?? Directory.current.path;
      }
    }
  }

  /// 从 Skill 目录反查项目根目录。
  ///
  /// 输入可能含 Windows 反斜杠或混合分隔符；统一为 '/' 后再搜索，
  /// 返回时还原为本机分隔符，以匹配 SkillTrustStore 中存储的目录格式。
  String? _findProjectRoot(String skillDir) {
    final normalized = _normalizePath(skillDir);
    final idx = normalized.indexOf('/.athena/');
    if (idx <= 0) return null;
    final root = normalized.substring(0, idx);
    return Platform.isWindows ? root.replaceAll('/', '\\') : root;
  }

  Skill? get currentContext {
    if (_contextStack.isEmpty) return null;
    return _skills[_contextStack.last];
  }

  static String get _homePath {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
  }
}
