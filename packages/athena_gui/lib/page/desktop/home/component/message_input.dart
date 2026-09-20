import 'dart:io';

import 'package:athena_gui/component/chat_column.dart';
import 'package:athena_gui/component/queued_messages.dart';
import 'package:athena_gui/page/desktop/home/component/configuration_button.dart';
import 'package:athena_gui/page/desktop/home/component/image_selector.dart';
import 'package:athena_gui/page/desktop/home/component/model_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/reasoning_effort_button.dart';
import 'package:athena_gui/page/desktop/home/component/token_indicator.dart';
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
  final void Function()? onModelTap;
  final void Function()? onSentinelTap;
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
  });
  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Watch((context) {
      final chat = chatViewModel.currentChat.value;
      final queued = chatViewModel.queuedMessages.value;
      // 版式取自 **Claude 桌面端**（这一处刻意不跟 Codex）：
      // 上面一条灰色上下文条、下面一个白底描边的输入框，两者是**独立的圆角容器**；
      // 权限/工具与模型/发送则在两个容器**外面**单独排一行。
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
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
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: colors.surfaceButtonSecondary,
                    borderRadius: BorderRadius.circular(AthenaRadius.container),
                  ),
                  child: DesktopSentinelIndicator(onTap: onSentinelTap),
                ),
                const SizedBox(height: 6),
                // 输入容器：白底 + 1px 描边
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(AthenaRadius.container),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: _Input(
                    controller: controller,
                    images: chatViewModel.pendingImages.value,
                    onImagePasted: onImagePasted,
                    onImageRemoved: onImageRemoved,
                    onSubmitted: onSubmitted,
                  ),
                ),
                const SizedBox(height: 6),
                // 容器之外的一行
                Row(
                  children: [
                    DesktopConfigurationButton(
                      chat: chat,
                      currentRetention: chatViewModel.currentRetention.value,
                      currentTemperature:
                          chatViewModel.currentTemperature.value,
                      onRetentionChange: onRetentionChange,
                      onTemperatureChange: onTemperatureChange,
                    ),
                    const SizedBox(width: 4),
                    DesktopImageSelector(onSelected: onImageSelected),
                    const Spacer(),
                    DesktopModelIndicator(onTap: onModelTap),
                    const SizedBox(width: 4),
                    DesktopReasoningEffortButton(
                      current: chatViewModel.currentReasoningEffort.value,
                      onSelected: onReasoningEffortChange,
                    ),
                    const SizedBox(width: 4),
                    const DesktopTokenIndicator(),
                    const SizedBox(width: 8),
                    _SendButton(
                      onSubmitted: onSubmitted,
                      onTerminated: onTerminated,
                    ),
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
  final List<String> images;
  final void Function(String)? onImagePasted;
  final void Function(int)? onImageRemoved;
  final void Function()? onSubmitted;
  const _Input({
    required this.controller,
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
    var hintTextStyle = TextStyle(
      color: colors.textSecondary,
      fontSize: AthenaFontSize.body,
      height: 1.5,
    );
    var inputDecoration = InputDecoration.collapsed(
      hintText: 'Ask me anything',
      hintStyle: hintTextStyle,
    );
    final inputTextStyle = TextStyle(
      color: colors.textInput,
      fontSize: AthenaFontSize.body,
      height: 1.5,
    );
    var textField = TextField(
      controller: widget.controller,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    // 与 Codex 的主操作一致：全局唯一那抹蓝（accent）的胶囊按钮。
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AthenaRadius.pill),
      color: colors.accent,
    );

    return Watch((context) {
      // 流式时按钮切换为 Stop；回车仍通过 onSubmitted 排队发送。
      var streaming = chatViewModel.isCurrentChatStreaming.value;
      Widget roundButton(IconData icon, VoidCallback? onTap) {
        var outerContainer = Container(
          alignment: Alignment.center,
          decoration: boxDecoration,
          height: 28,
          width: 28,
          child: Icon(icon, color: Colors.white, size: 16),
        );
        var mouseRegion = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: outerContainer,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: mouseRegion,
        );
      }

      return roundButton(
        streaming ? HugeIcons.strokeRoundedStop : HugeIcons.strokeRoundedSent,
        streaming ? onTerminated : onSubmitted,
      );
    });
  }
}
