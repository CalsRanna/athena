import 'dart:io';

import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/no_clipboard_backend.dart';
import 'package:athena_tui/ui/app.dart';
import 'package:nocterm/nocterm.dart';

/// 用法:athena [工作区目录]
///
/// 工作区目录可选:Agent 的 shell/file/skill 工具都以它作为工作根目录
/// (核心层基于 Directory.current 解析路径)。未指定时默认使用当前目录;
/// 目录不存在时自动创建。
Future<void> main(List<String> args) async {
  final workspace = args.isEmpty
      ? Directory.current
      : Directory(args.first);
  await workspace.create(recursive: true);
  // 全局工作区:核心层(shell workdir 默认值、file 工具相对路径、
  // skill 项目目录)都基于 Directory.current 解析
  Directory.current = workspace;

  final di = TuiDi(workspace: workspace.path);
  // 首次启动会从 models.dev 拉取最新模型目录(3.2MB,约几秒);
  // 缓存新鲜(7 天内)时秒过
  stdout.writeln('Athena TUI 启动中…工作区: ${workspace.path}');
  await di.initialize();
  stdout.writeln('Athena TUI 就绪。');

  // 包装 StdioBackend:过滤 OSC 52 剪贴板写入,避免 macOS 26.4+ 在
  // 终端粘贴内容时弹出 "tried to write to your clipboard" 安全警告
  // (nocterm 会在粘贴事件里把内容写回系统剪贴板)。
  await runApp(
    AthenaApp(di: di),
    backend: NoClipboardBackend(StdioBackend()),
  );
}
