import 'package:athena_gui/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

/// 上下文条上的「本会话工作文件夹」入口，紧跟在 Sentinel chip 之后。
///
/// 与 Sentinel 用同一种 chip（`filled: false`——带的底色已是浅灰，chip 再画
/// 一层同色底就成了看不见的胶囊）。未设置时显示 `No folder`；设置后显示
/// 文件夹名，并在 chip 内出现清除按钮（native 目录选择器选不出「不指定」，
/// 清除必须另有入口）。完整路径放在 tooltip 里，标签会被截断。
///
/// 只影响后续 run：运行中的 run 已在开始时解析并持有自己的基准，改这项不会
/// 让正在跑的一轮中途换目录。
class DesktopWorkspaceIndicator extends StatelessWidget {
  final String? path;
  final void Function()? onTap;
  final void Function()? onClear;

  const DesktopWorkspaceIndicator({
    super.key,
    required this.path,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final set = path != null && path!.isNotEmpty;
    return Tooltip(
      // 只放路径本身/一句话，宽度受限后长路径才换行而不是拉成一整条
      message: set ? path! : 'No working folder',
      preferBelow: false,
      constraints: const BoxConstraints(maxWidth: 280),
      child: AthenaContextChip(
        leading: const Icon(LucideIcons.folder),
        label: set ? p.basename(path!) : 'No folder',
        onTap: onTap,
        filled: false,
        // 内层 onTap 在命中测试里先于 chip 的 onTap 生效
        trailing: set
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClear,
                child: const Icon(LucideIcons.x, size: 12),
              )
            : null,
      ),
    );
  }
}
