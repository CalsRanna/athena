import 'dart:convert';

import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_core/util/path_normalizer.dart';
import 'package:path/path.dart' as p;

/// 把「本次 run 的工作文件夹」落到工具调用参数上。
///
/// 工作文件夹是**每次 run 的上下文**：工具集是长生命周期单例，而工作文件夹
/// 随会话变化，所以不注入工具实例（多 run 并发会串台）。改在分发前把相对
/// 路径解析成绝对路径——`path_normalizer.normalizePathForMatch` 只在路径为
/// 相对时才读 `Directory.current`，一旦解析成绝对路径，文件执行与权限规则
/// 匹配（`PermissionRule._matchesPath` 同样走归一化）自动共用同一基准，
/// 不需要给 `PermissionService` 另开一条基准通道。
///
/// **必须共用**：执行（`AgentService.executeToolCallInternal`）与
/// 并行预检（`AgentService.selectParallelCalls`）使用同一解析口径；审批卡
/// 与 AI 审核也必须看到实际执行目标，避免词法路径与真实路径产生判定漂移。
///
/// 文件工具的路径同时解析符号链接（[resolveRealPathSync]）：审批卡、AI
/// 审核、会话缓存、持久规则与执行都落在同一个真实目标上，项目里一个指向
/// `~/.zshrc` 的链接不能借项目路径的授权写出去。
///
/// [workspace] 为 null 或空串 = 不指定：shell 不注入 workdir（工具默认用户
/// 主目录），文件工具相对路径按进程当前目录解析——同样在这里落成绝对路径，
/// 避免审批目标随进程启动目录漂移。
Map<String, dynamic> applyRunWorkspace(
  String toolName,
  Map<String, dynamic> args,
  String? workspace,
) {
  final hasWorkspace = workspace != null && workspace.isNotEmpty;

  if (kFileToolNames.contains(toolName)) {
    final path = args['path'];
    if (path is! String || path.isEmpty) return args;
    final absolute = hasWorkspace && !p.isAbsolute(path)
        ? p.join(workspace, path)
        : path;
    return {...args, 'path': resolveRealPathSync(absolute)};
  }

  if (!hasWorkspace) return args;

  // shell 工具：调用参数里显式传入的 workdir 优先，缺省时才用工作文件夹
  // （工具自身再退化到注入的 defaultWorkdir / 用户主目录）
  if (kShellToolNames.contains(toolName)) {
    if (args['workdir'] == null) return {...args, 'workdir': workspace};
  }
  return args;
}

/// 审批卡展示用的参数 JSON：默认就是模型给的原始参数；文件工具的路径经
/// 符号链接指到别处时，把 path 换成真实目标——否则用户批准的是
/// `docs/setup.md`，实际写的是 `~/.zshrc`。纯粹的相对→绝对变化不改写，
/// 保持审批卡与工具卡的展示一致。
///
/// [rawArgs] 是 [applyRunWorkspace] 之前的参数，[resolvedArgs] 是之后的。
String approvalArgumentsFor(
  String toolName, {
  required String rawArguments,
  required Map<String, dynamic> rawArgs,
  required Map<String, dynamic> resolvedArgs,
  required String? workspace,
}) {
  if (!kFileToolNames.contains(toolName)) return rawArguments;
  final rawPath = rawArgs['path'];
  final realPath = resolvedArgs['path'];
  if (rawPath is! String || realPath is! String) return rawArguments;
  final lexical = normalizePathForMatch(
    workspace == null || workspace.isEmpty
        ? rawPath
        : p.join(workspace, rawPath),
  );
  if (lexical == realPath) return rawArguments;
  return jsonEncode({
    ...jsonDecode(rawArguments) as Map<String, dynamic>,
    'path': realPath,
  });
}
