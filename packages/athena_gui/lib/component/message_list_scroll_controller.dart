import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

  /// 在列表头部插入旧消息，并保持插入前正在查看的内容位置。
  Future<int> preservePositionWhilePrepending(
    Future<int> Function() prepend,
  ) async {
    final previousMaxScrollExtent = hasClients
        ? position.maxScrollExtent
        : null;
    final added = await prepend();
    if (added <= 0 ||
        previousMaxScrollExtent == null ||
        _disposed ||
        !hasClients) {
      return added;
    }

    final completer = Completer<void>();
    var appliedExtent = 0.0;

    void scheduleCorrection(int remainingFrames) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && hasClients) {
          final currentExtent =
              position.maxScrollExtent - previousMaxScrollExtent;
          final correction = currentExtent - appliedExtent;
          if (correction.abs() >= 0.5) {
            final target = (position.pixels + correction).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            );
            _programmaticScroll = true;
            try {
              jumpTo(target);
            } finally {
              _programmaticScroll = false;
            }
          }
          appliedExtent = currentExtent;
        }

        if (remainingFrames > 1 && !_disposed) {
          scheduleCorrection(remainingFrames - 1);
        } else if (!completer.isCompleted) {
          completer.complete();
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    }

    // 可变高度 Sliver 在插入后的首帧仍可能报告旧的滚动范围；连续校正
    // 三帧，只应用范围新增量，避免估算逐帧稳定时发生可见位置跳动。
    scheduleCorrection(3);
    await completer.future;
    return added;
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
    final direction = position.userScrollDirection;
    if (direction == ScrollDirection.forward) {
      // 正向列表中，forward 表示用户正向列表顶部滚动。即使只离开底部几
      // 个像素，也应立即停止自动跟随，避免下一次流式增量把页面吸回底部。
      _followBottom = false;
      return;
    }
    if (direction == ScrollDirection.idle) return;

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
