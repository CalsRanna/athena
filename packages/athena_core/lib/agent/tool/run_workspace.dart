import 'dart:convert';

import 'package:athena_core/util/path_normalizer.dart';
import 'package:path/path.dart' as p;

import '../permission/permission_rule.dart';

/// 把「本次 run 的工作文件夹」落到工具调用参数上。
///
/// 工作文件夹是**每次 run 的上下文**：工具集是长生命周期单例，而工作文件夹
/// 随会话变化，所以不注入工具实例（多 run 并发会串台）。改在分发前把相对
/// 路径解析成绝对路径——`path_normalizer.normalizePathForMatch` 只在路径为
/// 相对时才读 `Directory.current`，一旦解析成绝对路径，文件执行与权限规则
/// 匹配（`PermissionRule._matchesPath` 同样走归一化）自动共用同一基准，
/// 不需要给 `PermissionService` 另开一条基准通道。
///
/// **必须三处共用**：执行（`AgentService.executeToolCallInternal`）、
/// 并行预检（`AgentService.selectParallelCalls`）、审批落库
/// （`AgentRunCoordinator._askPermission`）。审批路径拿到的是模型原始 JSON
/// （相对路径）；若那里不同步解析，会话级授权键与持久规则都会存成相对路径，
/// 之后拿绝对路径匹配永远不命中，表现为「同一 run 内已批准仍重复弹窗」与
/// 「始终允许」规则失效。
///
/// 文件工具的路径同时解析符号链接（[resolveRealPathSync]）：审批卡、AI
/// 审核、会话缓存、持久规则与执行都落在同一个真实目标上，项目里一个指向
/// `~/.zshrc` 的链接不能借项目路径的授权写出去。
///
/// [workspace] 为 null 或空串 = 不指定：shell 不注入 workdir（工具默认用户
/// 主目录），文件工具相对路径按进程当前目录解析——同样在这里落成绝对路径，
/// 否则「始终允许」会存成相对路径规则，换个目录启动就跨项目生效。
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
