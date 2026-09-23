import 'dart:io';

import 'package:athena_core/util/logger_util.dart';
import 'package:path/path.dart' as p;

/// 工作文件夹根目录的项目约定文件（`AGENTS.md`）。
///
/// 内容由仓库维护、由用户负责，本类只做「读进来」这一件事：不做长度裁剪，
/// 也不做内容加工。运行时把它原样放进一条独立的 system 消息（见
/// `layoutPromptMessages`），并且与技能目录 / 记忆目录同一约定——只拼入本次
/// 请求、不落库，因此不会进入权限复核的授权依据（`PermissionReviewContext`
/// 只收集 user / assistant 角色的持久化消息）。
///
/// 只覆盖根目录这一份；目标文件所在目录层级的嵌套约定不在本类范围内。
class ProjectInstructions {
  const ProjectInstructions({
    required this.path,
    required this.content,
    required this.size,
    required this.modifiedMillis,
  });

  /// 约定文件名，固定在工作文件夹根目录。
  static const String fileName = 'AGENTS.md';

  /// 约定文件的绝对路径（工作文件夹已是绝对路径，见
  /// `AgentRunCoordinator._resolveWorkspace`）。
  final String path;

  /// 文件正文，原样使用。
  final String content;

  /// 读取时的字节数，用于判断文件是否变化。
  final int size;

  /// 读取时的修改时间（毫秒），用于判断文件是否变化。
  final int modifiedMillis;

  /// 注入文本：一行来源说明 + 正文。
  String get prompt =>
      'Project conventions from $path (maintained in the workspace '
      'repository):\n\n$content';

  /// 读取 [workspace] 根目录的约定文件。
  ///
  /// 未指定工作文件夹、文件不存在、不可读或内容为空时返回 null（调用方据此
  /// 不注入，而不是注入一个空段）。工作文件夹是用户随时可能删除的外部状态，
  /// 因此读取失败只记日志，不抛出。
  static ProjectInstructions? load(String? workspace) {
    if (workspace == null || workspace.isEmpty) return null;
    final snapshot = _read(p.join(workspace, fileName))?.snapshot;
    if (snapshot != null) {
      LoggerUtil.d(
        'ProjectInstructions: loaded ${snapshot.content.length} chars '
        '(${snapshot.size} bytes) from ${snapshot.path}',
      );
    }
    return snapshot;
  }

  /// 在每次请求前复核文件是否变化。
  ///
  /// 返回新快照表示内容已变化（调用方就地替换已注入的那条消息）；返回 null
  /// 表示保持现状，包含两种情形：
  /// - 文件未变化（size 与 mtime 都相同）；
  /// - 文件被删除、不可读或已被清空——run 进行中把约定从上下文里抽走没有
  ///   收益，保留已注入的内容，下一次 run 自然不再注入。
  ProjectInstructions? refresh() {
    final read = _read(path);
    if (read == null) return null;
    if (read.size == size && read.modifiedMillis == modifiedMillis) return null;
    return read.snapshot;
  }

  static _FileRead? _read(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final stat = file.statSync();
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return null;
      return _FileRead(
        ProjectInstructions(
          path: path,
          content: content,
          size: stat.size,
          modifiedMillis: stat.modified.millisecondsSinceEpoch,
        ),
      );
    } on FileSystemException catch (e) {
      LoggerUtil.w('ProjectInstructions: cannot read $path ($e)');
      return null;
    }
  }
}

class _FileRead {
  const _FileRead(this.snapshot);

  final ProjectInstructions snapshot;

  int get size => snapshot.size;

  int get modifiedMillis => snapshot.modifiedMillis;
}
