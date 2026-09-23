import 'dart:async';

import 'package:athena_core/util/platform_util.dart';

import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum AthenaMessageType { info, success, warning, error }

class AthenaDialog {
  static OverlayEntry? _messageOverlay;
  static Timer? _messageTimer;

  /// 静态方法取色：通过全局导航 context 获取当前主题扩展。
  static AthenaColors get _colors =>
      Theme.of(router.navigatorKey.currentContext!).extension<AthenaColors>()!;

  static Future<bool?> confirm(String text, {bool dismissible = true}) async {
    if (PlatformUtil.isDesktop) {
      return showDialog<bool>(
        barrierDismissible: dismissible,
        builder: (_) => _DesktopConfirmDialog(title: 'Confirm', message: text),
        context: router.navigatorKey.currentContext!,
      );
    } else {
      // 打开弹窗前释放焦点,否则弹窗关闭后焦点会回落到之前的
      // 输入框,导致键盘自动弹出。
      FocusManager.instance.primaryFocus?.unfocus();
      return showModalBottomSheet<bool>(
        backgroundColor: _colors.surfaceMobile,
        isDismissible: dismissible,
        enableDrag: dismissible,
        builder: (_) => _ConfirmDialog(text: text),
        context: router.navigatorKey.currentContext!,
      );
    }
  }

  static Future<String?> input(String title, {String? initialValue}) async {
    if (PlatformUtil.isDesktop) {
      return showDialog<String>(
        builder: (_) =>
            _DesktopInputDialog(title: title, initialValue: initialValue),
        context: router.navigatorKey.currentContext!,
      );
    } else {
      // 打开弹窗前释放焦点,防止关闭弹窗后焦点回落到输入框导致
      // 键盘自动弹出;弹窗内的输入框自身会重新申请焦点。
      FocusManager.instance.primaryFocus?.unfocus();
      return showModalBottomSheet<String>(
        backgroundColor: _colors.surfaceMobile,
        isScrollControlled: true,
        builder: (_) => _InputDialog(title: title, initialValue: initialValue),
        context: router.navigatorKey.currentContext!,
      );
    }
  }

  static void dismiss() {
    Navigator.of(router.navigatorKey.currentContext!).pop();
  }

  static void loading() {
    showDialog(
      barrierDismissible: false,
      context: router.navigatorKey.currentContext!,
      builder: (context) => const _DesktopLoadingDialog(),
    );
  }

  static void message(
    String message, {
    AthenaMessageType type = AthenaMessageType.info,
  }) {
    var isWindow = PlatformUtil.isDesktop;
    if (isWindow) {
      _showDesktopMessage(message, type: type);
      return;
    }
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final style = _AthenaMessageVisualStyle.fromType(type, _colors);
    var textStyle = TextStyle(color: _colors.textPrimary);
    var content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(style.icon, color: style.accentColor, size: 16),
        const SizedBox(width: 8),
        Flexible(child: Text(message, style: textStyle)),
      ],
    );
    var snackBar = SnackBar(
      backgroundColor: _colors.surfaceMobile,
      behavior: SnackBarBehavior.floating,
      content: content,
    );
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(snackBar);
  }

  static void show(Widget child, {bool barrierDismissible = false}) {
    if (PlatformUtil.isDesktop) {
      showDialog(
        barrierDismissible: barrierDismissible,
        builder: (_) => child,
        context: router.navigatorKey.currentContext!,
      );
    } else {
      // 打开弹窗前释放焦点,否则弹窗关闭后焦点会回落到之前的
      // 输入框,导致键盘自动弹出。
      FocusManager.instance.primaryFocus?.unfocus();
      showModalBottomSheet(
        backgroundColor: _colors.surfaceMobile,
        builder: (_) => child,
        context: router.navigatorKey.currentContext!,
      );
    }
  }

  static void info(String message) {
    AthenaDialog.message(message, type: AthenaMessageType.info);
  }

  static void success(String message) {
    AthenaDialog.message(message, type: AthenaMessageType.success);
  }

  static void warning(String message) {
    AthenaDialog.message(message, type: AthenaMessageType.warning);
  }

  static void error(String message) {
    AthenaDialog.message(message, type: AthenaMessageType.error);
  }

  static void _dismissDesktopMessage() {
    _messageTimer?.cancel();
    _messageTimer = null;
    _messageOverlay?.remove();
    _messageOverlay = null;
  }

  static void _showDesktopMessage(
    String message, {
    AthenaMessageType type = AthenaMessageType.info,
  }) {
    final overlay = router.navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _dismissDesktopMessage();
    final entry = OverlayEntry(
      builder: (context) =>
          _DesktopMessageOverlay(message: message, type: type),
    );
    overlay.insert(entry);
    _messageOverlay = entry;
    _messageTimer = Timer(const Duration(seconds: 3), _dismissDesktopMessage);
  }
}

/// 桌面对话框外壳（DESIGN.md §4 Desktop Dialog）。
///
/// `surfaceMobile` 底 + [AthenaRadius.panel] 圆角 + [AthenaShadow.overlay]，
/// 内边距 24，宽 320–520。给 [title] 就渲染标题行（[AthenaTextStyle.title]），
/// 再给 [onClose] 会在标题行右端放一个 ghost 关闭键。
///
/// 所有桌面模态（确认、输入、设置里的表单）都从这里派生，不要再各自画容器。
class AthenaDesktopDialog extends StatelessWidget {
  final String? title;
  final VoidCallback? onClose;
  final Widget child;

  const AthenaDesktopDialog({
    super.key,
    this.title,
    this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var header = title == null
        ? null
        : Row(
            children: [
              Expanded(
                child: Text(
                  title!,
                  style: AthenaTextStyle.title.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (onClose != null)
                AthenaGhostIconButton(
                  icon: LucideIcons.x,
                  onTap: onClose,
                ),
            ],
          );
    var children = [
      if (header != null) header,
      if (header != null) const SizedBox(height: AthenaSpace.lg),
      child,
    ];
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 520),
        decoration: BoxDecoration(
          color: colors.surfaceMobile,
          borderRadius: BorderRadius.circular(AthenaRadius.panel),
          boxShadow: AthenaShadow.overlay(colors.shadow),
        ),
        padding: const EdgeInsets.all(AthenaSpace.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _AthenaMessageVisualStyle {
  final Color accentColor;
  final IconData icon;

  const _AthenaMessageVisualStyle({
    required this.accentColor,
    required this.icon,
  });

  factory _AthenaMessageVisualStyle.fromType(
    AthenaMessageType type,
    AthenaColors colors,
  ) {
    return switch (type) {
      AthenaMessageType.info => _AthenaMessageVisualStyle(
        accentColor: colors.textSecondary,
        icon: LucideIcons.info,
      ),
      AthenaMessageType.success => _AthenaMessageVisualStyle(
        accentColor: colors.statusSuccess,
        icon: LucideIcons.check,
      ),
      AthenaMessageType.warning => _AthenaMessageVisualStyle(
        accentColor: colors.statusWarning,
        icon: LucideIcons.triangleAlert,
      ),
      AthenaMessageType.error => _AthenaMessageVisualStyle(
        accentColor: colors.statusError,
        icon: LucideIcons.circleX,
      ),
    };
  }
}

/// 移动端底部 sheet 内的确认面板：主/次按钮都是全宽矩形。
class _ConfirmDialog extends StatelessWidget {
  final String text;
  const _ConfirmDialog({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = AthenaTextStyle.title.copyWith(color: colors.textPrimary);
    var children = [
      Text(text, style: textStyle),
      const SizedBox(height: AthenaSpace.xxl),
      _buildConfirmButton(context),
      const SizedBox(height: AthenaSpace.sm),
      _buildCancelButton(context),
      SizedBox(height: MediaQuery.paddingOf(context).bottom),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void cancelDialog() {
    Navigator.of(router.navigatorKey.currentContext!).pop(false);
  }

  void confirmDialog(BuildContext context) {
    Navigator.of(router.navigatorKey.currentContext!).pop(true);
  }

  Widget _buildCancelButton(BuildContext context) {
    var container = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).extension<AthenaColors>()!.border,
        ),
        borderRadius: BorderRadius.circular(AthenaRadius.control),
      ),
      padding: const EdgeInsets.all(14),
      child: Text(
        'Cancel',
        style: AthenaTextStyle.label.copyWith(
          color: Theme.of(context).extension<AthenaColors>()!.textPrimary,
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: cancelDialog,
      child: container,
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => confirmDialog(context),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AthenaRadius.control),
        ),
        padding: const EdgeInsets.all(14),
        child: Text(
          'Confirm',
          style: AthenaTextStyle.label.copyWith(
            color: colors.textOnRaised,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DesktopConfirmDialog extends StatelessWidget {
  final String title;
  final String message;

  const _DesktopConfirmDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var messageStyle = AthenaTextStyle.body.copyWith(
      color: colors.textSecondary,
      height: 1.6,
    );
    var children = [
      Text(message, style: messageStyle),
      const SizedBox(height: AthenaSpace.xxl),
      _buildButtons(context),
    ];
    return AthenaDesktopDialog(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    var cancelButton = AthenaSecondaryButton(
      onTap: () => Navigator.of(context).maybePop(false),
      child: const Text('Cancel'),
    );
    var confirmButton = AthenaPrimaryButton(
      onTap: () => Navigator.of(context).maybePop(true),
      child: const Text('Confirm'),
    );
    var children = [
      cancelButton,
      const SizedBox(width: AthenaSpace.sm),
      confirmButton,
    ];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
  }
}

class _DesktopInputDialog extends StatefulWidget {
  final String title;
  final String? initialValue;

  const _DesktopInputDialog({required this.title, this.initialValue});

  @override
  State<_DesktopInputDialog> createState() => _DesktopInputDialogState();
}

class _DesktopInputDialogState extends State<_DesktopInputDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var children = [
      AthenaInput(controller: controller, autoFocus: true),
      const SizedBox(height: AthenaSpace.xxl),
      _buildButtons(context),
    ];
    return AthenaDesktopDialog(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    var cancelButton = AthenaSecondaryButton(
      onTap: () => Navigator.of(context).maybePop(null),
      child: const Text('Cancel'),
    );
    var confirmButton = AthenaPrimaryButton(
      onTap: _submit,
      child: const Text('Confirm'),
    );
    var children = [
      cancelButton,
      const SizedBox(width: AthenaSpace.sm),
      confirmButton,
    ];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
  }

  void _submit() {
    Navigator.of(context).maybePop(controller.text.trim());
  }
}

class _InputDialog extends StatefulWidget {
  final String title;
  final String? initialValue;

  const _InputDialog({required this.title, this.initialValue});

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var titleStyle = AthenaTextStyle.title.copyWith(color: colors.textPrimary);
    var input = AthenaInput(controller: controller, autoFocus: true);
    var children = [
      Text(widget.title, style: titleStyle),
      const SizedBox(height: AthenaSpace.lg),
      input,
      const SizedBox(height: AthenaSpace.xxl),
      _buildConfirmButton(context),
      const SizedBox(height: AthenaSpace.sm),
      _buildCancelButton(context),
      SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var container = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AthenaRadius.control),
      ),
      padding: const EdgeInsets.all(14),
      child: Text(
        'Cancel',
        style: AthenaTextStyle.label.copyWith(color: colors.textPrimary),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(null),
      child: container,
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(controller.text.trim()),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AthenaRadius.control),
        ),
        padding: const EdgeInsets.all(14),
        child: Text(
          'Confirm',
          style: AthenaTextStyle.label.copyWith(
            color: colors.textOnRaised,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DesktopLoadingDialog extends StatelessWidget {
  const _DesktopLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final indicator = SizedBox(
      height: 16,
      width: 16,
      child: CircularProgressIndicator(
        color: colors.textPrimary,
        strokeWidth: 2,
      ),
    );
    final textStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
    );
    final children = [
      indicator,
      const SizedBox(width: 10),
      Text('Loading...', style: textStyle),
    ];
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
    final container = Container(
      decoration: BoxDecoration(
        color: colors.surfaceMobile,
        borderRadius: BorderRadius.circular(AthenaRadius.panel),
        boxShadow: AthenaShadow.overlay(colors.shadow),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: row,
    );
    return Material(
      type: MaterialType.transparency,
      child: Center(child: container),
    );
  }
}

class _DesktopMessageOverlay extends StatelessWidget {
  final String message;
  final AthenaMessageType type;
  const _DesktopMessageOverlay({
    required this.message,
    this.type = AthenaMessageType.info,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final style = _AthenaMessageVisualStyle.fromType(type, colors);
    final textStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
      height: 1.5,
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final children = [
      Icon(style.icon, color: style.accentColor, size: 16),
      const SizedBox(width: 8),
      Flexible(child: Text(message, style: textStyle)),
    ];
    final container = Container(
      constraints: BoxConstraints(maxWidth: screenWidth - 32),
      decoration: BoxDecoration(
        color: colors.surfaceMobile,
        border: Border.all(color: style.accentColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AthenaRadius.container),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(padding: const EdgeInsets.all(16), child: container),
          ),
        ),
      ),
    );
  }
}
