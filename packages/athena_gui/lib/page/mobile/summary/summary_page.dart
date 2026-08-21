import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/entity/summary_entity.dart';
import 'package:athena_gui/page/mobile/summary/component/summary_list_tile.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/summary_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileSummaryPage extends StatefulWidget {
  /// 从 Shortcut 进入时绑定的专属 Sentinel（能力配置）。
  final SentinelEntity? sentinel;
  const MobileSummaryPage({super.key, this.sentinel});

  @override
  State<MobileSummaryPage> createState() => _MobileSummaryPageState();
}

class _MobileSummaryPageState extends State<MobileSummaryPage> {
  final controller = TextEditingController();
  late final viewModel = GetIt.instance<SummaryViewModel>();

  @override
  void initState() {
    super.initState();
    // Shortcut 入口：注入绑定的专属 Sentinel 作为摘要能力配置
    viewModel.setBoundSentinel(widget.sentinel);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AthenaScaffold(
      appBar: AthenaAppBar(title: Text('Summary')),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          AthenaInput(
            controller: controller,
            placeholder: 'Paste a link here',
            radius: 36,
            onSubmitted: handleSubmit,
          ),
          SizedBox(height: 24),
          _buildTitle(context),
          SizedBox(height: 16),
          ..._buildSummaryListView(),
        ],
      ),
    );
  }

  List<Widget> _buildSummaryListView() {
    return [
      Watch((context) {
        var summaries = viewModel.summaries.value;
        if (summaries.isEmpty) return const SizedBox();
        List<Widget> children = [];
        for (var summary in summaries) {
          var mobileSummaryListTile = MobileSummaryListTile(
            onTap: () => navigateSummaryDetailPage(summary),
            summary: summary,
          );
          children.add(mobileSummaryListTile);
          children.add(const SizedBox(height: 4));
        }
        if (children.isNotEmpty) children.removeLast();
        return Column(children: children);
      }),
    ];
  }

  void navigateSummaryDetailPage(SummaryEntity summary) {
    MobileSummaryDetailRoute(summary: summary).push(context);
  }

  Future<void> handleSubmit(String link) async {
    if (link.isEmpty) {
      AthenaDialog.warning('Link can not be empty');
      return;
    }
    var id = await viewModel.createSummary(link);
    var summary = SummaryEntity(
      id: id,
      link: link,
      title: '',
      content: '',
      icon: '',
      createdAt: DateTime.now(),
    );
    if (!mounted) return;
    MobileSummaryDetailRoute(summary: summary).push(context);
    controller.text = '';
    await viewModel.parse(summary);
  }

  Widget _buildTitle(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final titleTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Text('History', style: titleTextStyle),
      const Spacer(),
      AthenaTextButton(onTap: viewModel.deleteAllSummaries, text: 'Clear'),
    ];
    return Row(children: children);
  }
}
