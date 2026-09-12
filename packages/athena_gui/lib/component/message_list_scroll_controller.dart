import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 消息列表的正向滚动控制器。
///
/// 正向列表中底部对应 [ScrollPosition.maxScrollExtent]。控制器只在同时满足
/// 以下条件时才跟随消息增长：
///
/// - 仍处于跟随状态：用户自己滚动到了列表最底部，或切换会话 / 发送消息时
///   通过 [followBottom] 显式要求停留在底部；
/// - agent 正在工作中（[isWorking]），或处于显式跟随期间。
///
/// 用户主动向上滚动后立即停止跟随，且不会因为「距底部很近」重新吸附；只有
/// 真正滚回最底部才会重新进入跟随。
class MessageListScrollController extends ScrollController {
  /// 判定「已到达最底部」的像素容差。
  ///
  /// 覆盖物理回弹与超长懒加载列表估算带来的亚像素误差；取值远小于任何可见
  /// 距离，保证距底部还差一段时不会被内容增量吸底。
  static const double defaultAtBottomEpsilon = 1;

  final double atBottomEpsilon;

  bool _followBottom = true;
  bool _followExplicitly = false;
  bool _programmaticScroll = false;
  bool _frameScheduled = false;
  bool _rescheduleRequested = false;
  bool _disposed = false;

  MessageListScrollController({this.atBottomEpsilon = defaultAtBottomEpsilon}) {
    addListener(_updateFollowState);
  }

  /// agent 是否正在工作中（当前会话流式生成）。
  ///
  /// 由消息列表在每次构建时写入。只有工作中（或 [followBottom] 显式跟随
  /// 期间）内容增长才会自动贴底，避免 agent 空闲时列表在用户眼前自己滚动。
  bool isWorking = false;

  /// 当前是否应当对内容增长保持贴底。
  ///
  /// 供 [_MessageListScrollPosition] 在布局阶段判断；只读取状态、不触发
  /// 滚动。跟随状态本身只由用户手势（见 [_updateFollowState]）和
  /// [followBottom] 改变。
  bool get shouldStickToBottom =>
      _followBottom && (isWorking || _followExplicitly);

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _MessageListScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      controller: this,
    );
  }

  /// 在下一帧布局完成后保持列表位于底部。
  ///
  /// 仅在仍满足 [shouldStickToBottom] 时移动列表：用户已经向上滚动，或
  /// agent 空闲且非显式跟随时都不干预。
  void maintainBottom() => _scheduleScrollToBottom();

  /// 强制在下一帧跳到底部，并重新启用后续内容的底部跟随。
  ///
  /// 用于发送消息、切换会话等显式要求停留在底部的场景。显式跟随不受
  /// [isWorking] 限制，直到用户主动向上滚动才解除。
  void followBottom() {
    _followBottom = true;
    _followExplicitly = true;
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
    if (_disposed || !shouldStickToBottom) return;
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
      if (_disposed || !shouldStickToBottom || !hasClients) return;

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
      // 个像素，也应立即停止自动跟随（同时解除显式跟随），避免下一次流式
      // 增量把页面吸回底部。
      _followBottom = false;
      _followExplicitly = false;
      return;
    }
    if (direction == ScrollDirection.idle) return;

    // 只有真正滚动到最底部才算重新进入跟随；距底部还差一段可见距离时保持
    // 不吸附，否则用户想停在底部附近查看内容会被内容增量瞬间拉走。
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    _followBottom = distanceFromBottom <= atBottomEpsilon;
  }

  @override
  void dispose() {
    _disposed = true;
    removeListener(_updateFollowState);
    super.dispose();
  }
}

/// 在布局阶段完成贴底校正的 [ScrollPosition]。
///
/// 正向列表的滚动偏移只在布局时决定子项位置（绘制阶段不再叠加偏移），
/// 因此 post-frame 回调里的 jumpTo 必然晚一帧：内容变高的那一帧仍按旧
/// 偏移绘制，卡片底部被视口切平，下一帧才跳回底部，流式输出时表现为
/// 持续闪烁。这里在 [correctForNewDimensions] 中直接对齐并返回 false，
/// 视口会在同一帧内重新布局，该帧绘制时就已经贴底。
class _MessageListScrollPosition extends ScrollPositionWithSingleContext {
  _MessageListScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.controller,
  });

  final MessageListScrollController controller;

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    // 只在应当贴底（controller.shouldStickToBottom）、且没有正在进行的
    // 滚动（拖动或惯性）时贴底；滚动中不干预，否则用户向底部甩动时来新
    // 内容会被瞬间吸底。
    if (controller.shouldStickToBottom &&
        !(activity?.isScrolling ?? false) &&
        newPosition.pixels < newPosition.maxScrollExtent - 0.5) {
      correctPixels(newPosition.maxScrollExtent);
      // 返回 false 让视口带新偏移重新布局，把校正吃进当前帧。
      return false;
    }
    return super.correctForNewDimensions(oldPosition, newPosition);
  }
}
