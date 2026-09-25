import 'package:athena_gui/component/chat_column.dart';
import 'package:athena_gui/component/queued_messages.dart';
import 'package:athena_gui/page/desktop/home/component/context_selector.dart';
import 'package:athena_gui/page/desktop/home/component/image_selector.dart';
import 'package:athena_gui/page/desktop/home/component/model_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/permission_mode_selector.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/reasoning_effort_selector.dart';
import 'package:athena_gui/page/desktop/home/component/token_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/workspace_indicator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/pending_image.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopMessageInput extends StatelessWidget {
  final TextEditingController controller;

  /// 输入框的焦点节点，由首页持有并 dispose：新建对话、启动落到草稿页时
  /// 首页靠它把焦点放进输入框。
  final FocusNode focusNode;
  final void Function(int)? onRetentionChange;
  final void Function(List<String>)? onImageSelected;
  final Future<bool> Function()? onPasteImages;
  final void Function(int)? onImageRemoved;
  final void Function()? onSubmitted;
  final void Function(String)? onReasoningEffortChange;
  final void Function()? onTerminated;

  /// 点击模型名：回传那一块（含 hover 填充）的全局矩形，模型菜单锚在它上方。
  final void Function(Rect anchor)? onModelTap;

  /// 点击 Sentinel chip：回传 chip 的全局矩形，角色菜单锚在它上方。
  final void Function(Rect anchor)? onSentinelTap;

  /// 清除本会话的 Sentinel（回到「不选择任何 Sentinel」）。
  final void Function()? onSentinelClear;

  /// 选择/清除本会话的工作文件夹（目录选择器在 ViewModel 层弹）。
  final void Function()? onWorkspaceTap;
  final void Function()? onWorkspaceClear;
  const DesktopMessageInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onRetentionChange,
    this.onImageSelected,
    this.onPasteImages,
    this.onImageRemoved,
    this.onSubmitted,
    this.onReasoningEffortChange,
    this.onTerminated,
    this.onModelTap,
    this.onSentinelTap,
    this.onSentinelClear,
    this.onWorkspaceTap,
    this.onWorkspaceClear,
  });
  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // Claude 的 ghost 按钮 hover 填充：前景色 5%
    final ghostHover = colors.textPrimary.withValues(alpha: 0.05);
    return Watch((context) {
      final queued = chatViewModel.queuedMessages.value;
      // 在 Watch 内订阅；放进下方 builder 会延迟到另一个 build，图片变化就不重绘。
      final images = chatViewModel.pendingImages.value;
      final chatId = chatViewModel.currentChat.value?.id;
      // 推理强度只对推理模型有意义（发送端也只给推理模型带参数），
      // 非推理模型不摆这个控件——摆了也没有任何效果。
      final reasoningModel =
          chatViewModel.currentModel.value?.reasoning ?? false;
      final reasoningEffort = chatViewModel.currentReasoningEffort.value;
      // 版式取自 **Claude 桌面端**：
      // 上面一条灰色上下文条、下面一个白底描边的输入框，两者是**独立的圆角容器**；
      // 权限/工具与模型/发送则在两个容器**外面**单独排一行。
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kChatColumnWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (queued.isNotEmpty) ...[
                  QueuedMessages(messages: queued),
                  const SizedBox(height: 12),
                ],
                // 上下文条：灰底、无描边
                Container(
                  height: 40,
                  // Claude 实测：带内首个元素距容器左缘 17（含 chip 自身 10）
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: colors.surfaceButtonSecondary,
                    borderRadius: BorderRadius.circular(AthenaRadius.container),
                  ),
                  child: Row(
                    children: [
                      DesktopSentinelIndicator(
                        onTap: onSentinelTap,
                        onClear: onSentinelClear,
                      ),
                      const SizedBox(width: 4),
                      // 草稿态也能设工作文件夹（随草稿一起落盘），所以读
                      // current* 信号而不是 chat 字段，两种状态一个来源
                      DesktopWorkspaceIndicator(
                        path: chatViewModel.currentWorkspacePath.value,
                        onTap: onWorkspaceTap,
                        onClear: onWorkspaceClear,
                      ),
                      const Spacer(),
                      // 当前保留策略同时服务草稿和已有会话，选项从 chip 向上展开。
                      DesktopContextSelector(
                        currentRetention: chatViewModel.currentRetention.value,
                        onSelected: onRetentionChange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                // 输入容器：白底（surfaceMobile 是纯白那档）+ 1px 描边
                _ComposerInputBox(
                  focusNode: focusNode,
                  builder: (focusNode) => Row(
                    children: [
                      Expanded(
                        child: _Input(
                          controller: controller,
                          chatId: chatId,
                          focusNode: focusNode,
                          images: images,
                          onPasteImages: onPasteImages,
                          onImageRemoved: onImageRemoved,
                          onSubmitted: images.every((image) => image.isReady)
                              ? onSubmitted
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _SendButton(
                        onSubmitted: onSubmitted,
                        onTerminated: onTerminated,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // 容器之外的一行
                Row(
                  children: [
                    // Claude 的左侧是「一段文字 + 一个裸字形」（Bypass permissions +）：
                    // 文字是审批模式，点开 Mode 菜单；字形是加号（选图片）。
                    // 菜单要锚在整块（含 hover 填充）上，用 Builder 拿它的矩形。
                    Builder(
                      builder: (context) => _SquishButton(
                        hoverFill: ghostHover,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        onTap: () => DesktopPermissionModeMenu.show(
                          context,
                          contextMenuAnchorOf(context),
                        ),
                        child: const DesktopPermissionModeLabel(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SquishButton(
                      hoverFill: ghostHover,
                      child: DesktopImageSelector(onSelected: onImageSelected),
                    ),
                    const Spacer(),
                    // 用 Builder 拿到这一整块的矩形回传，菜单右边要与它对齐
                    Builder(
                      builder: (context) => _SquishButton(
                        hoverFill: ghostHover,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        onTap: () =>
                            onModelTap?.call(contextMenuAnchorOf(context)),
                        child: const DesktopModelIndicator(),
                      ),
                    ),
                    if (reasoningModel) ...[
                      const SizedBox(width: 4),
                      // Effort 面板锚在这一整块上方、右对齐
                      Builder(
                        builder: (context) => _SquishButton(
                          hoverFill: ghostHover,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          onTap: () => DesktopReasoningEffortMenu.show(
                            context,
                            contextMenuAnchorOf(context),
                            current: reasoningEffort,
                            onSelected: onReasoningEffortChange,
                          ),
                          child: DesktopReasoningEffortLabel(
                            current: reasoningEffort,
                          ),
                        ),
                      ),
                    ],
                    // Claude 实测：`High` 与右侧圆环之间约 20
                    const SizedBox(width: 12),
                    const DesktopTokenIndicator(),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _Input extends StatefulWidget {
  final TextEditingController controller;

  /// 当前对话的 id（草稿态是 null）。只在换对话时用来重置本组件自己的状态；
  /// 注意**不能让它变成 key**，理由见 [_InputState.didUpdateWidget]。
  final int? chatId;

  /// 外部传入的焦点节点：composer 的容器要靠它切换边框色。
  final FocusNode? focusNode;
  final List<PendingImage> images;
  final Future<bool> Function()? onPasteImages;
  final void Function(int)? onImageRemoved;
  final void Function()? onSubmitted;

  /// 刻意不收 `key`：这个元素承载 composer 的焦点节点，换 key 会把它重建掉，
  /// 从而导致换对话后"看着聚焦却打不进字"（见 [_InputState.didUpdateWidget]）。
  /// 需要按对话重置状态就往 [chatId] 里传，别在这里加 key。
  const _Input({
    required this.controller,
    this.chatId,
    this.focusNode,
    this.images = const [],
    this.onPasteImages,
    this.onImageRemoved,
    this.onSubmitted,
  });

  @override
  State<_Input> createState() => _InputState();
}

class _SendIntent extends Intent {
  const _SendIntent();
}

class _NewlineIntent extends Intent {
  const _NewlineIntent();
}

class _InputState extends State<_Input> {
  bool _pasting = false;
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(_Input oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换对话（草稿↔对话、对话 A↔对话 B）时重置本组件自己的状态。
    //
    // **不能用换 key 来重建**：这个元素承载着 composer 的焦点节点（`focusNode`
    // 一路传给 TextField）。换 key 会销毁旧的 EditableText 连同它的文本输入连接，
    // 而焦点节点是同一个对象、焦点自始至终没有变化，新建的 EditableText 只会在
    // 焦点变化时才重开连接（`EditableText._handleFocusChanged` → `_openInputConnection`），
    // 于是输入框"看起来聚焦、实际打不进字"——⌘N 新建对话（对话→草稿）后正是
    // 这个状态，页里那次 `requestFocus` 也救不回来：节点仍持焦，请求会被
    // FocusNode 当作无变化直接忽略。
    if (widget.chatId == oldWidget.chatId) return;
    _pasting = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var hintTextStyle = AthenaTextStyle.body.copyWith(
      // Claude 实测：占位符是**浅灰** #898782（gray-400），不是深色。
      // 之前那条"深色"的结论是我把光标误当成了文字。
      color: colors.textWeak,
      height: 1.5,
    );
    var inputDecoration = InputDecoration.collapsed(
      hintText: 'Ask me anything',
      hintStyle: hintTextStyle,
    );
    final inputTextStyle = AthenaTextStyle.body.copyWith(
      color: colors.textInput,
      height: 1.5,
    );
    var textField = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      scrollController: _scrollController,
      cursorHeight: 16,
      cursorColor: colors.textInput,
      decoration: inputDecoration,
      style: inputTextStyle,
      maxLines: 4,
      minLines: 1,
      onChanged: (_) => _scrollToCaret(),
      contextMenuBuilder: (context, editable) {
        void paste() {
          editable.hideToolbar();
          _pasteImageAware();
        }
        final items = editable.contextMenuButtonItems.map((item) =>
          item.type == ContextMenuButtonType.paste
              ? ContextMenuButtonItem(
                  type: ContextMenuButtonType.paste,
                  onPressed: paste,
                )
              : item,
        ).toList();
        // 纯图片剪贴板没有文本，默认菜单可能不提供 Paste。
        if (!items.any((item) => item.type == ContextMenuButtonType.paste)) {
          items.add(ContextMenuButtonItem(
            type: ContextMenuButtonType.paste,
            onPressed: paste,
          ));
        }
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editable.contextMenuAnchors,
          buttonItems: items,
        );
      },
    );
    var shortcuts = Shortcuts(
      shortcuts: const {
        _SendActivator(): _SendIntent(),
        _SendNumpadActivator(): _SendIntent(),
        _NewlineActivator(): _NewlineIntent(),
        _PasteMacActivator(): PasteTextIntent(SelectionChangedCause.keyboard),
        _PasteCtrlActivator(): PasteTextIntent(SelectionChangedCause.keyboard),
      },
      child: Actions(
        actions: {
          _SendIntent: CallbackAction<_SendIntent>(
            onInvoke: (_) {
              widget.onSubmitted?.call();
              return null;
            },
          ),
          _NewlineIntent: CallbackAction<_NewlineIntent>(
            onInvoke: (_) => _insertNewline(),
          ),
          // 使用标准粘贴 Intent，让其他系统粘贴入口也复用图片处理。
          PasteTextIntent: CallbackAction<PasteTextIntent>(
            onInvoke: (_) => _pasteImageAware(),
          ),
        },
        child: textField,
      ),
    );
    // 待发送图片属于输入内容，展示在输入框边框内部（文字上方）
    var content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.images.isNotEmpty) ...[
          _PendingImageStrip(
            images: widget.images,
            onRemoved: widget.onImageRemoved,
          ),
          const SizedBox(height: 10),
        ],
        shortcuts,
      ],
    );
    return Padding(
      // Claude 实测：占位符距容器左缘 10
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: content,
    );
  }

  void _insertNewline() {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final newText =
        '${text.substring(0, selection.start)}\n${text.substring(selection.end)}';
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + 1),
    );
    _scrollToCaret();
  }

  /// 多行输入超过可视高度时滚动到光标所在的最新一行
  /// （TextField 不会自动跟随光标，需在文本变化后手动滚动）。
  void _scrollToCaret() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent > 0) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  /// 图片感知粘贴：剪贴板中有图片时全部贴入待发送列表
  /// （文件管理器多选复制可能有多个图片文件），
  /// 否则回退到默认的文本粘贴行为。
  Future<void> _pasteImageAware() async {
    if (_pasting) return;
    _pasting = true;
    try {
      final pasted = await widget.onPasteImages?.call() ?? false;
      if (pasted || !mounted) return;
      await _pasteClipboardText();
    } finally {
      _pasting = false;
    }
  }

  Future<void> _pasteClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final controller = widget.controller;
    final value = controller.value;
    final selection = value.selection;
    // 无有效选区时在末尾追加，避免 substring 越界
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final newText = value.text.replaceRange(start, end, text);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _scrollToCaret();
  }
}

class _PendingImageStrip extends StatelessWidget {
  final List<PendingImage> images;
  final void Function(int)? onRemoved;
  const _PendingImageStrip({required this.images, this.onRemoved});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => KeyedSubtree(
          key: ObjectKey(images[index].id),
          child: _buildItem(context, index),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final pending = images[index];
    final image = !pending.isReady
        ? _ImageProgress(stage: pending.stage)
        : Image.memory(
            pending.bytes!,
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
            cacheWidth: 96,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return const _ImageProgress(stage: PendingImageStage.decoding);
            },
            errorBuilder: (context, error, stackTrace) =>
                const _ImageProgress(stage: PendingImageStage.failed),
          );
    var icon = Icon(
      LucideIcons.x,
      color: colors.textPrimary,
      size: 12,
    );
    var decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AthenaRadius.inline),
      color: colors.surfaceMobile,
    );
    var removeButton = Semantics(
      label: 'Remove image',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onRemoved?.call(index),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            decoration: decoration,
            padding: EdgeInsets.all(2),
            child: icon,
          ),
        ),
      ),
    );
    return SizedBox.square(
      dimension: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AthenaRadius.inline),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            Positioned(right: 2, top: 2, child: removeButton),
          ],
        ),
      ),
    );
  }
}

class _ImageProgress extends StatelessWidget {
  final PendingImageStage stage;
  const _ImageProgress({required this.stage});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final failed = stage == PendingImageStage.failed;
    return Tooltip(
      message: failed
          ? 'Could not load image. Remove it and paste again.'
          : 'Loading image',
      child: ColoredBox(
        color: colors.inputBackground,
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  failed ? LucideIcons.imageOff : LucideIcons.image,
                  size: 12,
                  color: failed ? colors.statusError : colors.textWeak,
                  semanticLabel: failed ? 'Could not load image' : null,
                ),
                if (!failed)
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                      semanticsLabel: 'Loading image',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasteMacActivator extends SingleActivator {
  const _PasteMacActivator()
    : super(LogicalKeyboardKey.keyV, meta: true, control: false);
}

class _PasteCtrlActivator extends SingleActivator {
  const _PasteCtrlActivator()
    : super(LogicalKeyboardKey.keyV, meta: false, control: true);
}

class _SendActivator extends SingleActivator {
  const _SendActivator()
    : super(
        LogicalKeyboardKey.enter,
        shift: false,
        control: false,
        alt: false,
        meta: false,
      );
}

class _SendNumpadActivator extends SingleActivator {
  const _SendNumpadActivator()
    : super(
        LogicalKeyboardKey.numpadEnter,
        shift: false,
        control: false,
        alt: false,
        meta: false,
      );
}

class _NewlineActivator extends SingleActivator {
  const _NewlineActivator() : super(LogicalKeyboardKey.enter, shift: true);
}

class _SendButton extends StatelessWidget {
  final void Function()? onSubmitted;
  final void Function()? onTerminated;
  const _SendButton({this.onSubmitted, this.onTerminated});
  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Watch((context) {
      final streaming = chatViewModel.isCurrentChatStreaming.value;
      final imagesReady = chatViewModel.pendingImages.value
          .every((image) => image.isReady);
      // Claude 的 ghost 按钮 hover 填充：前景色 5%
      final ghostHover = colors.textPrimary.withValues(alpha: 0.05);
      // 规格取自 Claude 的 CSS（`[data-cds=Button][data-cds-icon-only]`）：
      // 高宽同为"嵌套档"、圆角同心算出（各档 3–4）、ghost 无填充无描边。
      // 取 step4 档：22×22。按下缩放到 0.975 也是从 CSS 取的。
      return _SquishButton(
        onTap: streaming ? onTerminated : imagesReady ? onSubmitted : null,
        hoverFill: ghostHover,
        child: Container(
          alignment: Alignment.center,
          height: 22,
          width: 22,
          child: Icon(
            streaming
                ? LucideIcons.square
                : LucideIcons.arrowUp,
            color: streaming || imagesReady ? colors.accent : colors.textWeak,
            size: 16,
          ),
        ),
      );
    });
  }
}

/// 按压缩放按钮。
///
/// 取自 Claude 的 `.cds-btn-squish:active { transform: scale(.975) }`，
/// 过渡在按下时用快档（`--cds-dur-fast` ≈ 60ms）、回弹用慢档带弹簧。
class _SquishButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// hover 时的圆角填充。Claude 的 ghost 按钮是前景色 5%（暗色 7.5%）。
  /// 传 null 表示不做 hover 反馈。
  final Color? hoverFill;

  /// 填充与内容之间的内边距（文字类控件需要，纯图标不需要）。
  final EdgeInsetsGeometry padding;

  const _SquishButton({
    required this.child,
    this.onTap,
    this.hoverFill,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<_SquishButton> createState() => _SquishButtonState();
}

class _SquishButtonState extends State<_SquishButton> {
  bool _pressed = false;
  bool _hover = false;

  bool get _interactive => widget.onTap != null || widget.hoverFill != null;
  @override
  Widget build(BuildContext context) {
    Widget result = widget.hoverFill == null
        ? widget.child
        : DecoratedBox(
            decoration: BoxDecoration(
              color: _hover ? widget.hoverFill : Colors.transparent,
              borderRadius: BorderRadius.circular(AthenaRadius.xs),
            ),
            child: Padding(padding: widget.padding, child: widget.child),
          );
    result = AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: Duration(milliseconds: _pressed ? 60 : 200),
      curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
      child: result,
    );
    result = MouseRegion(
      cursor: _interactive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: result,
    );
    result = Listener(
      onPointerDown: (_) {
        if (_interactive) setState(() => _pressed = true);
      },
      onPointerUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onPointerCancel: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      child: result,
    );
    if (widget.onTap == null) return result;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: result,
    );
  }
}

/// composer 的输入容器。
///
/// Claude 实测：边框**常态 `#E1E1E0`（浅灰），聚焦后加深到 `#BFBFBE`**
/// （CSS 里对应 `focus:border-[...]` 效用类）。两个值都是中性灰，
/// 而本仓的 `border` / `borderStrong` 属暖灰系，白底上会偏黄，所以这里单独定义。
class _ComposerInputBox extends StatefulWidget {
  /// 外部持有的焦点节点：容器只监听它来切边框色，不负责 dispose。
  final FocusNode focusNode;
  final Widget Function(FocusNode focusNode) builder;
  const _ComposerInputBox({required this.focusNode, required this.builder});

  @override
  State<_ComposerInputBox> createState() => _ComposerInputBoxState();
}

class _ComposerInputBoxState extends State<_ComposerInputBox> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(_ComposerInputBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return AnimatedContainer(
      decoration: BoxDecoration(
        color: colors.surfaceMobile,
        border: Border.all(
          color: widget.focusNode.hasFocus
              ? colors.neutralBorderStrong
              : colors.neutralBorder,
        ),
        borderRadius: BorderRadius.circular(AthenaRadius.container),
        // Claude 实测：容器下方有一层很柔的投影——紧贴下边框处比画布暗约
        // 7/255，在约 18 逻辑内平滑衰减到 0，且上方几乎没有，所以是**向下偏移**
        // 的阴影，而不是第二条边框色。
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: widget.builder(widget.focusNode),
    );
  }
}
