import 'dart:io';

import 'package:athena_tui/di/tui_di.dart';
import 'package:athena_tui/ui/app.dart';
import 'package:nocterm/nocterm.dart';

Future<void> main() async {
  final di = TuiDi();
  // 首次启动会从 models.dev 拉取最新模型目录(3.2MB,约几秒);
  // 缓存新鲜(7 天内)时秒过
  stdout.writeln('Athena TUI 启动中…(首次启动同步模型目录)');
  await di.initialize();
  stdout.writeln('Athena TUI 就绪。');

  await runApp(AthenaApp(di: di));
}
