import 'dart:convert';
import 'dart:typed_data';

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

class _DesktopBase64ImageState extends State<DesktopBase64Image> {
  late Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: widget.fit,
      height: widget.height,
      width: widget.width,
    );
  }

  @override
  void initState() {
    super.initState();
    bytes = base64Decode(widget.base64);
  }
}
