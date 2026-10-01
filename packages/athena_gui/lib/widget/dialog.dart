import 'dart:async';

import 'package:athena_gui/router/router.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum AthenaMessageType { info, success, warning, error }

abstract final class AthenaDialog {
  static OverlayEntry? _messageOverlay;
  static Timer? _messageTimer;

  /// 静态方法取色：通过全局导航 context 获取当前主题扩展。
  static AthenaColors get _colors =>
      Theme.of(router.navigatorKey.currentContext!).extension<AthenaColors>()!;

  /// 移动端判定走 `ThemeData.platform` 而不是 `PlatformUtil`。
  ///
  /// 理由与 [AthenaScrollBehavior] 相同、也与 [PermissionApprovalCard] /
  /// [ElicitCard] 现在的做法一致：`PlatformUtil` 读 `dart:io` 的 `Platform`，
  /// 在 widget 测试里恒为宿主平台，**移动端的分支根本进不去**；而
  /// `ThemeData.platform` 可以在测试里用 `theme.copyWith(platform:)` 指定，
  /// 两端才都能断言。生产环境不显式设置 `ThemeData.platform`，
  /// 它由 `defaultTargetPlatform` 填充，与 `PlatformUtil` 同源。
  static bool _isMobile(BuildContext context) {
    var platform = Theme.of(context).platform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  static Future<bool?> confirm(String text, {bool dismissible = true}) async {
    final context = router.navigatorKey.currentContext!;
    if (_isMobile(context)) {
      // 打开弹窗前释放焦点,否则弹窗关闭后焦点会回落到之前的
      // 输入框,导致键盘自动弹出。
      FocusManager.instance.primaryFocus?.unfocus();
      return showModalBottomSheet<bool>(
        backgroundColor: _colors.surfaceMobile,
        isDismissible: dismissible,
        enableDrag: dismissible,
        builder: (_) => _ConfirmDialog(text: text),
        context: context,
      );
    }
    return showDialog<bool>(
      barrierDismissible: dismissible,
      builder: (_) => _DesktopConfirmDialog(title: 'Confirm', message: text),
      context: context,
    );
  }

  static Future<String?> input(String title, {String? initialValue}) async {
    final context = router.navigatorKey.currentContext!;
    if (_isMobile(context)) {
      // 打开弹窗前释放焦点,防止关闭弹窗后焦点回落到输入框导致
      // 键盘自动弹出;弹窗内的输入框自身会重新申请焦点。
      FocusManager.instance.primaryFocus?.unfocus();
      return showModalBottomSheet<String>(
        backgroundColor: _colors.surfaceMobile,
        isScrollControlled: true,
        builder: (_) => _InputDialog(title: title, initialValue: initialValue),
        context: context,
      );
    }
    return showDialog<String>(
      builder: (_) =>
          _DesktopInputDialog(title: title, initialValue: initialValue),
      context: context,
    );
  }

  static void dismiss() {
    Navigator.of(router.navigatorKey.currentContext!).pop();
  }

  static void loading() {
    showDialog<void>(
      barrierDismissible: false,
      context: router.navigatorKey.currentContext!,
      builder: (context) => const _DesktopLoadingDialog(),
    );
  }

  static void message(
    String message, {
    AthenaMessageType type = AthenaMessageType.info,
  }) {
    if (!_isMobile(router.navigatorKey.currentContext!)) {
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
        Icon(
          style.icon,
          color: style.accentColor,
          size: AthenaIcon.regularSize,
        ),
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
    final context = router.navigatorKey.currentContext!;
    if (_isMobile(context)) {
      // 打开弹窗前释放焦点,否则弹窗关闭后焦点会回落到之前的
      // 输入框,导致键盘自动弹出。
      FocusManager.instance.primaryFocus?.unfocus();
      showModalBottomSheet<void>(
        backgroundColor: _colors.surfaceMobile,
        builder: (_) => child,
        context: context,
      );
      return;
    }
    showDialog<void>(
      barrierDismissible: barrierDismissible,
      builder: (_) => child,
      context: context,
    );
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
    _messageTimer = Timer(AthenaMotion.linger, _dismissDesktopMessage);
  }
}

/// 桌面对话框外壳（DESIGN.md §7 Desktop Dialog）。
///
/// `surfaceMobile` 底 + [AthenaRadius.panel] 圆角 + [AthenaShadow.modal]，
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
                AthenaGhostIconButton(icon: LucideIcons.x, onTap: onClose),
            ],
          );
    var children = [
      if (header != null) header,
      if (header != null) const SizedBox(height: AthenaSpace.lg),
      child,
    ];
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 520),
        decoration: BoxDecoration(
          color: colors.surfaceMobile,
          borderRadius: BorderRadius.circular(AthenaRadius.panel),
          boxShadow: AthenaShadow.modal(colors.shadow),
        ),
        foregroundDecoration: Theme.of(context).brightness == Brightness.dark
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AthenaRadius.panel),
                border: Border.all(color: colors.border),
              )
            : null,
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

/// 桌面对话框底部的按钮行：次要在左、主操作在最右，右对齐、间距 8。
///
/// 确认、输入与各设置表单的模态共用这一行，不要再各自拼 `Row`。
class AthenaDialogActions extends StatelessWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String cancelLabel;
  final String confirmLabel;

  const AthenaDialogActions({
    super.key,
    this.onCancel,
    this.onConfirm,
    this.cancelLabel = 'Cancel',
    this.confirmLabel = 'Confirm',
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      AthenaSecondaryButton(onTap: onCancel, child: Text(cancelLabel)),
      const SizedBox(width: AthenaSpace.sm),
      AthenaPrimaryButton(onTap: onConfirm, child: Text(confirmLabel)),
    ];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
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
        icon: AthenaIcons.error,
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
      AthenaPrimaryButton(
        onTap: () =>
            Navigator.of(router.navigatorKey.currentContext!).pop(true),
        child: const Center(child: Text('Confirm')),
      ),
      const SizedBox(height: AthenaSpace.sm),
      AthenaSecondaryButton(
        onTap: () =>
            Navigator.of(router.navigatorKey.currentContext!).pop(false),
        child: const Center(child: Text('Cancel')),
      ),
      SizedBox(height: MediaQuery.paddingOf(context).bottom),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
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
    );
    var children = [
      Text(message, style: messageStyle),
      const SizedBox(height: AthenaSpace.xxl),
      AthenaDialogActions(
        onCancel: () => Navigator.of(context).maybePop(false),
        onConfirm: () => Navigator.of(context).maybePop(true),
      ),
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
      AthenaDialogActions(
        onCancel: () => Navigator.of(context).maybePop(null),
        onConfirm: () => Navigator.of(context).maybePop(controller.text.trim()),
      ),
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
      AthenaPrimaryButton(
        onTap: () => Navigator.of(context).maybePop(controller.text.trim()),
        child: const Center(child: Text('Confirm')),
      ),
      const SizedBox(height: AthenaSpace.sm),
      AthenaSecondaryButton(
        onTap: () => Navigator.of(context).maybePop(null),
        child: const Center(child: Text('Cancel')),
      ),
      SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
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
        borderRadius: BorderRadius.circular(AthenaRadius.container),
        boxShadow: AthenaShadow.overlay(colors.shadow),
      ),
      foregroundDecoration: Theme.of(context).brightness == Brightness.dark
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AthenaRadius.container),
              border: Border.all(color: colors.border),
            )
          : null,
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
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final children = [
      Icon(style.icon, color: style.accentColor, size: AthenaIcon.regularSize),
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
