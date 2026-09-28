import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 仅给会话正文与代码提供固定排版，完整保留系统的文字缩放规则。
class AthenaWorkspaceTextSize extends InheritedWidget {
  final AthenaTextSize size;

  const AthenaWorkspaceTextSize({
    super.key,
    required this.size,
    required super.child,
  });

  static AthenaTextSize of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AthenaWorkspaceTextSize>()
          ?.size ??
      AthenaTextSize.medium;

  @override
  bool updateShouldNotify(AthenaWorkspaceTextSize oldWidget) =>
      size != oldWidget.size;
}
