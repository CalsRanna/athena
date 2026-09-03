import 'package:athena_gui/entity/summary_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class MobileSummaryListTile extends StatelessWidget {
  final void Function()? onTap;
  final SummaryEntity summary;

  const MobileSummaryListTile({super.key, this.onTap, required this.summary});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var titleTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var titleText = Text(
      summary.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: titleTextStyle,
    );
    var linkTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var linkText = Text(
      summary.link,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: linkTextStyle,
    );
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [titleText, linkText],
    );
    var rowChildren = [
      _buildLogo(context),
      SizedBox(width: 20),
      Expanded(child: column),
    ];
    var row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowChildren,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }

  Widget _buildLogo(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var icon = Icon(
      HugeIcons.strokeRoundedAiBrowser,
      color: colors.iconOnRaised,
      size: 32,
    );
    Widget child = icon;
    if (summary.icon.isNotEmpty) {
      child = UnconstrainedBox(
        child: CachedNetworkImage(
          imageUrl: summary.icon,
          errorWidget: (_, __, ___) => icon,
          fit: BoxFit.cover,
          height: 32,
          placeholder: (_, __) => icon,
          width: 32,
        ),
      );
    }
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: colors.inputBackground,
    );
    return Container(
      decoration: boxDecoration,
      height: 80,
      width: 80,
      child: child,
    );
  }
}
