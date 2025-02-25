import 'package:athena/provider/tool.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/tool.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class MobileToolListPage extends ConsumerWidget {
  const MobileToolListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var tools = ref.watch(toolsNotifierProvider).valueOrNull;
    Widget body = const SizedBox();
    if (tools != null) body = _buildBody(tools);
    return AScaffold(
      appBar: AAppBar(title: const Text('Tool')),
      body: body,
    );
  }

  Widget _buildBody(List<Tool> tools) {
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
      color: Color(0xFFFFFFFF).withValues(alpha: 0.2),
      height: 1,
      thickness: 1,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: divider,
    );
  }
}

class _ToolListTile extends ConsumerWidget {
  final Tool tool;
  const _ToolListTile(this.tool);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const titleTextStyle = TextStyle(
      fontSize: 16,
      color: Color(0xFFFFFFFF),
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    const subtitleTextStyle = TextStyle(
      fontSize: 12,
      color: Color(0xFFE0E0E0),
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
    MobileToolFormRoute(tool: tool).push(context);
  }
}
