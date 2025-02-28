import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/sentinel.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopSettingSentinelPage extends ConsumerWidget {
  const DesktopSettingSentinelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var sentinels = ref.watch(sentinelsNotifierProvider).value;
    if (sentinels == null) return const SizedBox();
    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      childAspectRatio: 2.0,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );
    var gridView = GridView.builder(
      gridDelegate: delegate,
      itemCount: sentinels.length,
      itemBuilder: (context, index) => _SentinelTile(sentinels[index]),
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
    );
    return AthenaScaffold(body: gridView);
  }
}

class _SentinelContextMenu extends ConsumerWidget {
  final Offset offset;
  final void Function()? onTap;
  final Sentinel sentinel;
  const _SentinelContextMenu({
    required this.offset,
    this.onTap,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var editOption = DesktopContextMenuOption(
      text: 'Edit',
      onTap: () => navigateSentinelFormPage(context),
    );
    var deleteOption = DesktopContextMenuOption(
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

class _SentinelTile extends StatefulWidget {
  final Sentinel sentinel;
  const _SentinelTile(this.sentinel);

  @override
  State<_SentinelTile> createState() => _SentinelTileState();
}

class _SentinelTileState extends State<_SentinelTile> {
  OverlayEntry? entry;

  @override
  Widget build(BuildContext context) {
    const nameTextStyle = TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var descriptionText = LayoutBuilder(builder: _buildDescriptionText);
    var children = [
      Text(
        widget.sentinel.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: nameTextStyle,
      ),
      const SizedBox(height: 4),
      Expanded(child: descriptionText),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: ColorUtil.FFFFFFFF,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(12),
      child: column,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => showContextMenu(context, details),
      child: container,
    );
  }

  Widget _buildDescriptionText(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    const descriptionTextStyle = TextStyle(
      color: ColorUtil.FF616161,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var maxLines = constraints.maxHeight ~/ 18;
    return Text(
      widget.sentinel.description,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: descriptionTextStyle,
    );
  }

  void removeEntry() {
    if (entry != null) {
      entry!.remove();
      entry = null;
    }
  }

  void showContextMenu(BuildContext context, TapUpDetails details) {
    if (widget.sentinel.name == 'Athena') return;
    var contextMenu = _SentinelContextMenu(
      offset: details.globalPosition - Offset(240, 50),
      onTap: removeEntry,
      sentinel: widget.sentinel,
    );
    entry = OverlayEntry(builder: (_) => contextMenu);
    Overlay.of(context).insert(entry!);
  }
}
