import 'dart:io';

import 'package:athena_gui/component/chat_column.dart';
import 'package:athena_gui/component/queued_messages.dart';
import 'package:athena_gui/page/desktop/home/component/configuration_button.dart';
import 'package:athena_gui/page/desktop/home/component/image_selector.dart';
import 'package:athena_gui/page/desktop/home/component/model_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/permission_mode_selector.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/reasoning_effort_button.dart';
import 'package:athena_gui/page/desktop/home/component/token_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/workspace_indicator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/clipboard_image_service.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopMessageInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function(int)? onRetentionChange;
  final void Function(List<String>)? onImageSelected;
  final void Function(String)? onImagePasted;
  final void Function(int)? onImageRemoved;
  final void Function()? onSubmitted;
  final void Function(double)? onTemperatureChange;
  final void Function(String?)? onReasoningEffortChange;
  final void Function()? onTerminated;

  /// 点击模型名：回传那一块（含 hover 填充）的全局矩形，模型菜单锚在它上方。
  final void Function(Rect anchor)? onModelTap;
  final void Function()? onSentinelTap;

  /// 清除本会话的 Sentinel（回到「不选择任何 Sentinel」）。
  final void Function()? onSentinelClear;

  /// 选择/清除本会话的工作文件夹（目录选择器在 ViewModel 层弹）。
  final void Function()? onWorkspaceTap;
  final void Function()? onWorkspaceClear;
  const DesktopMessageInput({
    super.key,
    required this.controller,
    this.onRetentionChange,
    this.onImageSelected,
    this.onImagePasted,
    this.onImageRemoved,
    this.onSubmitted,
    this.onTemperatureChange,
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
      final chat = chatViewModel.currentChat.value;
      final queued = chatViewModel.queuedMessages.value;
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
                      DesktopWorkspaceIndicator(
                        path: chat?.workspacePath,
                        onTap: chat == null ? null : onWorkspaceTap,
                        onClear: chat == null ? null : onWorkspaceClear,
                      ),
                      const Spacer(),
                      // 会话配置（上下文保留 / 温度）从容器外那一行挪到
                      // 上下文条最右，与左边两个 chip 同一种形态
                      DesktopConfigurationButton.chip(
                        chat: chat,
                        currentRetention: chatViewModel.currentRetention.value,
                        currentTemperature:
                            chatViewModel.currentTemperature.value,
                        onRetentionChange: onRetentionChange,
                        onTemperatureChange: onTemperatureChange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                // 输入容器：白底（surfaceMobile 是纯白那档）+ 1px 描边
                _ComposerInputBox(
                  builder: (focusNode) => Row(
                    children: [
                      Expanded(
                        child: _Input(
                          controller: controller,
                          focusNode: focusNode,
                          images: chatViewModel.pendingImages.value,
                          onImagePasted: onImagePasted,
                          onImageRemoved: onImageRemoved,
                          onSubmitted: onSubmitted,
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
                          _globalRect(context),
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
                        onTap: () => onModelTap?.call(_globalRect(context)),
                        child: const DesktopModelIndicator(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _SquishButton(
                      hoverFill: ghostHover,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: DesktopReasoningEffortButton(
                        current: chatViewModel.currentReasoningEffort.value,
                        onSelected: onReasoningEffortChange,
                      ),
                    ),
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

  /// 外部传入的焦点节点：composer 的容器要靠它切换边框色。
  final FocusNode? focusNode;
  final List<String> images;
  final void Function(String)? onImagePasted;
  final void Function(int)? onImageRemoved;
  final void Function()? onSubmitted;
  const _Input({
    required this.controller,
    this.focusNode,
    this.images = const [],
    this.onImagePasted,
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

class _PasteIntent extends Intent {
  const _PasteIntent();
}

class _InputState extends State<_Input> {
  bool _pasting = false;
  final _scrollController = ScrollController();

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
    );
    var shortcuts = Shortcuts(
      shortcuts: const {
        _SendActivator(): _SendIntent(),
        _SendNumpadActivator(): _SendIntent(),
        _NewlineActivator(): _NewlineIntent(),
        _PasteMacActivator(): _PasteIntent(),
        _PasteCtrlActivator(): _PasteIntent(),
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
          _PasteIntent: CallbackAction<_PasteIntent>(
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
    var pasted = false;
    try {
      // 文件路径先回调（占位立即出现），转换数据逐张回填
      await ClipboardImageService.readClipboardImages((path) {
        pasted = true;
        widget.onImagePasted?.call(path);
      });
      if (pasted) return;
      await _pasteClipboardText();
    } finally {
      _pasting = false;
    }
  }

  Future<void> _pasteClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
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
  final List<String> images;
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
        itemBuilder: (context, index) => _buildItem(context, index),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 缩略图只按 2x 显示尺寸解码（48x48 ≈ 96），避免大图全尺寸解码卡顿；
    // frameBuilder 在图片数据就绪前渲染占位底色，避免整块空白后突然弹出
    var image = Image.file(
      File(images[index]),
      fit: BoxFit.cover,
      height: double.infinity,
      width: double.infinity,
      cacheWidth: 96,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return ColoredBox(
          color: colors.inputBackground,
          child: Center(
            child: Icon(
              HugeIcons.strokeRoundedImage01,
              color: colors.border,
              size: 16,
            ),
          ),
        );
      },
    );
    var icon = Icon(
      HugeIcons.strokeRoundedCancel01,
      color: colors.textPrimary,
      size: 12,
    );
    var decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AthenaRadius.inline),
      color: colors.surfaceMobile,
    );
    var removeButton = GestureDetector(
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
      // Claude 的 ghost 按钮 hover 填充：前景色 5%
      final ghostHover = colors.textPrimary.withValues(alpha: 0.05);
      // 规格取自 Claude 的 CSS（`[data-cds=Button][data-cds-icon-only]`）：
      // 高宽同为"嵌套档"、圆角同心算出（各档 3–4）、ghost 无填充无描边。
      // 取 step4 档：22×22。按下缩放到 0.975 也是从 CSS 取的。
      return _SquishButton(
        onTap: streaming ? onTerminated : onSubmitted,
        hoverFill: ghostHover,
        child: Container(
          alignment: Alignment.center,
          height: 22,
          width: 22,
          child: Icon(
            streaming
                ? HugeIcons.strokeRoundedStop
                : HugeIcons.strokeRoundedSent,
            color: colors.accent,
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
  final Widget Function(FocusNode focusNode) builder;
  const _ComposerInputBox({required this.builder});

  @override
  State<_ComposerInputBox> createState() => _ComposerInputBoxState();
}

class _ComposerInputBoxState extends State<_ComposerInputBox> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
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
          color: _focusNode.hasFocus
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
      child: widget.builder(_focusNode),
    );
  }
}

/// [context] 对应控件的全局矩形，供弹出菜单锚定。
Rect _globalRect(BuildContext context) {
  final box = context.findRenderObject() as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}
