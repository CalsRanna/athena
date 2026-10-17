import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final void Function()? onTap;
  final String title;
  const SectionTitle(this.title, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 分区标题用 title，不用 hero：hero 是空态欢迎语那一档，首页三个分区
    // 若都按 hero 排，层级会比桌面设置分区更响。
    final textStyle = AthenaTextStyle.title.copyWith(color: colors.textPrimary);
    final children = [
      Expanded(child: Text(title, style: textStyle)),
      if (onTap != null)
        AthenaIconButton(icon: AthenaIcons.forward, onTap: onTap),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: children),
    );
  }
}
