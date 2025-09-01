import 'dart:io';

import 'package:athena/main.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/button.dart';
import 'package:flutter/material.dart';

class AthenaDialog {
  static Future<bool?> confirm(String text) async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return showDialog<bool>(
        builder: (_) => _DesktopConfirmDialog(text: text),
        context: globalKey.currentContext!,
      );
    } else {
      return showModalBottomSheet<bool>(
        backgroundColor: ColorUtil.FF282F32,
        builder: (_) => _ConfirmDialog(text: text),
        context: globalKey.currentContext!,
      );
    }
  }

  static void dismiss() {
    Navigator.of(globalKey.currentContext!).pop();
  }

  static void loading() {
    var indicator = CircularProgressIndicator(color: ColorUtil.FFFFFFFF);
    showDialog(
      barrierDismissible: false,
      context: globalKey.currentContext!,
      builder: (context) => Center(child: indicator),
    );
  }

  static void message(String message) {
    var text = Text(message, style: TextStyle(color: ColorUtil.FFFFFFFF));
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: ColorUtil.FF282F32,
    );
    var screenWidth = MediaQuery.sizeOf(globalKey.currentContext!).width;
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
    var messenger = ScaffoldMessenger.of(globalKey.currentContext!);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(snackBar);
  }

  static void show(Widget child, {bool barrierDismissible = false}) {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      showDialog(
        barrierDismissible: barrierDismissible,
        builder: (_) => child,
        context: globalKey.currentContext!,
      );
    } else {
      showModalBottomSheet(
        backgroundColor: ColorUtil.FF282F32,
        builder: (_) => child,
        context: globalKey.currentContext!,
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
    Navigator.of(globalKey.currentContext!).pop(false);
  }

  void confirmDialog(BuildContext context) {
    Navigator.of(globalKey.currentContext!).pop(true);
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
  final String text;
  const _DesktopConfirmDialog({required this.text});

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
      _buildButtons(context),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );
    var container = Container(
      decoration: boxDecoration,
      padding: EdgeInsets.all(24),
      child: column,
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      child: UnconstrainedBox(child: container),
    );
  }

  Widget _buildButtons(BuildContext context) {
    var edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var cancelButton = AthenaSecondaryButton(
      onTap: () => Navigator.of(context).maybePop(false),
      child: Padding(padding: edgeInsets, child: Text('Cancel')),
    );
    var storeButton = AthenaPrimaryButton(
      onTap: () => Navigator.of(context).maybePop(true),
      child: Padding(padding: edgeInsets, child: Text('Confirm')),
    );
    var children = [cancelButton, const SizedBox(width: 12), storeButton];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
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
    Navigator.of(globalKey.currentContext!).pop();
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
