import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopSentinelGridPage extends StatelessWidget {
  const DesktopSentinelGridPage({super.key});

  @override
  Widget build(BuildContext context) {
    var children = [
      _TagListView(),
      Expanded(child: _SentinelGridView()),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AScaffold(body: column);
  }
}

class _ContextMenu extends StatelessWidget {
  final Offset offset;
  final void Function()? onTap;
  final Sentinel sentinel;
  const _ContextMenu({
    required this.offset,
    this.onTap,
    required this.sentinel,
  });

  @override
  Widget build(BuildContext context) {
    var editOption = DesktopContextMenuOption(
      text: 'Edit',
      onTap: () => navigateSentinelFormPage(context),
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
    var container = ProviderScope.containerOf(context);
    var provider = sentinelsNotifierProvider;
    var notifier = container.read(provider.notifier);
    notifier.destroy(sentinel);
    onTap?.call();
  }

  void navigateSentinelFormPage(BuildContext context) {
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
    var children = tags.map((tag) => ATag(text: tag)).toList();
    var wrap = Wrap(
      alignment: WrapAlignment.start,
      spacing: 12,
      runSpacing: 12,
      children: children,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: wrap,
    );
  }
}
