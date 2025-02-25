import 'dart:io';

import 'package:athena/main.dart';
import 'package:flutter/material.dart';

class ADialog {
  static void confirm(
    String title, {
    void Function(BuildContext)? onConfirmed,
  }) {
    show(_ConfirmDialog(title: title, onConfirmed: onConfirmed));
  }

  static void dismiss() {
    Navigator.of(globalKey.currentContext!).pop();
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
        backgroundColor: Color(0xFF282F32),
        builder: (_) => child,
        context: globalKey.currentContext!,
      );
    }
  }

  static void success(String message) {
    show(_SuccessDialog(message: message));
  }

  static void loading() {
    var indicator = CircularProgressIndicator(color: Colors.white);
    showDialog(
      context: globalKey.currentContext!,
      builder: (context) => Center(child: indicator),
    );
  }

  static void message(String message) {
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: Color(0xFF282F32),
    );
    var container = Container(
      decoration: boxDecoration,
      margin: EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(message, style: TextStyle(color: Colors.white)),
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
      duration: Duration(seconds: 2),
      elevation: 0,
      padding: EdgeInsets.zero,
    );
    var messenger = ScaffoldMessenger.of(globalKey.currentContext!);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(snackBar);
  }
}

class _ConfirmDialog extends StatelessWidget {
  final void Function(BuildContext)? onConfirmed;
  final String title;
  const _ConfirmDialog({this.onConfirmed, required this.title});

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Text(title, style: textStyle),
      const SizedBox(height: 24),
      _buildConfirmButton(context),
      const SizedBox(height: 12),
      _buildCancelButton(context),
      SizedBox(height: MediaQuery.paddingOf(context).bottom)
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void cancelDialog() {
    Navigator.of(globalKey.currentContext!).pop();
  }

  void confirmDialog(BuildContext context) {
    onConfirmed?.call(context);
  }

  Widget _buildCancelButton(BuildContext context) {
    var shapeDecoration = ShapeDecoration(
      color: Color(0xFF616161),
      shape: StadiumBorder(),
    );
    var textStyle = TextStyle(
      color: Colors.white,
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
      color: Color(0xFFCED2C7).withValues(alpha: 0.5),
    );
    var shapeDecoration = ShapeDecoration(
      shape: StadiumBorder(),
      color: Colors.white,
      shadows: [boxShadow],
    );
    var textStyle = TextStyle(
      color: Color(0xFF161616),
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

class _SuccessDialog extends StatelessWidget {
  final String message;
  const _SuccessDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Text(message, style: textStyle),
      const SizedBox(height: 24),
      _buildConfirmButton(context),
      SizedBox(height: MediaQuery.paddingOf(context).bottom)
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
      color: Color(0xFFCED2C7).withValues(alpha: 0.5),
    );
    var shapeDecoration = ShapeDecoration(
      shape: StadiumBorder(),
      color: Colors.white,
      shadows: [boxShadow],
    );
    var textStyle = TextStyle(
      color: Color(0xFF161616),
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
