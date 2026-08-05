/// Shell 命令动作分析与只读识别。
///
/// 纯函数、无 I/O,便于单元测试。
class CommandAnalyzer {
  /// 从 shell 命令提取"动作"(第一个可执行词)。
  ///
  /// - `'git status'` → `'git'`
  /// - `'ls -la'`    → `'ls'`
  /// - 空命令、含管道/分隔符的复合命令 → `null`(无法可靠解析,降级)
  static String? extractAction(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return null;
    // 复合命令(管道、&&、||、;、重定向)无法用单个动作表示
    if (trimmed.contains('|') ||
        trimmed.contains(';') ||
        trimmed.contains('&&') ||
        trimmed.contains('||')) {
      return null;
    }
    final first = trimmed.split(RegExp(r'\s+')).first;
    return first.isEmpty ? null : first;
  }

  /// 解析用户输入的规则模式,拆分为动作 + 参数模式。
  ///
  /// - `'git *'`  → `(action: 'git', pattern: '*')`
  /// - `'git'`    → `(action: 'git', pattern: '')`(允许所有 git 命令)
  /// - `'/a/b/'`  → `(action: null, pattern: '/a/b/')`(非 shell 或无法解析,按旧规则)
  static ({String? action, String pattern}) parseRulePattern(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return (action: null, pattern: '');
    final action = extractAction(trimmed);
    if (action == null) return (action: null, pattern: trimmed);
    // 路径(/ 开头)或 URL(含 ://)不被当作动作,整串作为 pattern 保存
    if (action.startsWith('/') || action.contains('://')) {
      return (action: null, pattern: trimmed);
    }
    final rest =
        trimmed.substring(trimmed.indexOf(action) + action.length).trim();
    return (action: action, pattern: rest);
  }

  /// 判断命令是否为只读(无副作用),命中则权限层默认放行。
  ///
  /// 保守策略:任何复合形式(管道/重定向/分隔符)一律不算只读,
  /// 只有单个简单命令且动作在白名单内才算。
  static bool isReadOnlyCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return false;
    // 重定向、管道、分隔符都可能引入副作用或后续危险命令；
    // 命令替换 $(...) / 反引号 / 参数与花括号展开会执行任意命令，
    // 一律不算只读（如 `echo $(git push --force)`、`` echo `rm -f /tmp/x` ``）。
    if (trimmed.contains('>') ||
        trimmed.contains('<') ||
        trimmed.contains('|') ||
        trimmed.contains(';') ||
        trimmed.contains('&&') ||
        trimmed.contains('||') ||
        trimmed.contains(r'$') ||
        trimmed.contains('`') ||
        trimmed.contains('{') ||
        trimmed.contains('(')) {
      return false;
    }

    // 敏感路径:即便命中只读白名单,读取凭据类文件也需人工审批
    if (containsSensitivePath(trimmed)) return false;

    final action = extractAction(trimmed);
    if (action == null) return false;

    final rest =
        trimmed.substring(trimmed.indexOf(action) + action.length).trim();
    final args = rest.isEmpty ? <String>[] : rest.split(RegExp(r'\s+'));

    switch (action) {
      case 'ls':
      case 'cat':
      case 'grep':
      case 'head':
      case 'tail':
      case 'pwd':
      case 'echo':
      case 'which':
      case 'whoami':
        return true;
      case 'git':
        // 裸 git 打开交互界面,不算只读;只读子命令才放行
        if (args.isEmpty) return false;
        final sub = args.first;
        return sub == 'status' || sub == 'log' || sub == 'diff';
      case 'npm':
        return args.isNotEmpty && args.first == 'list';
      case 'find':
        // 排除 -delete / -exec 等破坏性参数
        return !args.any(
          (a) => a == '-delete' || a == '-exec' || a == '-execdir',
        );
      default:
        return false;
    }
  }

  /// 判断命令文本是否涉及敏感路径(凭据/密钥类)。
  ///
  /// 命中时即使命令属于只读白名单也不放行,改走人工审批。
  /// 这是缓解而非完备拦截(bash 读取文件的方式无法穷举),
  /// 目的是把"免审批读取敏感文件"收窄为"需弹窗"。
  static bool containsSensitivePath(String command) {
    final lower = command.toLowerCase();
    return _sensitivePathMarkers.any(lower.contains);
  }

  /// 敏感路径标记(小写子串)。覆盖文件与目录名,含 Windows 形态。
  static const _sensitivePathMarkers = [
    '.ssh/',
    r'.ssh\',
    '.aws/',
    r'.aws\',
    '.athena/',
    r'.athena\',
    '.env',
    'credentials',
    'id_rsa',
    'id_ed25519',
  ];
}
