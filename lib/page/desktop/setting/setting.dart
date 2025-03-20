import 'package:athena/page/desktop/setting/component/provider_form_dialog.dart';
import 'package:athena/page/desktop/setting/component/server_form_dialog.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingPage extends StatefulWidget {
  const DesktopSettingPage({super.key});

  @override
  State<DesktopSettingPage> createState() => _DesktopSettingPageState();
}

class _DesktopSettingPageState extends State<DesktopSettingPage> {
  int index = 0;

  final _icons = [
    HugeIcons.strokeRoundedPowerService,
    HugeIcons.strokeRoundedArtificialIntelligence03,
    HugeIcons.strokeRoundedTools,
    HugeIcons.strokeRoundedAiBrain01,
    HugeIcons.strokeRoundedInformationCircle,
  ];
  final _menus = [
    'Provider',
    'Sentinel',
    'MCP Server',
    'Default Model',
    'About Athena',
  ];

  @override
  Widget build(BuildContext context) {
    var appBar = AthenaAppBar(
      action: DesktopPopButton(),
      leading: _buildCreateButton(),
      title: _buildPageHeader(context),
    );
    var children = [_buildLeftBar(), const Expanded(child: AutoRouter())];
    return AthenaScaffold(appBar: appBar, body: Row(children: children));
  }

  void changeMenu(int index) {
    setState(() {
      this.index = index;
    });
    var route = switch (index) {
      0 => const DesktopSettingProviderRoute(),
      1 => const DesktopSettingSentinelRoute(),
      2 => const DesktopSettingServerRoute(),
      3 => const DesktopSettingDefaultModelRoute(),
      4 => const DesktopSettingAboutRoute(),
      _ => null,
    };
    if (route == null) return;
    AutoRouter.of(context).replace(route);
  }

  void showDialog() {
    if (index == 0) {
      AthenaDialog.show(DesktopProviderFormDialog());
      return;
    }
    if (index == 1) {
      DesktopSentinelFormRoute().push(context);
      return;
    }
    if (index == 2) {
      AthenaDialog.show(DesktopServerFormDialog());
      return;
    }
  }

  Widget _buildCreateButton() {
    if (index > 2) return const SizedBox();
    var icon = Icon(
      HugeIcons.strokeRoundedPencilEdit02,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    var createButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: showDialog,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
    );
    return Align(alignment: Alignment.centerRight, child: createButton);
  }

  Widget _buildLeftBar() {
    var listView = ListView.separated(
      itemBuilder: (_, index) => _itemBuilder(index),
      itemCount: _menus.length,
      padding: const EdgeInsets.all(12),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
    var borderSide =
        BorderSide(color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2));
    var boxDecoration = BoxDecoration(border: Border(right: borderSide));
    return Container(decoration: boxDecoration, width: 240, child: listView);
  }

  Widget _buildPageHeader(BuildContext context) {
    var title = 'Setting / ${_menus[index]}';
    var rowChildren = [
      const SizedBox(width: 16),
      Text(title, style: TextStyle(color: ColorUtil.FFFFFFFF)),
    ];
    return Row(children: rowChildren);
  }

  Widget _itemBuilder(int index) {
    return DesktopMenuTile(
      active: this.index == index,
      label: _menus[index],
      leading: Icon(_icons[index]),
      onTap: () => changeMenu(index),
    );
  }
}
