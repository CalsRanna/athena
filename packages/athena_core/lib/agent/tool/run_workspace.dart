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
/// [workspace] 为 null 或空串 = 不指定：原样返回，维持引入本能力之前的行为
/// （shell 默认用户主目录、文件工具相对路径按进程当前目录解析）。
Map<String, dynamic> applyRunWorkspace(
  String toolName,
  Map<String, dynamic> args,
  String? workspace,
) {
  if (workspace == null || workspace.isEmpty) return args;

  // 文件工具：相对路径以工作文件夹为基准解析为绝对路径（词法归一化，
  // 不访问文件系统，与 normalizePathForMatch 的口径一致）
  if (kFileToolNames.contains(toolName)) {
    final path = args['path'];
    if (path is String && path.isNotEmpty && !p.isAbsolute(path)) {
      return {...args, 'path': p.normalize(p.join(workspace, path))};
    }
    return args;
  }

  // shell 工具：调用参数里显式传入的 workdir 优先，缺省时才用工作文件夹
  // （工具自身再退化到注入的 defaultWorkdir / 用户主目录）
  if (kShellToolNames.contains(toolName)) {
    if (args['workdir'] == null) return {...args, 'workdir': workspace};
  }
  return args;
}
