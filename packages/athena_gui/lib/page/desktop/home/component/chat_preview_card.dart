import 'dart:math' as math;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 侧栏会话行的悬浮预览卡：鼠标停在会话行上时，在行右侧弹出的一张浮层。
///
/// 只有两行内容：
/// - 第一行：会话标题
/// - 第二行：会话**开头那一轮**的 agent 回答正文（首条用户消息之后紧跟的
///   那条回答，见 `MessageRepository.getOpeningAnswerPreview`）。它不是最新
///   消息——最新一条可能只是工具步骤，或还没收尾的占位。
///
/// 它只读、不可点，所以整张卡不参与命中测试（见 [DesktopChatPreviewManager]
/// 的 `IgnorePointer`）：卡片压在指针旁边的行上时，不该把 hover 从行上抢走，
/// 否则卡片一弹出侧栏行的 hover 底色就"熄"了。
class ChatPreviewCard extends StatelessWidget {
  /// 卡片宽度。侧栏 288，卡片越过侧栏右边缘压在画布上，给正文留出能读
  /// 两三句的宽度。
  static const double width = 248;

  /// 卡片最大高度（标题 19 + 间距 4 + 正文 3 行约 53 + 上下内边距 22）。
  /// 只用于贴到窗口下沿时的位置回退，实际高度由内容决定。
  static const double maxHeight = 100;

  final String title;
  final String answer;

  const ChatPreviewCard({super.key, required this.title, required this.answer});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Container(
      width: width,
      decoration: BoxDecoration(
        // 浮层底色与右键菜单同档：比侧栏面板亮一级 + 柔阴影，不描边
        color: colors.surfaceMobile,
        borderRadius: BorderRadius.circular(AthenaRadius.container),
        boxShadow: AthenaShadow.overlay(colors.shadow),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            flatten(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AthenaTextStyle.body.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              height: AthenaFontSize.bodyHeight,
              decoration: TextDecoration.none,
            ),
          ),
          // 这一轮还没收尾（回答未落库）时只显示提问，不占一行空文案
          if (answer.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              flatten(answer),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AthenaTextStyle.caption.copyWith(
                color: colors.textSecondary,
                height: AthenaFontSize.bodyHeight,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 把正文压成一段：换行、缩进、代码块里的空白都并成单个空格——卡片是
  /// 摘要位，保留原始段落只会让头几行全是空行。
  static String flatten(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 悬浮预览卡的浮层管理：同一时刻只留一张卡。
///
/// 鼠标在行间快速划过时，旧行先 [dismissFor]、新行再 [show]，不会叠出两张；
/// 卡片归属由 [show] 的 `owner` 标记，行 State 销毁时只关自己那张，不会误关
/// 别人刚弹出的。
///
/// 卡片刻意不带遮罩层：它不像右键菜单那样要吃掉"点外面关闭"的手势，指针
/// 停在行上才是它的常态。
class DesktopChatPreviewManager {
  /// 正在显示的卡。
  OverlayEntry? _entry;
  GlobalKey<_PreviewCardOverlayState>? _key;

  /// 正在播退场动画、还没摘掉的卡（指针已移开，卡片还在淡出）。
  OverlayEntry? _hidingEntry;
  Object? _owner;
  static DesktopChatPreviewManager instance = DesktopChatPreviewManager();

  /// 卡片与锚点行的间距。
  static const double gap = 8;

  /// 卡片离窗口边缘留的余量。
  static const double margin = 8;

  /// 进场时长（淡入 + 从下浮起 + 轻微放大）。
  static const Duration appearDuration = Duration(milliseconds: 140);

  /// 退场时长。比进场短：指针已经移开，收卡要跟手。
  static const Duration hideDuration = Duration(milliseconds: 100);

  /// 在 [anchor]（会话行的全局矩形）右侧弹出预览卡；右侧/下侧放不下时回退。
  void show(
    BuildContext context, {
    required Object owner,
    required Rect anchor,
    required String title,
    required String answer,
  }) {
    // 上一张直接摘掉（不等它淡出）：鼠标挪到另一行时不该看到两张卡
    _clear();
    final key = GlobalKey<_PreviewCardOverlayState>();
    _key = key;
    final size = MediaQuery.sizeOf(context);
    final left = math.min(
      anchor.right + gap,
      size.width - ChatPreviewCard.width - margin,
    );
    final top = math.min(
      anchor.top,
      size.height - ChatPreviewCard.maxHeight - margin,
    );
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              left: math.max(left, margin),
              top: math.max(top, margin),
              child: Material(
                color: Colors.transparent,
                child: _PreviewCardOverlay(
                  key: key,
                  onHidden: _handleHidden,
                  child: ChatPreviewCard(title: title, answer: answer),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    _entry = entry;
    _owner = owner;
    Overlay.of(context).insert(entry);
  }

  /// 只关掉 [owner] 自己那张卡（别的行刚弹出的卡不动）。
  void dismissFor(Object owner) {
    if (!identical(_owner, owner)) return;
    dismiss();
  }

  /// 收卡：先播退场动画，播完再摘掉浮层。已经在收卡、或控件已不可用时直接摘。
  void dismiss() {
    final entry = _entry;
    if (entry == null) return;
    final state = _key?.currentState;
    _entry = null;
    _owner = null;
    if (state == null || !state.hide()) {
      entry.remove();
      return;
    }
    // 退场期间这张卡仍挂在浮层上，播完由 _handleHidden 摘除
    _hidingEntry = entry;
  }

  /// 退场动画播完：把还在淡出的那张摘掉。
  void _handleHidden() {
    _hidingEntry?.remove();
    _hidingEntry = null;
  }

  /// 立刻摘掉所有卡片（显示中的与还在淡出的），不播动画。
  void _clear() {
    _entry?.remove();
    _hidingEntry?.remove();
    _entry = null;
    _hidingEntry = null;
    _key = null;
    _owner = null;
  }
}

/// 卡片的进出场：淡入 + 从下方轻微浮起 + 轻微放大，退场反向。
///
/// 动画挂在这个内部控件上，[DesktopChatPreviewManager] 用 GlobalKey 拿它的
/// State 调 [hide]，退场播完再由 onHidden 摘 OverlayEntry——直接 remove 会让
/// 卡片"啪"地消失。
class _PreviewCardOverlay extends StatefulWidget {
  final Widget child;

  /// 反向动画播完（卡片已不可见）时回调。
  final void Function() onHidden;

  const _PreviewCardOverlay({
    super.key,
    required this.child,
    required this.onHidden,
  });

  @override
  State<_PreviewCardOverlay> createState() => _PreviewCardOverlayState();
}

class _PreviewCardOverlayState extends State<_PreviewCardOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DesktopChatPreviewManager.appearDuration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );
  bool _hiding = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 开始退场；已经在退场时返回 false，调用方直接摘掉浮层。
  bool hide() {
    if (_hiding) return false;
    _hiding = true;
    _controller.duration = DesktopChatPreviewManager.hideDuration;
    // 被 remove 掉时 ticker 取消，whenComplete 不会触发，也就不会回调已失效的 entry
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onHidden();
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _progress,
      child: SlideTransition(
        // 位移取卡片高度的百分比：0.06 约 6px，够看出"浮起来"又不飘
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_progress),
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(_progress),
          child: widget.child,
        ),
      ),
    );
  }
}
