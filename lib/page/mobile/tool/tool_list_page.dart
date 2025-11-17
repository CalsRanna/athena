import 'package:athena/entity/tool_entity.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/tool_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileToolListPage extends StatelessWidget {
  const MobileToolListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var toolViewModel = GetIt.instance<ToolViewModel>();
      var tools = toolViewModel.tools.value;
      return AthenaScaffold(
        appBar: AthenaAppBar(title: const Text('Tool')),
        body: _buildBody(tools),
      );
    });
  }

  Widget _buildBody(List<ToolEntity> tools) {
    if (tools.isEmpty) return const SizedBox();
    return ListView.separated(
      itemCount: tools.length,
      itemBuilder: (_, index) => _ToolListTile(tools[index]),
      padding: EdgeInsets.zero,
      separatorBuilder: (_, __) => _buildSeparator(),
    );
  }

  Widget _buildSeparator() {
    var divider = Divider(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
      height: 1,
      thickness: 1,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: divider,
    );
  }
}

class _ToolListTile extends StatelessWidget {
  final ToolEntity tool;
  const _ToolListTile(this.tool);

  @override
  Widget build(BuildContext context) {
    const titleTextStyle = TextStyle(
      fontSize: 16,
      color: ColorUtil.FFFFFFFF,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    const subtitleTextStyle = TextStyle(
      fontSize: 12,
      color: ColorUtil.FFE0E0E0,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var rowChildren = [
      Expanded(child: Text(tool.name, style: titleTextStyle)),
    ];
    var columnChildren = [
      Row(children: rowChildren),
      Text(tool.description, style: subtitleTextStyle),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnChildren,
    );
    var padding = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: column,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigateProviderForm(context),
      child: padding,
    );
  }

  void navigateProviderForm(BuildContext context) {
    MobileToolFormRoute(tool: tool).push<void>(context);
  }
}
