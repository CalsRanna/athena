import 'dart:io';

import 'package:athena/router/router.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/input.dart';
import 'package:flutter/material.dart';

class AthenaDialog {
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
    var indicator = CircularProgressIndicator(color: ColorUtil.FFFFFFFF);
    showDialog(
      barrierDismissible: false,
      context: router.navigatorKey.currentContext!,
      builder: (context) => Center(child: indicator),
    );
  }

  static void message(String message) {
    var text = Text(message, style: TextStyle(color: ColorUtil.FFFFFFFF));
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: ColorUtil.FF282F32,
    );
    var screenWidth = MediaQuery.sizeOf(
      router.navigatorKey.currentContext!,
    ).width;
    var container = Container(
      constraints: BoxConstraints(maxWidth: screenWidth - 32),
      decoration: boxDecoration,
      margin: EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: text,
    );
    var alignment = Alignment.center;
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      alignment = Alignment.centerLeft;
    }
    var unconstrainedBox = UnconstrainedBox(
      alignment: alignment,
      child: container,
    );
    var snackBar = SnackBar(
      backgroundColor: Colors.transparent,
      content: unconstrainedBox,
      elevation: 0,
      padding: EdgeInsets.zero,
    );
    var isWindow = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    if (!isWindow) {
      snackBar = SnackBar(behavior: SnackBarBehavior.floating, content: text);
    }
    var messenger = ScaffoldMessenger.of(router.navigatorKey.currentContext!);
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

  static void success(String message) {
    show(_SuccessDialog(message: message));
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

class _SuccessDialog extends StatelessWidget {
  final String message;
  const _SuccessDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Text(message, style: textStyle),
      const SizedBox(height: 24),
      _buildConfirmButton(context),
      SizedBox(height: MediaQuery.paddingOf(context).bottom),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void confirmDialog() {
    Navigator.of(router.navigatorKey.currentContext!).pop();
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
      onTap: confirmDialog,
      child: Container(
        alignment: Alignment.center,
        decoration: shapeDecoration,
        padding: EdgeInsets.all(16),
        child: Text('Done', style: textStyle),
      ),
    );
  }
}
