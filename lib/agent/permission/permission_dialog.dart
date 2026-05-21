import 'dart:io';

import 'package:athena/router/router.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

class PermissionDialogResult {
  final bool approved;
  final bool persist;

  const PermissionDialogResult({required this.approved, required this.persist});
}

Future<PermissionDialogResult> showPermissionDialog({
  required String toolName,
  required String description,
  required String ruleDescription,
  bool allowPersist = true,
}) async {
  final context = router.navigatorKey.currentContext!;
  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    final result = await showDialog<PermissionDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DesktopPermissionDialog(
        toolName: toolName,
        description: description,
        ruleDescription: ruleDescription,
        allowPersist: allowPersist,
      ),
    );
    return result ?? const PermissionDialogResult(approved: false, persist: false);
  } else {
    final result = await showModalBottomSheet<PermissionDialogResult>(
      context: context,
      backgroundColor: ColorUtil.FF282F32,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _MobilePermissionDialog(
        toolName: toolName,
        description: description,
        ruleDescription: ruleDescription,
        allowPersist: allowPersist,
      ),
    );
    return result ?? const PermissionDialogResult(approved: false, persist: false);
  }
}

class _DesktopPermissionDialog extends StatefulWidget {
  final String toolName;
  final String description;
  final String ruleDescription;
  final bool allowPersist;

  const _DesktopPermissionDialog({
    required this.toolName,
    required this.description,
    required this.ruleDescription,
    required this.allowPersist,
  });

  @override
  State<_DesktopPermissionDialog> createState() =>
      _DesktopPermissionDialogState();
}

class _DesktopPermissionDialogState extends State<_DesktopPermissionDialog> {
  bool _persist = false;

  @override
  Widget build(BuildContext context) {
    var titleRow = Row(children: [
      Icon(
        HugeIcons.strokeRoundedAlert02,
        size: 20,
        color: Colors.orange.shade700,
      ),
      const SizedBox(width: 8),
      Text(widget.toolName, style: GoogleFonts.firaCode(
        fontSize: 16,
        color: ColorUtil.FFFFFFFF,
        fontWeight: FontWeight.w500,
      )),
    ]);
    var descriptionText = Text(
      widget.description,
      style: GoogleFonts.firaCode(
        fontSize: 13,
        color: ColorUtil.FFFFFFFF,
        height: 1.6,
      ),
    );
    var children = <Widget>[
      titleRow,
      const SizedBox(height: 16),
      descriptionText,
    ];
    if (widget.allowPersist) {
      children.add(const SizedBox(height: 16));
      children.add(_buildCheckbox());
    }
    children.add(const SizedBox(height: 24));
    children.add(_buildButtons());

    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    var container = Container(
      constraints: const BoxConstraints(minWidth: 360, maxWidth: 520),
      decoration: BoxDecoration(
        color: ColorUtil.FF282F32,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(24),
      child: column,
    );
    return Dialog(backgroundColor: Colors.transparent, child: container);
  }

  Widget _buildCheckbox() {
    var textStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 13,
    );
    return GestureDetector(
      onTap: () => setState(() => _persist = !_persist),
      behavior: HitTestBehavior.opaque,
      child: Row(children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _persist,
            onChanged: (v) => setState(() => _persist = v ?? false),
            activeColor: Colors.orange.shade700,
            side: BorderSide(color: ColorUtil.FFC2C2C2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(widget.ruleDescription, style: textStyle)),
      ]),
    );
  }

  Widget _buildButtons() {
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var denyButton = AthenaSecondaryButton(
      onTap: () => Navigator.pop(
        context,
        const PermissionDialogResult(approved: false, persist: false),
      ),
      child: Padding(padding: edgeInsets, child: const Text('Deny')),
    );
    var allowButton = AthenaPrimaryButton(
      onTap: () => Navigator.pop(
        context,
        PermissionDialogResult(approved: true, persist: _persist),
      ),
      child: Padding(padding: edgeInsets, child: const Text('Allow')),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [denyButton, const SizedBox(width: 12), allowButton],
    );
  }
}

class _MobilePermissionDialog extends StatefulWidget {
  final String toolName;
  final String description;
  final String ruleDescription;
  final bool allowPersist;

  const _MobilePermissionDialog({
    required this.toolName,
    required this.description,
    required this.ruleDescription,
    required this.allowPersist,
  });

  @override
  State<_MobilePermissionDialog> createState() =>
      _MobilePermissionDialogState();
}

class _MobilePermissionDialogState extends State<_MobilePermissionDialog> {
  bool _persist = false;

  @override
  Widget build(BuildContext context) {
    var titleRow = Row(children: [
      Icon(
        HugeIcons.strokeRoundedAlert02,
        size: 20,
        color: Colors.orange.shade700,
      ),
      const SizedBox(width: 8),
      Text(widget.toolName, style: GoogleFonts.firaCode(
        fontSize: 16,
        color: ColorUtil.FFFFFFFF,
        fontWeight: FontWeight.w500,
      )),
    ]);
    var descriptionText = Text(
      widget.description,
      style: GoogleFonts.firaCode(
        fontSize: 13,
        color: ColorUtil.FFFFFFFF,
        height: 1.6,
      ),
    );
    var children = <Widget>[
      titleRow,
      const SizedBox(height: 16),
      descriptionText,
    ];
    if (widget.allowPersist) {
      children.add(const SizedBox(height: 16));
      children.add(_buildCheckbox());
    }
    children.add(const SizedBox(height: 24));
    children.add(_buildAllowButton());
    children.add(const SizedBox(height: 12));
    children.add(_buildDenyButton());
    children.add(SizedBox(height: MediaQuery.paddingOf(context).bottom));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildCheckbox() {
    var textStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 13,
    );
    return GestureDetector(
      onTap: () => setState(() => _persist = !_persist),
      behavior: HitTestBehavior.opaque,
      child: Row(children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _persist,
            onChanged: (v) => setState(() => _persist = v ?? false),
            activeColor: Colors.orange.shade700,
            side: BorderSide(color: ColorUtil.FFC2C2C2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(widget.ruleDescription, style: textStyle)),
      ]),
    );
  }

  Widget _buildAllowButton() {
    var shapeDecoration = ShapeDecoration(
      shape: const StadiumBorder(),
      color: ColorUtil.FFFFFFFF,
      shadows: [
        BoxShadow(
          blurRadius: 16,
          color: ColorUtil.FFCED2C7.withValues(alpha: 0.5),
        ),
      ],
    );
    var textStyle = TextStyle(
      color: ColorUtil.FF161616,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(
        context,
        PermissionDialogResult(approved: true, persist: _persist),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: shapeDecoration,
        padding: const EdgeInsets.all(16),
        child: Text('Allow', style: textStyle),
      ),
    );
  }

  Widget _buildDenyButton() {
    var shapeDecoration = ShapeDecoration(
      color: ColorUtil.FF616161,
      shape: const StadiumBorder(),
    );
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(
        context,
        const PermissionDialogResult(approved: false, persist: false),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: shapeDecoration,
        padding: const EdgeInsets.all(16),
        child: Text('Deny', style: textStyle),
      ),
    );
  }
}
