import 'package:athena/main.dart';
import 'package:flutter/material.dart';

class ADialog {
  static void confirm(String title, {void Function()? onConfirmed}) {
    show(_ConfirmDialog(title: title, onConfirmed: onConfirmed));
  }

  static void dismiss() {
    Navigator.of(globalKey.currentContext!).pop();
  }

  static void show(Widget child) {
    showModalBottomSheet(
      backgroundColor: Color(0xFF282F32),
      builder: (_) => child,
      context: globalKey.currentContext!,
    );
  }

  static void success(String message) {
    show(_SuccessDialog(message: message));
  }

  static void loading() {
    showDialog(
      context: globalKey.currentContext!,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final void Function()? onConfirmed;
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

  void confirmDialog() {
    onConfirmed?.call();
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
      onTap: confirmDialog,
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
