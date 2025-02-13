import 'package:athena/page/desktop/setting/component/provider_form_dialog.dart';
import 'package:athena/router/router.gr.dart';
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
    HugeIcons.strokeRoundedAiBrain01,
    HugeIcons.strokeRoundedArtificialIntelligence03,
  ];
  final _menus = ['Provider', 'Default Model', 'Sentinel'];

  @override
  Widget build(BuildContext context) {
    var appBar = AAppBar(
      action: DesktopPopButton(),
      leading: _buildCreateButton(),
      title: _buildPageHeader(context),
    );
    var children = [_buildLeftBar(), const Expanded(child: AutoRouter())];
    return AScaffold(appBar: appBar, body: Row(children: children));
  }

  void changeMenu(int index) {
    setState(() {
      this.index = index;
    });
    var route = switch (index) {
      0 => const DesktopSettingProviderRoute(),
      1 => const DesktopSettingDefaultModelRoute(),
      2 => const DesktopSettingSentinelRoute(),
      _ => null,
    };
    if (route == null) return;
    AutoRouter.of(context).replace(route);
  }

  void showDialog() {
    if (index == 1) {
      DesktopSentinelFormRoute().push(context);
      return;
    }
    ADialog.show(DesktopProviderFormDialog());
  }

  Widget _buildCreateButton() {
    var icon = Icon(
      HugeIcons.strokeRoundedPencilEdit02,
      color: Colors.white,
      size: 24,
    );
    var createButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: showDialog,
      child: icon,
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
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    var boxDecoration = BoxDecoration(border: Border(right: borderSide));
    return Container(decoration: boxDecoration, width: 200, child: listView);
  }

  Widget _buildPageHeader(BuildContext context) {
    var title = 'Setting / ${_menus[index]}';
    var rowChildren = [
      const SizedBox(width: 16),
      Text(title, style: TextStyle(color: Colors.white)),
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
