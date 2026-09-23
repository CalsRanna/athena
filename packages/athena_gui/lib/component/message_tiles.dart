import 'dart:convert';

import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/component/base64_image.dart';
import 'package:athena_gui/component/step_card.dart';
import 'package:athena_gui/component/step_primitives.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/message_display_util.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// 会话内单条消息的渲染，以及消息底部的操作条。
///
/// 按角色分派：[MessageListTile] 只做分派，正文分别由助手 / 用户两支私有实现
/// 渲染（压缩消息归入助手卡内的步骤序列）。列表侧的懒加载与项切分在
/// `message_sliver.dart`。

class MessageListTile extends StatelessWidget {
  final bool loading;
  final MessageEntity message;
  final void Function()? onLongPress;
  final void Function(TapUpDetails)? onSecondaryTapUp;
  final void Function()? onResend;
  final SentinelEntity sentinel;

  const MessageListTile({
    super.key,
    this.loading = false,
    required this.message,
    this.onLongPress,
    this.onResend,
    this.onSecondaryTapUp,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    if (message.role == 'user') {
      return _UserMessageListTile(
        message: message,
        onLongPress: onLongPress,
        onResend: onResend,
        onSecondaryTapUp: onSecondaryTapUp,
      );
    }
    return _AssistantMessageListTile(
      loading: loading,
      message: message,
      sentinel: sentinel,
    );
  }
}

class _AssistantMessageListTile extends StatefulWidget {
  final bool loading;
  final MessageEntity message;
  final SentinelEntity sentinel;

  const _AssistantMessageListTile({
    this.loading = false,
    required this.message,
    required this.sentinel,
  });

  @override
  State<_AssistantMessageListTile> createState() =>
      _AssistantMessageListTileState();
}

class _AssistantMessageListTileState extends State<_AssistantMessageListTile> {
  final hover = AssistantCardHover();

  @override
  void dispose() {
    hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layouts = buildAssistantMessageLayouts([
      widget.message,
    ], loading: widget.loading);
    if (layouts.isEmpty) return const SizedBox.shrink();
    return AssistantMessageItem(
      layout: layouts.first,
      cardMessages: [widget.message],
      isCardHeader: true,
      isCardTail: true,
      sentinel: widget.sentinel,
      hover: hover,
    );
  }
}

/// 助手卡内的一段消息。
///
/// 卡片没有底板，因此这里只负责卡片级内边距：上内边距落在整卡第一段、下内边距
/// 落在整卡最后一段，中间各段之间零间距（段本身仍连续排布）。
class AssistantMessageItem extends StatelessWidget {
  final AssistantMessageLayout layout;
  final List<MessageEntity> cardMessages;
  final bool isCardHeader;
  final bool isCardTail;
  final SentinelEntity sentinel;

  /// 卡片级 hover 归属：操作条挂在整条助手消息上，而不是某一段上。
  final AssistantCardHover hover;

  /// 本轮尚未结束：操作条不显形。整卡同值，卡内各段无需各自判断。
  final bool suppressActions;

  const AssistantMessageItem({
    super.key,
    required this.layout,
    required this.cardMessages,
    required this.isCardHeader,
    required this.isCardTail,
    required this.sentinel,
    required this.hover,
    this.suppressActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final message = layout.message;
    return Padding(
      // 列内左右留白：Claude 的助手正文用 `--cds-assistant-message-text-inset`
      // (4) 贴住 768 定宽列的边缘
      padding: EdgeInsets.fromLTRB(
        4,
        isCardHeader ? 16 : 0,
        4,
        isCardTail ? 16 : 0,
      ),
      child: _AssistantMessageSegment(
        key: ValueKey(
          'assistant-card-segment-${message.id ?? identityHashCode(message)}',
        ),
        layout: layout,
        isCardHeader: isCardHeader,
        isCardTail: isCardTail,
        cardMessages: cardMessages,
        sentinel: sentinel,
        hover: hover,
        suppressActions: suppressActions,
        cardId: cardMessages.first.id ?? identityHashCode(cardMessages.first),
      ),
    );
  }
}

/// 卡内一条消息的呈现。
///
/// 因为整张卡是一个列表项，卡内消息数可能很大，而流式期间每来一个 delta 都会
/// 重建整张卡。这里按"渲染输入清单"记忆化：清单未变时返回同一个 Widget 实例，
/// Flutter 的 `updateChild` 会直接跳过这棵子树，于是增量只重建真正变化的那条
/// 消息，长卡的每次 delta 开销仍接近常数。
///
/// 清单用值比较而非哈希，避免碰撞造成画面陈旧；漏判只会导致多重建一次，
/// 不会渲染错内容。
class _AssistantMessageSegment extends StatelessWidget {
  final AssistantMessageLayout layout;
  final bool isCardHeader;
  final bool isCardTail;
  final List<MessageEntity> cardMessages;
  final SentinelEntity sentinel;
  final AssistantCardHover hover;

  /// 本轮尚未结束：操作条不显形。
  final bool suppressActions;

  /// 本段所属助手卡的标识，用来判定"指针是否在这张卡上"。
  final Object cardId;

  const _AssistantMessageSegment({
    super.key,
    required this.layout,
    required this.isCardHeader,
    required this.isCardTail,
    required this.cardMessages,
    required this.sentinel,
    required this.hover,
    required this.suppressActions,
    required this.cardId,
  });

  @override
  Widget build(BuildContext context) {
    // 助手消息没有头像、没有气泡：内容直接铺满列宽。
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: _AssistantMessageContent(layout: layout))],
    );
    final showActions = isCardTail && !layout.waitingForFirstDelta;
    // 操作条排在**整卡最后一段的正下方**（Claude 把它放在消息底部，不是浮在
    // 右侧）。它常驻占位、默认全透明，hover 才淡入，所以卡片高度不随 hover
    // 变化，正文也不会被压窄。
    //
    // Claude 的显形条件是**整条消息行** hover（`.group\/message-row:hover
    // [data-cds=MessageActions]`）：指针落在卡内任意一段都算。本仓每段消息各
    // 占一个列表项，所以 hover 状态放在卡片级的 [AssistantCardHover] 上——
    // 各段只上报进出，最后一段订阅它决定操作条是否可见，正文不参与重建。
    //
    // 本轮未结束时（[suppressActions]）hover 也不显形：这一轮还在跑，Copy 只能
    // 拿到半截正文。这里仍走 `visible: false` 而不是把控件摘掉——摘掉的话收尾
    // 瞬间操作条凭空出现，卡片高度变 28，流式末尾会跳一下。
    Widget result = MouseRegion(
      onEnter: (_) => hover.enter(cardId),
      onExit: (_) => hover.leave(cardId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row,
          if (showActions)
            ValueListenableBuilder<Object?>(
              valueListenable: hover.hoveredCard,
              builder: (context, hoveredCard, _) => MessageActionBar(
                visible: hoveredCard == cardId && !suppressActions,
                onCopy: () => _copyAssistantMessages(cardMessages),
              ),
            ),
        ],
      ),
    );
    return result;
  }
}

class _AssistantMessageContent extends StatelessWidget {
  final AssistantMessageLayout layout;

  const _AssistantMessageContent({required this.layout});

  @override
  Widget build(BuildContext context) {
    final message = layout.message;
    final children = <Widget>[];
    if (layout.waitingForFirstDelta) {
      children.add(const _AssistantMessageWaitingPart());
    }
    for (final (index, part) in layout.parts.indexed) {
      switch (part) {
        case StepsPart():
          children.add(
            StepCard(
              key: ValueKey(
                'steps-${message.id ?? identityHashCode(message)}-$index',
              ),
              steps: part.steps,
              live: part.live,
            ),
          );
        case ContentPart():
          children.add(const SizedBox(height: 8));
          children.add(AthenaMarkdown(message: message));
        case ReferencePart():
          children.add(
            _AssistantMessageListTileReferencePart(message: message),
          );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// 写系统剪贴板。用户消息与助手消息共用这一个出口。
void _copyMessageContent(String content) {
  Clipboard.setData(ClipboardData(text: content));
}

void _copyAssistantMessages(List<MessageEntity> messages) {
  final content = messages
      .map((message) => message.content)
      .where((content) => content.isNotEmpty)
      .join('\n\n');
  _copyMessageContent(content);
}

class _AssistantMessageWaitingPart extends StatelessWidget {
  const _AssistantMessageWaitingPart();

  @override
  Widget build(BuildContext context) {
    return const StepHeader(
      icon: LucideIcons.sparkles,
      label: 'Working…',
      running: true,
    );
  }
}

class _AssistantMessageListTileReferencePart extends StatelessWidget {
  final MessageEntity message;
  const _AssistantMessageListTileReferencePart({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.reference.isEmpty) return const SizedBox();
    try {
      final decoded = jsonDecode(message.reference);
      final references = decoded is List ? decoded : const <dynamic>[];
      List<Widget> referenceWidgets = [];
      for (var i = 0; i < references.length; i++) {
        final reference = references[i];
        if (reference is! Map<String, dynamic>) continue;
        referenceWidgets.add(_buildReference(context, reference, index: i));
      }
      var children = [Text('References:'), ...referenceWidgets];
      var column = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: children,
      );
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var boxDecoration = BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colors.codeBackground,
      );
      var textStyle = TextStyle(
        fontWeight: FontWeight.w600,
        color: colors.textOnCode,
      );
      return Container(
        decoration: boxDecoration,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: DefaultTextStyle.merge(style: textStyle, child: column),
      );
    } catch (e) {
      return const SizedBox();
    }
  }

  Future<void> openLink(String? url) async {
    var uri = Uri.parse(url ?? '');
    if (!(await canLaunchUrl(uri))) {
      AthenaDialog.warning('The link is invalid');
      return;
    }
    launchUrl(uri);
  }

  Widget _buildReference(
    BuildContext context,
    Map<String, dynamic> reference, {
    required int index,
  }) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var url = reference['url'] as String?;
    var title = reference['title'] as String?;
    var textSpan = TextSpan(
      text: title,
      style: TextStyle(color: colors.markdownLink),
      recognizer: TapGestureRecognizer()..onTap = () => openLink(url),
    );
    var children = [TextSpan(text: '${index + 1}. '), textSpan];
    return Text.rich(TextSpan(children: children));
  }
}

class _UserMessageListTile extends StatefulWidget {
  final MessageEntity message;
  final void Function()? onLongPress;
  final void Function()? onResend;
  final void Function(TapUpDetails)? onSecondaryTapUp;
  const _UserMessageListTile({
    required this.message,
    this.onLongPress,
    this.onResend,
    this.onSecondaryTapUp,
  });

  @override
  State<_UserMessageListTile> createState() => _UserMessageListTileState();
}

class _UserMessageListTileState extends State<_UserMessageListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 用户消息：**右对齐的浅灰气泡**，取自 Claude 的类
    // `bg-text/5 max-w-[77%] rounded-xl px-3 py-2`，容器 `items-end justify-end`。
    // 没有头像。
    //
    // 操作条与助手消息同一套：排在**气泡下方**、默认全透明、hover 才淡入。
    // 气泡右对齐，操作条也贴右缘。旧版把重发按钮常驻在气泡右侧，白占了一列
    // 横向位置，且静止时就能看见。
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.77,
                      ),
                      decoration: BoxDecoration(
                        color: colors.textPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: _buildContent(context),
                    ),
                  ),
                ],
              ),
            ),
            MessageActionBar(
              // 用户消息不受"本轮未结束"影响：即使正在跑，也照常 hover 显形。
              visible: _hovered,
              // Copy 始终可用；Retry 只有调用方给了回调才出现。
              onCopy: () => _copyMessageContent(widget.message.content),
              onResend: widget.onResend,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 用户消息为正文级别，用主题化正文色（浅色模式下近黑）。
    // 字号 / 行高与助手正文同一档（prose 13 / 20），否则一轮对话里
    // 问与答的字号会不一致。
    var textStyle = AthenaTextStyle.prose.copyWith(color: colors.textPrimary);
    var text = Text(widget.message.content, style: textStyle);
    var images = widget.message.imageUrls.isNotEmpty
        ? widget.message.imageUrls.split(',')
        : <String>[];
    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 9,
    );
    var gridView = GridView.builder(
      gridDelegate: delegate,
      // 以 base64 为 key：同一网格位置的元素在不同消息间复用时，
      // 避免渲染出上一条消息的图片
      itemBuilder: (context, index) => Base64Image(
        key: ValueKey(images[index]),
        base64: images[index],
        fit: BoxFit.cover,
        width: double.infinity,
      ),
      itemCount: images.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
    );
    // 图片是用户输入内容的一部分，渲染在文字之前
    var children = [if (images.isNotEmpty) gridView, text];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    // **不要给内容套带 alignment 的 Container**：Container 一旦带 alignment 就会
    // 在宽度上手撑满可用约束，气泡变成"固定 0.77 列宽"而不是"最宽 0.77 列宽"，
    // 短消息也被拉成一整条。
    //
    // 也不设 minHeight：内容贴顶对齐，缺席的高度会整块落在文字下方——单行消息
    // 于是凭空多出一行空白。气泡高度交给行盒与内边距：8 + 20 + 8 = 36 已经是
    // 单行该有的高度，短内容靠外层内边距兜底即可。
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.onLongPress,
      onSecondaryTapUp: widget.onSecondaryTapUp,
      child: column,
    );
    return gestureDetector;
  }
}

/// 助手卡的 hover 归属。
///
/// Claude 的消息操作条挂在**整条消息行**上（`.group\/message-row:hover`
/// 时 `[data-cds=MessageActions]` 显形），指针落在卡内任意一段都算 hover。
/// 本仓每段消息各占一个独立列表项、各自持有 MouseRegion，因此用一个卡级的
/// 共享 notifier 把各段的上报汇总起来：任意段进入即记为该卡，离开即清空。
///
/// 只有操作条订阅它，正文不参与重建，流式追加时的重建成本不变。
class AssistantCardHover {
  /// 当前被 hover 的卡片标识；`null` 表示没有任何卡片被 hover。
  final ValueNotifier<Object?> hoveredCard = ValueNotifier<Object?>(null);

  void enter(Object cardId) {
    if (hoveredCard.value != cardId) hoveredCard.value = cardId;
  }

  void leave(Object cardId) {
    if (hoveredCard.value == cardId) hoveredCard.value = null;
  }

  void dispose() => hoveredCard.dispose();
}

/// 消息底部的操作条，默认全透明、hover 才淡入。
///
/// 位置对齐 Claude：操作条在**消息正文的下方**，不浮在右侧。它常驻在布局
/// 里（`AnimatedOpacity`，不是 `Visibility`），所以静止时高度仍被占住，
/// hover 只改透明度、不引起跳动，也不会挤压正文宽度。
///
/// [visible] 由调用方决定：既包含 hover 归属，也包含"这一轮是否已经结束"。
/// **尚未结束的那一轮里的助手消息不显形**（流式中悬在助手正文上看不到操作条，
/// 收尾后才恢复）；用户消息不受影响，照常 hover 显形。调用方**不要**在未结束时
/// 把控件从树上摘掉，摘掉会让卡片高度在收尾瞬间变 28，末尾跳一下。
///
/// 时序逐条对齐 Claude 的 `[data-cds=MessageActions][data-reveal]`：
/// - **只动透明度**——`--cds-message-actions-reveal-scale` 在 `.cds-root`
///   上是 `none`，旧版加的 `scale(0.9)` 是自创的；
/// - 进入用 `--cds-dur-snap`(120ms) **且延迟** `...-reveal-in-delay`(100ms)；
/// - 退出用 `--cds-dur-fast`(60ms) 且无延迟。
/// 延迟用 `Interval` 曲线表达：前 100/220 的进度里保持全透明。
class MessageActionBar extends StatelessWidget {
  final bool visible;
  final VoidCallback? onCopy;
  final VoidCallback? onResend;

  const MessageActionBar({
    super.key,
    required this.visible,
    this.onCopy,
    this.onResend,
  });

  static const _inDelayMs = 100.0;
  static const _inDurMs = 120.0;
  static const _outDurMs = 60.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 与正文之间的呼吸位。这块高度常驻，hover 前后不变。
      padding: const EdgeInsets.only(top: 4),
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Duration(
            milliseconds: (visible ? _inDelayMs + _inDurMs : _outDurMs).round(),
          ),
          curve: visible
              ? const Interval(
                  _inDelayMs / (_inDelayMs + _inDurMs),
                  1,
                  curve: Curves.easeOut,
                )
              : Curves.linear,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onCopy != null)
                _MessageActionButton(
                  icon: LucideIcons.copy,
                  tooltip: 'Copy',
                  onTap: onCopy,
                ),
              if (onResend != null)
                _MessageActionButton(
                  icon: LucideIcons.refreshCw,
                  tooltip: 'Retry',
                  onTap: onResend,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 操作条上的一个 ghost 图标按钮。
///
/// 尺寸取自 Claude：控件高 `--cds-h-control`(24)，图标 `--cds-icon`(16)，
/// 圆角 `--cds-radius--lg`(7)，hover 填充 `--cds-fill-ghost-hover`
/// （浅色 alpha-1 ≈ 5%）。
class _MessageActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _MessageActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  State<_MessageActionButton> createState() => _MessageActionButtonState();
}

class _MessageActionButtonState extends State<_MessageActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered
                  ? colors.textPrimary.withValues(alpha: 0.05)
                  : colors.textPrimary.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(AthenaRadius.row),
            ),
            child: Icon(widget.icon, size: 16, color: colors.iconSecondary),
          ),
        ),
      ),
    );
  }
}
