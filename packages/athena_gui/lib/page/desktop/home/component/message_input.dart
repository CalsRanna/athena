import 'dart:io';

import 'package:athena_gui/page/desktop/home/component/configuration_button.dart';
import 'package:athena_gui/page/desktop/home/component/image_selector.dart';
import 'package:athena_gui/page/desktop/home/component/reasoning_effort_button.dart';
import 'package:athena_gui/page/desktop/home/component/token_indicator.dart';
import 'package:athena_gui/theme/athena_colors.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Watch((context) {
      var chat = chatViewModel.currentChat.value;
      var toolbarChildren = [
        DesktopConfigurationButton(
          chat: chat,
          currentRetention: chatViewModel.currentRetention.value,
          currentTemperature: chatViewModel.currentTemperature.value,
          onRetentionChange: onRetentionChange,
          onTemperatureChange: onTemperatureChange,
        ),
        DesktopImageSelector(onSelected: onImageSelected),
        DesktopReasoningEffortButton(
          current: chatViewModel.currentReasoningEffort.value,
          onSelected: onReasoningEffortChange,
        ),
        const Spacer(),
        const DesktopTokenIndicator(),
      ];
      var toolbar = Row(spacing: 12, children: toolbarChildren);
      var input = _Input(
        controller: controller,
        images: chatViewModel.pendingImages.value,
        onImagePasted: onImagePasted,
        onImageRemoved: onImageRemoved,
        onSubmitted: onSubmitted,
      );
      var inputChildren = [
        Expanded(child: input),
        const SizedBox(width: 8),
        _SendButton(onSubmitted: onSubmitted, onTerminated: onTerminated),
      ];
      var inputRow = Row(children: inputChildren);
      var borderSide = BorderSide(
        color: colors.borderFaint.withValues(alpha: 0.2),
      );
      var children = [toolbar, const SizedBox(height: 12), inputRow];
      return Container(
        decoration: BoxDecoration(border: Border(top: borderSide)),
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Column(children: children),
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
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var boxDecoration = BoxDecoration(
      border: Border.all(color: colors.borderStrong),
      borderRadius: BorderRadius.circular(24),
      color: colors.inputBackground.withValues(alpha: 0.6),
    );
    var hintTextStyle = TextStyle(
      color: colors.border,
      fontSize: 14,
      height: 1.5,
    );
    var inputDecoration = InputDecoration.collapsed(
      hintText: 'Ask me anything',
      hintStyle: hintTextStyle,
    );
    final inputTextStyle = TextStyle(
      color: colors.textInput,
      fontSize: 14,
      height: 1.5,
    );
    var textField = TextField(
      controller: widget.controller,
      cursorHeight: 16,
      cursorColor: colors.textInput,
      decoration: inputDecoration,
      style: inputTextStyle,
      maxLines: 4,
      minLines: 1,
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
    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15.5),
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
      shape: BoxShape.circle,
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
        borderRadius: BorderRadius.circular(12),
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
    var gradientColors = [
      colors.tagBorderStart.withValues(alpha: 0.17),
      Colors.transparent,
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.centerLeft,
      colors: gradientColors,
      end: Alignment.centerRight,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(55),
      gradient: linearGradient,
    );
    var boxShadow = BoxShadow(
      blurRadius: 16,
      color: colors.ctaGlow.withValues(alpha: 0.5),
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(55),
      color: colors.surfaceRaised,
      boxShadow: [boxShadow],
    );

    return Watch((context) {
      // 仅当"当前显示的对话"正在流式时才显示 Stop；
      // 切到其他对话时恢复发送按钮（后台任务不受影响）
      var streaming = chatViewModel.isCurrentChatStreaming.value;
      var iconData = HugeIcons.strokeRoundedSent;
      if (streaming) iconData = HugeIcons.strokeRoundedStop;
      var innerContainer = Container(
        decoration: innerBoxDecoration,
        child: Icon(iconData, color: colors.iconOnRaised),
      );
      var outerContainer = Container(
        decoration: boxDecoration,
        height: 55,
        padding: EdgeInsets.all(1),
        width: 55,
        child: innerContainer,
      );
      var mouseRegion = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: outerContainer,
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => handleTap(streaming),
        child: mouseRegion,
      );
    });
  }

  void handleTap(bool streaming) {
    if (!streaming) {
      onSubmitted?.call();
      return;
    }
    onTerminated?.call();
  }
}
