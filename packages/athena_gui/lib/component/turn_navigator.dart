import 'package:flutter/foundation.dart';

/// 消息列表与轮次指示器之间的桥。
///
/// 「视口当前在第几轮」与「跳到第几轮」这两件事只有消息 sliver 的布局阶段才
/// 知道：消息列表是懒加载的，没被构建的项连高度都不存在。所以信息单向流动——
/// sliver 把测出来的当前轮写进 [currentTurnIndex]，指示器读它；反向则由指示器
/// 调 [scrollToTurn]，落到 sliver 登记进来的滚动实现上。
class TurnNavigator {
  /// 视口当前所在的那一轮下标；-1 = 还没测出来，或本次会话没有轮次。
  ///
  /// 用 [ValueNotifier] 而不是全局 signal：它只服务于指示器一个订阅者，
  /// 且值随滚动每一帧都可能变。
  final ValueNotifier<int> currentTurnIndex = ValueNotifier<int>(-1);

  void Function(int turnIndex)? _scrollToTurn;

  /// 由消息 sliver 登记滚动实现；sliver 销毁时传 null 解除。
  void bindScroller(void Function(int turnIndex)? scrollToTurn) {
    _scrollToTurn = scrollToTurn;
  }

  /// 把第 [turnIndex] 轮滚到视口顶部。
  void scrollToTurn(int turnIndex) => _scrollToTurn?.call(turnIndex);

  void dispose() => currentTurnIndex.dispose();
}
