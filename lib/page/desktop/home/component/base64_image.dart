import 'dart:convert';
import 'dart:typed_data';

import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';

class DesktopBase64Image extends StatefulWidget {
  final String base64;
  final BoxFit? fit;
  final double? height;
  final double? width;
  const DesktopBase64Image({
    super.key,
    required this.base64,
    this.fit,
    this.height,
    this.width,
  });

  @override
  State<DesktopBase64Image> createState() => _DesktopBase64ImageState();
}

class _DesktopBase64ImagePreviewDialog extends StatelessWidget {
  final Uint8List bytes;
  const _DesktopBase64ImagePreviewDialog({required this.bytes});

  @override
  Widget build(BuildContext context) {
    var windowSize = MediaQuery.sizeOf(context);
    var size = Size(windowSize.width - 64, windowSize.height - 64);
    var container = ConstrainedBox(
      constraints: BoxConstraints.loose(size),
      child: SingleChildScrollView(child: Image.memory(bytes)),
    );
    return UnconstrainedBox(child: container);
  }
}

class _DesktopBase64ImageState extends State<DesktopBase64Image> {
  late Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    var image = Image.memory(
      bytes,
      fit: widget.fit,
      height: widget.height,
      width: widget.width,
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => _openPreviewDialog(), child: image),
    );
  }

  @override
  void initState() {
    super.initState();
    bytes = base64Decode(widget.base64);
  }

  void _openPreviewDialog() {
    AthenaDialog.show(
      _DesktopBase64ImagePreviewDialog(bytes: bytes),
      barrierDismissible: true,
    );
  }
}
