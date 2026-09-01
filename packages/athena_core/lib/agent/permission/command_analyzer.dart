/// Shell 命令动作分析与只读识别。
///
/// 纯函数、无 I/O,便于单元测试。
class CommandAnalyzer {
  /// 从 shell 命令提取"动作"(第一个可执行词)。
  ///
  /// - `'git status'` → `'git'`
  /// - `'ls -la'`    → `'ls'`
  /// - `'grep -n "a|b" f'` → `'grep'`(引号内分隔符不算复合)
  /// - 空命令、含管道/分隔符的复合命令 → `null`(无法可靠解析,降级)
  static String? extractAction(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return null;
    // 引号/括号感知:复合命令(引号外的 && || ; | 等)无法用单个动作表示
    final subs = splitSubcommands(trimmed);
    if (subs.length > 1) return null;
    final first = trimmed.split(RegExp(r'\s+')).first;
    return first.isEmpty ? null : first;
  }

  /// 把复合命令拆成子命令(引号/括号感知,纯字符串处理不执行 shell)。
  ///
  /// 分隔符:`&&` `||` `;` `|` `|&` `&` 与换行。引号内(`'` `"`,支持
  /// `\"` 转义)与 `$()` / `()` 括号深度内的分隔符不切:
  /// `grep -n "a | b"`、`echo $(git push || true)` 保持为一个子命令。
  /// 括号不平衡/无法可靠解析时退化为整条一个子命令(宁窄勿宽)。
  static List<String> splitSubcommands(String command) {
    final parts = <String>[];
    final buf = StringBuffer();
    var singleQuote = false;
    var doubleQuote = false;
    var parenDepth = 0;
    var i = 0;

    void flush() {
      final seg = buf.toString().trim();
      if (seg.isNotEmpty) parts.add(seg);
      buf.clear();
    }

    while (i < command.length) {
      final c = command[i];
      if (singleQuote) {
        buf.write(c);
        if (c == "'") singleQuote = false;
        i++;
        continue;
      }
      if (doubleQuote) {
        buf.write(c);
        if (c == r'\' && i + 1 < command.length) {
          buf.write(command[i + 1]);
          i += 2;
          continue;
        }
        if (c == '"') doubleQuote = false;
        i++;
        continue;
      }
      if (c == "'") {
        singleQuote = true;
        buf.write(c);
        i++;
        continue;
      }
      if (c == '"') {
        doubleQuote = true;
        buf.write(c);
        i++;
        continue;
      }
      // $() 与 () 内部的命令替换/子 shell:深度内的分隔符不切
      if (c == r'$' && i + 1 < command.length && command[i + 1] == '(') {
        parenDepth++;
        buf.write(c);
        buf.write('(');
        i += 2;
        continue;
      }
      if (c == '(') {
        parenDepth++;
        buf.write(c);
        i++;
        continue;
      }
      if (c == ')' && parenDepth > 0) {
        parenDepth--;
        buf.write(c);
        i++;
        continue;
      }
      if (parenDepth > 0) {
        buf.write(c);
        i++;
        continue;
      }
      final isAmpOrPipe = c == '&' || c == '|';
      if (isAmpOrPipe) {
        final two =
            command.substring(i, i + 2 > command.length ? command.length : i + 2);
        // && || |& 双字符分隔符
        if (two == '&&' || two == '||' || two == '|&') {
          flush();
          i += 2;
          continue;
        }
        if (c == '&' || c == '|') {
          flush();
          i++;
          continue;
        }
      }
      if (c == ';' || c == '\n') {
        flush();
        i++;
        continue;
      }
      buf.write(c);
      i++;
    }
    if (parenDepth > 0) {
      // 括号不平衡:无法可靠解析,整条作为单个子命令(保守)
      return [command.trim()]..removeWhere((s) => s.isEmpty);
    }
    flush();
    return parts;
  }

  /// 判断命令是否为只读(无副作用),命中则权限层默认放行。
  ///
  /// 保守策略:重定向、命令替换($()/反引号)一律不算只读;"纯只读链"
  /// (滤波器管道 `ls | head -100`、`a && b` 的每个子段都只读)按子段
  /// 逐段判定,全部只读才放行;单个简单命令动作在白名单内才算。
  static bool isReadOnlyCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return false;

    // 敏感路径:即便命中只读白名单,读取凭据类文件也需人工审批
    if (containsSensitivePath(trimmed)) return false;

    // 复合命令:引号/括号感知拆段后逐段判定(如 `ls -la | head -100`、
    // `cd /a && git status`)。任一段非只读(`a && rm b`、`ls | tee out`)
    // 则整体弹窗。sed/awk 的脚本参数($、{}、()、正则交替)是常规
    // 语法,由各自分支豁免处理,不在此处拦截。
    final subs = splitSubcommands(trimmed);
    if (subs.length > 1) {
      return subs.every(isReadOnlyCommand);
    }

    final action = extractAction(trimmed);
    if (action == null) return false;

    final rest =
        trimmed.substring(trimmed.indexOf(action) + action.length).trim();
    final args = rest.isEmpty ? <String>[] : rest.split(RegExp(r'\s+'));

    if (action == 'sed') return _isReadOnlySed(args);
    if (action == 'awk') return _isReadOnlyAwk(args);

    // 常规命令:重定向与命令替换/参数展开是危险形态,先拦
    if (trimmed.contains('>') ||
        trimmed.contains('<') ||
        trimmed.contains(r'$') ||
        trimmed.contains('`')) {
      return false;
    }

    switch (action) {
      case 'ls':
      case 'cat':
      case 'grep':
      case 'head':
      case 'tail':
      case 'sort':
      case 'wc':
      case 'uniq':
      case 'cut':
      case 'nl':
      case 'tr':
      case 'pwd':
      case 'echo':
      case 'which':
      case 'whoami':
      case 'cd':
        // cd 本身无副作用;复合命令(cd x && cmd)按子命令判定时,
        // cd 子命令不应造成弹窗(敏感路径已在上面的检查拦截)
        // sort/wc/uniq/cut/nl/tr 为纯滤波器,常出现在只读管道右段
        return true;
      case 'git':
        return _gitReadOnly(args);
      case 'dart':
      case 'flutter':
        // 分析/跑测试无文件副作用;run(执行代码)、format(改写文件)、
        // pub(更新锁文件)等仍走人工审批
        return args.isNotEmpty &&
            (args.first == 'test' || args.first == 'analyze');
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

  /// sed 的只读判定。脚本内 `$`、`()`、`{}`(行锚/反向引用/地址分组)
  /// 是常规语法,不走通用拦截;唯二危险形态是原地写文件
  /// (-i / --in-place)与输出重定向(> 写文件)。
  static bool _isReadOnlySed(List<String> args) {
    return !args.any(
      (a) => a.startsWith('-i') || a == '--in-place' || a.contains('>'),
    );
  }

  /// awk 的只读判定。`$1`/`$NF`、函数括号、花括号是常规语法,不走
  /// 通用拦截;危险源是脚本内执行外部命令(system())或重定向写文件
  /// (>)/管道到外部命令(|)。注意 awk 脚本内正则交替 `/a|b/` 会被
  /// 误判为管道而弹窗 —— 宁可多弹一次,不可静默放行 shell 管道。
  static bool _isReadOnlyAwk(List<String> args) {
    return !args.any(
      (a) => a.contains('system(') || a.contains('>') || a.contains('|'),
    );
  }

  /// git 的只读判定。支持 `git -C <dir>` / `--no-pager` 前缀(agent
  /// 在工作区外查看仓库的常用形态);只读子命令才放行。
  static bool _gitReadOnly(List<String> args) {
    var i = 0;
    while (i < args.length) {
      if (args[i] == '--no-pager') {
        i++;
        continue;
      }
      if (args[i] == '-C' && i + 1 < args.length) {
        i += 2;
        continue;
      }
      break;
    }
    if (i >= args.length) return false;
    final sub = args[i];
    final rest = args.sublist(i + 1);
    switch (sub) {
      case 'status':
      case 'log':
      case 'diff':
      case 'show':
        return true;
      case 'branch':
        // 裸 branch(列本地分支)或纯展示 flag;创建/重命名/删除
        // (-c/-C/-d/-D/-m/-M)拦截
        if (rest.isEmpty) return true;
        if (rest.every((a) => a.startsWith('-'))) return true;
        return rest.contains('--list') || rest.contains('-l');
      case 'tag':
        // 裸 tag(列标签)或纯展示 flag(-n/-l/--list/--sort);
        // `tag v1.0`(创建)、`tag -d`(删除)、`tag -a`(annotated)拦截
        if (rest.isEmpty) return true;
        if (rest.every((a) => a.startsWith('-'))) return true;
        return rest.contains('-l') || rest.contains('--list');
      case 'remote':
        // `git remote -v`、`git remote show <name>` 等展示形态;
        // add/set-url 等写配置拦截
        if (rest.isEmpty) return true;
        if (rest.first == 'show') return true;
        return rest.every((a) => a == '-v' || a == '-vv');
      case 'stash':
        // 裸 stash 进入交互界面;只放行 list / show
        return rest.isNotEmpty &&
            (rest.first == 'list' || rest.first == 'show');
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

  /// 命令是否包含递归删除模式,命中则 shell 工具拒绝执行。
  ///
  /// 这是 **shell 命令语义**而非某个工具的实现细节,因此与
  /// [isReadOnlyCommand] / [containsSensitivePath] 同处一层:
  /// bash 与 powershell 共用同一份模式表,避免两份列表各自漂移
  /// (历史上 powershell 侧漏了 `find . -delete` 与 cmd 的 `rd /s`)。
  ///
  /// 同时覆盖 POSIX 与 Windows 两套语法——用户可能在任一 shell 里
  /// 调用另一套工具链(WSL、Git Bash、pwsh on Linux)。
  static bool isRecursiveDelete(String command) =>
      _recursiveDeletePatterns.any((p) => p.hasMatch(command));

  /// 递归删除模式表(`static final`:只编译一次,不随每次调用重建)。
  static final _recursiveDeletePatterns = [
    // POSIX
    RegExp(r'\brm\s+.*(?:-[a-zA-Z]*[rR]|--recursive)'),
    RegExp(r'\brmdir\b'),
    RegExp(r'\bfind\b.*\brm\b'),
    // find . -delete / -ok —— 无 rm 字面量也能递归删除
    RegExp(r'\bfind\b.*(?:-delete|-ok\b)'),
    // cmd
    RegExp(r'\bdel\b\s+/[sS]'),
    // cmd 的 rd /s(rmdir 别名;要求 rd 与 /s 之间有空白,
    // 避免误伤 "ls rd/s" 这类路径写法)
    RegExp(r'\brd\b\s+/\s*[sS]'),
    // PowerShell:Remove-Item 及别名 ri / rd(命令不区分大小写);
    // 覆盖 -Recurse 与短参数 -R/-r
    RegExp(r'\bRemove-Item\b\s+.*-Recurse', caseSensitive: false),
    RegExp(r'\bRemove-Item\b\s+.*(?:-[a-zA-Z]*[rR]\b)', caseSensitive: false),
    RegExp(r'\bri\b\s+.*-Recurse', caseSensitive: false),
    RegExp(r'\bri\b\s+.*(?:-[a-zA-Z]*[rR]\b)', caseSensitive: false),
    RegExp(r'\brd\b\s+.*(?:-Recurse|-[a-zA-Z]*[rR]\b)', caseSensitive: false),
  ];
}
