import 'dart:convert';
import 'dart:io';

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopInformationIndicator extends StatelessWidget {
  const DesktopInformationIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var icon = Icon(
      HugeIcons.strokeRoundedInformationCircle,
      color: colors.textPrimary,
      size: 24,
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: icon,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openDialog(context),
      child: mouseRegion,
    );
  }

  void openDialog(BuildContext context) {
    AthenaDialog.show(_DesktopInformationDialog(), barrierDismissible: true);
  }
}

class _DesktopInformationDialog extends StatelessWidget {
  const _DesktopInformationDialog();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var listView = ListView(
      padding: EdgeInsets.symmetric(vertical: 16),
      shrinkWrap: true,
      children: [_buildEnvironment(), _buildPath(), _buildProcessPath()],
    );
    var textStyle = TextStyle(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var defaultTextStyle = DefaultTextStyle.merge(
      style: textStyle,
      child: listView,
    );
    var constrainedBox = ConstrainedBox(
      constraints: BoxConstraints.loose(Size(520, 640)),
      child: defaultTextStyle,
    );
    var boxDecoration = BoxDecoration(
      color: colors.surfaceMobile,
      borderRadius: BorderRadius.circular(8),
    );
    var container = Container(
      decoration: boxDecoration,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: constrainedBox,
    );
    return UnconstrainedBox(child: container);
  }

  Widget _buildEnvironment() {
    var encoder = JsonEncoder.withIndent('  ');
    var environment = encoder.convert(Platform.environment);
    var children = [
      SizedBox(width: 100, child: Text('Environment')),
      SizedBox(width: 16),
      Expanded(child: Text(environment)),
    ];
    return Row(children: children);
  }

  Widget _buildPath() {
    var path = Platform.environment['PATH'] ?? '';
    var children = [
      SizedBox(width: 100, child: Text('Path')),
      SizedBox(width: 16),
      Expanded(child: Text(path)),
    ];
    return Row(children: children);
  }

  Widget _buildProcessPath() {
    // var path = ProcessUtil.defaultPath;
    var children = [
      SizedBox(width: 100, child: Text('Process Path')),
      SizedBox(width: 16),
      // Expanded(child: Text(path)),
      Expanded(child: Text('Not implemented')),
    ];
    return Row(children: children);
  }
}
