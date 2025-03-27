import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/view_model/sentinel.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopSentinelContextMenu extends ConsumerWidget {
  final Offset offset;
  final void Function()? onTap;
  final Sentinel sentinel;
  const DesktopSentinelContextMenu({
    super.key,
    required this.offset,
    this.onTap,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var editOption = DesktopContextMenuTile(
      text: 'Edit',
      onTap: () => navigateSentinelFormPage(context),
    );
    var deleteOption = DesktopContextMenuTile(
      text: 'Delete',
      onTap: () => destroySentinel(context, ref),
    );
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onTap,
      children: [editOption, deleteOption],
    );
  }

  void destroySentinel(BuildContext context, WidgetRef ref) {
    SentinelViewModel(ref).destroySentinel(sentinel);
    onTap?.call();
  }

  void navigateSentinelFormPage(BuildContext context) {
    DesktopSentinelFormRoute(sentinel: sentinel).push(context);
    onTap?.call();
  }
}
