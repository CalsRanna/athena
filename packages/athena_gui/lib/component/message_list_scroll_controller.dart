import 'package:flutter/material.dart';

/// 消息列表的正向滚动控制器。
///
/// 正向列表中底部对应 [ScrollPosition.maxScrollExtent]。控制器只在用户仍位于
/// 底部附近时跟随消息增长；用户主动向上滚动后停止跟随。切换会话或发送消息时
/// 可通过 [followBottom] 重新启用跟随。
class MessageListScrollController extends ScrollController {
  static const double defaultBottomThreshold = 80;

  final double bottomThreshold;

  bool _followBottom = true;
  bool _programmaticScroll = false;
  bool _frameScheduled = false;
  bool _rescheduleRequested = false;
  bool _disposed = false;

  MessageListScrollController({this.bottomThreshold = defaultBottomThreshold}) {
    addListener(_updateFollowState);
  }

  /// 在下一帧布局完成后保持列表位于底部。
  ///
  /// 用户已经向上滚动时不会移动列表。
  void maintainBottom() => _scheduleScrollToBottom();

  /// 强制在下一帧跳到底部，并重新启用后续内容的底部跟随。
  void followBottom() {
    _followBottom = true;
    _scheduleScrollToBottom();
  }

  /// 视口高度或内容尺寸变化时，在仍跟随底部的前提下重新对齐。
  bool handleMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth == 0) maintainBottom();
    return false;
  }

  void _scheduleScrollToBottom() {
    if (_disposed || !_followBottom) return;
    if (_frameScheduled) {
      // 消息更新与已排队的回调可能落在同一帧。记录补调度请求，避免第一次
      // 回调读取到布局前的旧 maxScrollExtent 后就停止。
      _rescheduleRequested = true;
      return;
    }
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      final shouldReschedule = _rescheduleRequested;
      _rescheduleRequested = false;
      if (_disposed || !_followBottom || !hasClients) return;

      final target = position.maxScrollExtent;
      if ((position.pixels - target).abs() >= 0.5) {
        _programmaticScroll = true;
        try {
          jumpTo(target);
        } finally {
          _programmaticScroll = false;
        }
      }
      if (shouldReschedule) _scheduleScrollToBottom();
    });
  }

  void _updateFollowState() {
    if (_disposed || _programmaticScroll || !hasClients) return;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    _followBottom = distanceFromBottom <= bottomThreshold;
  }

  @override
  void dispose() {
    _disposed = true;
    removeListener(_updateFollowState);
    super.dispose();
  }
}
