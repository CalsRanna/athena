import 'package:athena/page/desktop/setting/sentinel/component/sentinel_context_menu.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/sentinel.dart';
import 'package:athena/widget/context_menu.dart';
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

class _SentinelTile extends ConsumerWidget {
  final Sentinel sentinel;
  const _SentinelTile(this.sentinel);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const nameTextStyle = TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var descriptionText = LayoutBuilder(builder: _buildDescriptionText);
    var children = [
      Text(
        sentinel.name,
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
      onSecondaryTapUp: (details) => openContextMenu(context, ref, details),
      child: container,
    );
  }

  void destroySentinel(BuildContext context, WidgetRef ref) {
    SentinelViewModel(ref).destroySentinel(sentinel);
  }

  void navigateSentinelFormPage(BuildContext context) {
    DesktopSentinelFormRoute(sentinel: sentinel).push(context);
  }

  void openContextMenu(
    BuildContext context,
    WidgetRef ref,
    TapUpDetails details,
  ) {
    if (sentinel.name == 'Athena') return;
    var contextMenu = DesktopSentinelContextMenu(
      offset: details.globalPosition - Offset(240, 50),
      onDestroyed: () => destroySentinel(context, ref),
      onEdited: () => navigateSentinelFormPage(context),
    );
    DesktopContextMenuManager.instance.show(context, contextMenu);
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
      sentinel.description,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: descriptionTextStyle,
    );
  }
}
