import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 仅给会话消息叠加字号档位，composer、placeholder 和其他 UI 保留系统缩放。
class AthenaWorkspaceTextSize extends StatelessWidget {
  final AthenaTextSize size;
  final Widget child;

  const AthenaWorkspaceTextSize({
    super.key,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 保持原有叠加口径：按正文号取得系统缩放系数，不覆盖无障碍设置。
    final systemScale =
        media.textScaler.scale(AthenaFontSize.body) / AthenaFontSize.body;
    // 各档保持同一层级，避免切换 Medium 时重建消息列表、丢失展开状态。
    return MediaQuery(
      data: media.copyWith(
        textScaler: size.scale == 1.0
            ? media.textScaler
            : TextScaler.linear(systemScale * size.scale),
      ),
      child: child,
    );
  }
}
