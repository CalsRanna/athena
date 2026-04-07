import 'dart:async';
import 'dart:io';

import 'package:athena/router/router.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

enum AthenaMessageType { info, success, warning, error }

class AthenaDialog {
  static OverlayEntry? _messageOverlay;
  static Timer? _messageTimer;

  static Future<bool?> confirm(String text) async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return showDialog<bool>(
        builder: (_) => _DesktopConfirmDialog(title: 'Confirm', message: text),
        context: router.navigatorKey.currentContext!,
      );
    } else {
      return showModalBottomSheet<bool>(
        backgroundColor: ColorUtil.FF282F32,
        builder: (_) => _ConfirmDialog(text: text),
        context: router.navigatorKey.currentContext!,
      );
    }
  }

  static Future<String?> input(String title, {String? initialValue}) async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return showDialog<String>(
        builder: (_) =>
            _DesktopInputDialog(title: title, initialValue: initialValue),
        context: router.navigatorKey.currentContext!,
      );
    } else {
      return showModalBottomSheet<String>(
        backgroundColor: ColorUtil.FF282F32,
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
    var isWindow = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    if (isWindow) {
      _showDesktopMessage(message, type: type);
      return;
    }
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final style = _AthenaMessageVisualStyle.fromType(type);
    var textStyle = const TextStyle(color: ColorUtil.FFFFFFFF);
    var content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(style.icon, color: style.accentColor, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(message, style: textStyle)),
      ],
    );
    var snackBar = SnackBar(
      backgroundColor: ColorUtil.FF282F32,
      behavior: SnackBarBehavior.floating,
      content: content,
    );
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(snackBar);
  }

  static void show(Widget child, {bool barrierDismissible = false}) {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      showDialog(
        barrierDismissible: barrierDismissible,
        builder: (_) => child,
        context: router.navigatorKey.currentContext!,
      );
    } else {
      showModalBottomSheet(
        backgroundColor: ColorUtil.FF282F32,
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
      builder: (context) => _DesktopMessageOverlay(message: message, type: type),
    );
    overlay.insert(entry);
    _messageOverlay = entry;
    _messageTimer = Timer(const Duration(seconds: 3), _dismissDesktopMessage);
  }
}

class _AthenaMessageVisualStyle {
  final Color accentColor;
  final IconData icon;

  const _AthenaMessageVisualStyle({required this.accentColor, required this.icon});

  factory _AthenaMessageVisualStyle.fromType(AthenaMessageType type) {
    return switch (type) {
      AthenaMessageType.info => const _AthenaMessageVisualStyle(
        accentColor: ColorUtil.FFC2C2C2,
        icon: HugeIcons.strokeRoundedInformationCircle,
      ),
      AthenaMessageType.success => const _AthenaMessageVisualStyle(
        accentColor: ColorUtil.FFA7BA88,
        icon: HugeIcons.strokeRoundedTick02,
      ),
      AthenaMessageType.warning => const _AthenaMessageVisualStyle(
        accentColor: Color(0xFFE8B86D),
        icon: HugeIcons.strokeRoundedAlert02,
      ),
      AthenaMessageType.error => const _AthenaMessageVisualStyle(
        accentColor: Color(0xFFE38B8B),
        icon: HugeIcons.strokeRoundedCancelCircle,
      ),
    };
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String text;
  const _ConfirmDialog({required this.text});

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Text(text, style: textStyle),
      const SizedBox(height: 24),
      _buildConfirmButton(context),
      const SizedBox(height: 12),
      _buildCancelButton(context),
      SizedBox(height: MediaQuery.paddingOf(context).bottom),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    var shapeDecoration = ShapeDecoration(
      color: ColorUtil.FF616161,
      shape: StadiumBorder(),
    );
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var container = Container(
      alignment: Alignment.center,
      decoration: shapeDecoration,
      padding: EdgeInsets.all(16),
      child: Text('Cancel', style: textStyle),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: cancelDialog,
      child: container,
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    var boxShadow = BoxShadow(
      blurRadius: 16,
      color: ColorUtil.FFCED2C7.withValues(alpha: 0.5),
    );
    var shapeDecoration = ShapeDecoration(
      shape: StadiumBorder(),
      color: ColorUtil.FFFFFFFF,
      shadows: [boxShadow],
    );
    var textStyle = TextStyle(
      color: ColorUtil.FF161616,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => confirmDialog(context),
      child: Container(
        alignment: Alignment.center,
        decoration: shapeDecoration,
        padding: EdgeInsets.all(16),
        child: Text('Confirm', style: textStyle),
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
    var titleStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var messageStyle = TextStyle(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.8),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var children = [
      Text(title, style: titleStyle),
      const SizedBox(height: 12),
      Text(message, style: messageStyle),
      const SizedBox(height: 24),
      _buildButtons(context),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );
    var container = Container(
      constraints: BoxConstraints(minWidth: 320, maxWidth: 520),
      decoration: boxDecoration,
      padding: EdgeInsets.all(32),
      child: column,
    );
    return Dialog(backgroundColor: Colors.transparent, child: container);
  }

  Widget _buildButtons(BuildContext context) {
    var edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var cancelButton = AthenaSecondaryButton(
      onTap: () => Navigator.of(context).maybePop(false),
      child: Padding(padding: edgeInsets, child: Text('Cancel')),
    );
    var confirmButton = AthenaPrimaryButton(
      onTap: () => Navigator.of(context).maybePop(true),
      child: Padding(padding: edgeInsets, child: Text('Confirm')),
    );
    var children = [cancelButton, const SizedBox(width: 12), confirmButton];
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
    var titleStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Text(widget.title, style: titleStyle),
      const SizedBox(height: 16),
      AthenaInput(controller: controller, autoFocus: true),
      const SizedBox(height: 24),
      _buildButtons(context),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );
    var container = Container(
      constraints: BoxConstraints(minWidth: 320, maxWidth: 520),
      decoration: boxDecoration,
      padding: EdgeInsets.all(32),
      child: column,
    );
    return Dialog(backgroundColor: Colors.transparent, child: container);
  }

  Widget _buildButtons(BuildContext context) {
    var edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var cancelButton = AthenaSecondaryButton(
      onTap: () => Navigator.of(context).maybePop(null),
      child: Padding(padding: edgeInsets, child: Text('Cancel')),
    );
    var confirmButton = AthenaPrimaryButton(
      onTap: _submit,
      child: Padding(padding: edgeInsets, child: Text('Confirm')),
    );
    var children = [cancelButton, const SizedBox(width: 12), confirmButton];
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
    var titleStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ColorUtil.FF616161),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ColorUtil.FF616161),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ColorUtil.FFFFFFFF),
      ),
      filled: true,
      fillColor: ColorUtil.FF616161,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
    var textField = TextField(
      controller: controller,
      autofocus: true,
      decoration: inputDecoration,
      style: TextStyle(color: ColorUtil.FFFFFFFF),
    );
    var children = [
      Text(widget.title, style: titleStyle),
      const SizedBox(height: 16),
      textField,
      const SizedBox(height: 24),
      _buildConfirmButton(context),
      const SizedBox(height: 12),
      _buildCancelButton(context),
      SizedBox(height: MediaQuery.paddingOf(context).bottom),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    var shapeDecoration = ShapeDecoration(
      color: ColorUtil.FF616161,
      shape: StadiumBorder(),
    );
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var container = Container(
      alignment: Alignment.center,
      decoration: shapeDecoration,
      padding: EdgeInsets.all(16),
      child: Text('Cancel', style: textStyle),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(null),
      child: container,
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    var boxShadow = BoxShadow(
      blurRadius: 16,
      color: ColorUtil.FFCED2C7.withValues(alpha: 0.5),
    );
    var shapeDecoration = ShapeDecoration(
      shape: StadiumBorder(),
      color: ColorUtil.FFFFFFFF,
      shadows: [boxShadow],
    );
    var textStyle = TextStyle(
      color: ColorUtil.FF161616,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(controller.text.trim()),
      child: Container(
        alignment: Alignment.center,
        decoration: shapeDecoration,
        padding: EdgeInsets.all(16),
        child: Text('Confirm', style: textStyle),
      ),
    );
  }
}

class _DesktopLoadingDialog extends StatelessWidget {
  const _DesktopLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        color: ColorUtil.FFFFFFFF,
        strokeWidth: 2,
      ),
    );
    final textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.8),
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    final borderSide = BorderSide(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
    );
    final children = [
      indicator,
      const SizedBox(width: 12),
      Text('Loading...', style: textStyle),
    ];
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
    final container = Container(
      decoration: BoxDecoration(
        color: ColorUtil.FF282F32,
        border: Border.fromBorderSide(borderSide),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    final style = _AthenaMessageVisualStyle.fromType(type);
    final textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    final borderSide = BorderSide(
      color: style.accentColor.withValues(alpha: 0.35),
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final children = [
      Icon(style.icon, color: style.accentColor, size: 18),
      const SizedBox(width: 10),
      Flexible(child: Text(message, style: textStyle)),
    ];
    final container = Container(
      constraints: BoxConstraints(maxWidth: screenWidth - 32),
      decoration: BoxDecoration(
        color: ColorUtil.FF282F32,
        border: Border.fromBorderSide(borderSide),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: container,
            ),
          ),
        ),
      ),
    );
  }
}
