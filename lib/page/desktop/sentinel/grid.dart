import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
import 'package:athena/widget/window_button.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSentinelGridPage extends StatelessWidget {
  const DesktopSentinelGridPage({super.key});

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildPageHeader(context),
      SizedBox(height: 52, child: _TagListView()),
      Expanded(child: _SentinelGridView()),
    ];
    return AScaffold(body: Column(children: children));
  }

  void popPage(BuildContext context) {
    AutoRouter.of(context).maybePop();
  }

  Widget _buildPageHeader(BuildContext context) {
    var icon = Icon(
      HugeIcons.strokeRoundedArrowTurnBackward,
      color: Colors.white,
      size: 24,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => popPage(context),
      child: icon,
    );
    var container = Container(
      height: 50,
      width: 120,
      alignment: Alignment.centerRight,
      child: gestureDetector,
    );
    var stackChildren = [
      container,
      const Positioned(left: 16, top: 18, child: MacWindowButton())
    ];
    var titleText = Text('Sentinel', style: TextStyle(color: Colors.white));
    var rowChildren = [
      Stack(children: stackChildren),
      const SizedBox(width: 16),
      Expanded(child: titleText),
    ];
    return Row(children: rowChildren);
  }
}

class _ContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onTap;
  final Sentinel sentinel;
  const _ContextMenu(
      {required this.offset, this.onTap, required this.sentinel});

  @override
  Widget build(BuildContext context) {
    var editOption = DesktopContextMenuOption(
      text: 'Edit',
      onTap: () => navigateSentinelFormPage(context, sentinel),
    );
    var deleteOption = DesktopContextMenuOption(
      text: 'Delete',
      onTap: () => destroySentinel(context),
    );
    return DesktopContextMenu(
      offset: offset,
      onBarrierTapped: onTap,
      children: [editOption, deleteOption],
    );
  }

  void destroySentinel(BuildContext context) {
    AutoRouter.of(context).maybePop<Sentinel>(sentinel);
    onTap?.call();
  }

  void navigateSentinelFormPage(BuildContext context, Sentinel sentinel) {
    DesktopSentinelFormRoute(sentinel: sentinel).push(context);
    onTap?.call();
  }
}

class _SentinelGridView extends ConsumerWidget {
  const _SentinelGridView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = sentinelsNotifierProvider;
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(List<Sentinel> sentinels) {
    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      childAspectRatio: 2.0,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: delegate,
      itemCount: sentinels.length,
      itemBuilder: (context, index) => _SentinelTile(sentinels[index]),
    );
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
    const descriptionTextStyle = TextStyle(
      color: Color(0xFF616161),
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var descriptionText = Text(
      widget.sentinel.description,
      style: descriptionTextStyle,
    );
    var children = [
      Text(widget.sentinel.name, style: nameTextStyle),
      const SizedBox(height: 4),
      Expanded(child: descriptionText),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(12),
      child: column,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => showContextMenu(context, details),
      onTap: () => popPageWithResult(context),
      child: container,
    );
  }

  void popPageWithResult(BuildContext context) {
    AutoRouter.of(context).maybePop<Sentinel>(widget.sentinel);
  }

  void removeEntry() {
    if (entry != null) {
      entry!.remove();
      entry = null;
    }
  }

  void showContextMenu(BuildContext context, TapUpDetails details) {
    var contextMenu = _ContextMenu(
      offset: details.globalPosition,
      onTap: removeEntry,
      sentinel: widget.sentinel,
    );
    entry = OverlayEntry(builder: (_) => contextMenu);
    Overlay.of(context).insert(entry!);
  }
}

class _TagListView extends ConsumerWidget {
  const _TagListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = sentinelTagsNotifierProvider;
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(List<String> tags) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemBuilder: (_, index) => ATag(text: tags[index]),
      itemCount: tags.length,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      separatorBuilder: (context, index) => const SizedBox(width: 12),
    );
  }
}
