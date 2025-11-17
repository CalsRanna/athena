import 'package:athena/entity/summary_entity.dart';
import 'package:athena/page/mobile/summary/component/summary_list_tile.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/summary_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileSummaryPage extends StatefulWidget {
  const MobileSummaryPage({super.key});

  @override
  State<MobileSummaryPage> createState() => _MobileSummaryPageState();
}

class _MobileSummaryPageState extends State<MobileSummaryPage> {
  final controller = TextEditingController();
  late final viewModel = GetIt.instance<SummaryViewModel>();

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
          _buildTitle(),
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
      })
    ];
  }

  void navigateSummaryDetailPage(SummaryEntity summary) {
    MobileSummaryDetailRoute(summary: summary).push(context);
  }

  Future<void> handleSubmit(String link) async {
    if (link.isEmpty) {
      AthenaDialog.message('Link can not be empty');
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

  Widget _buildTitle() {
    const titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Text('History', style: titleTextStyle),
      const Spacer(),
      AthenaTextButton(onTap: viewModel.deleteAllSummaries, text: 'Clear')
    ];
    return Row(children: children);
  }
}
