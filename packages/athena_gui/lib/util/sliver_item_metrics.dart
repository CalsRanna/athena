import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 懒加载 sliver 的项度量。
///
/// Flutter 没有「滚到第 n 项」的 API：`SliverList` 只构建视口（含缓存区）附近的
/// 项，未构建的项连高度都不存在。所以「视口当前在哪一项」与「第 n 项现在在哪」
/// 只能从已构建的子项上读——子项的 `layoutOffset`（sliver 滚动坐标系里的位置）
/// 与自身高度，配上 `constraints.scrollOffset`（视口首边在同一个坐标系里的位置）
/// 就够用了。
///
/// 抽成独立助手是为了能单独验证这套坐标系换算：真正的消息列表要接
/// GetIt / 主题，探针里跑不起来。
abstract final class SliverItemMetrics {
  /// 视口内**可见**的第一项下标；没有已构建的子项时返回 null。
  ///
  /// 用来判断"目标在视口上方还是下方"，不用于高亮：贴着列表底部时，视口顶
  /// 往往还留着上一轮的尾巴，用它会一直高亮上一轮。
  static int? firstVisibleIndex(RenderSliverList sliver) {
    final top = sliver.constraints.scrollOffset;
    int? bestIndex;
    double? bestOffset;
    _visitLaidOut(sliver, (index, offset, extent) {
      // 下边缘越过视口顶才算可见
      if (offset + extent <= top) return;
      if (bestOffset == null || offset < bestOffset!) {
        bestOffset = offset;
        bestIndex = index;
      }
    });
    return bestIndex;
  }

  /// 视口里**占得最多**的那一项下标：它就是"用户此刻在看的那一项"。
  static int? dominantItemIndex(RenderSliverList sliver) {
    final constraints = sliver.constraints;
    final top = constraints.scrollOffset;
    final bottom = top + constraints.viewportMainAxisExtent;
    int? bestIndex;
    var bestOverlap = 0.0;
    _visitLaidOut(sliver, (index, offset, extent) {
      final overlap = math.min(offset + extent, bottom) - math.max(offset, top);
      if (overlap <= bestOverlap) return;
      bestOverlap = overlap;
      bestIndex = index;
    });
    return bestIndex;
  }

  /// 把第 [itemIndex] 项顶到视口首边所需的滚动偏移；该项未被构建时返回 null。
  static double? viewportOffsetOf(
    RenderSliverList sliver,
    ScrollPosition position,
    int itemIndex,
  ) {
    double? layoutOffset;
    _visitLaidOut(sliver, (index, offset, extent) {
      if (index == itemIndex) layoutOffset = offset;
    });
    final offset = layoutOffset;
    if (offset == null) return null;
    return position.pixels + (offset - sliver.constraints.scrollOffset);
  }

  /// 已构建子项的平均主轴尺寸；没有子项时返回 0。
  static double averageChildExtent(RenderSliverList sliver) {
    var total = 0.0;
    var count = 0;
    _visitLaidOut(sliver, (index, offset, extent) {
      total += extent;
      count++;
    });
    return count == 0 ? 0 : total / count;
  }

  /// 遍历**已构建且在视口内**的子项。
  ///
  /// 被 `keepAlive` 留下的项虽然还在子项链表里，但已经不在视口中、位置也是旧的，
  /// 直接跳过。
  static void _visitLaidOut(
    RenderSliverList sliver,
    void Function(int index, double layoutOffset, double extent) visit,
  ) {
    sliver.visitChildren((child) {
      final data = child.parentData;
      if (data is! SliverMultiBoxAdaptorParentData || data.keptAlive) return;
      final index = data.index;
      final offset = data.layoutOffset;
      if (index == null || offset == null || child is! RenderBox) return;
      visit(index, offset, child.size.height);
    });
  }
}
