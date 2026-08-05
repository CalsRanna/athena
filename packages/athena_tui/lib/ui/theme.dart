import 'package:nocterm/nocterm.dart';

/// Athena 设计语言在终端的映射(源自 DESIGN.md 的色板)。
///
/// 终端是深色底,背景不设色(用终端默认),主要用文字色与边框表达层级。
abstract class AthenaColors {
  /// 品牌 teal(#6ABEB9):用户消息前缀、状态高亮。
  static const Color teal = Color.fromRGB(106, 190, 185);

  /// 次级文字(对应 Gray 600 #9E9E9E)。
  static const Color dim = Colors.gray;

  /// 错误红、警告黄、信息蓝、成功绿。
  static const Color error = Colors.red;
  static const Color warning = Colors.yellow;
  static const Color info = Colors.blue;
  static const Color success = Colors.green;

  /// 工具卡片边框。
  static const Color toolBorder = Color.fromRGB(88, 102, 130);
}

/// 消息卡片左侧竖线色:按消息类型分色,替代文字前缀标记。
abstract class AthenaCardColors {
  /// 用户消息:品牌 teal。
  static const Color user = AthenaColors.teal;

  /// 助手消息:主要内容,最亮。
  static const Color assistant = Colors.white;

  /// 系统消息:弱化。
  static const Color system = AthenaColors.dim;

  /// 推理卡片(思考过程)。
  static const Color reasoning = AthenaColors.warning;

  /// 工具调用卡片。
  static const Color toolCall = AthenaColors.info;

  /// 工具结果卡片。
  static const Color toolResult = AthenaColors.success;

  /// 错误消息。
  static const Color error = AthenaColors.error;

  /// 已取消消息。
  static const Color cancelled = Colors.gray;
}

/// 常见文本样式。
abstract class AthenaTextStyles {
  static const TextStyle dim = TextStyle(color: AthenaColors.dim);
  static const TextStyle teal = TextStyle(color: AthenaColors.teal);
  static const TextStyle error = TextStyle(color: AthenaColors.error);
  static const TextStyle warning = TextStyle(color: AthenaColors.warning);
  static const TextStyle info = TextStyle(color: AthenaColors.info);

  /// 状态栏:反色白字。
  static const TextStyle statusBar = TextStyle(
    backgroundColor: AthenaColors.teal,
    color: Color.fromRGB(20, 30, 30),
    fontWeight: FontWeight.bold,
  );
}
