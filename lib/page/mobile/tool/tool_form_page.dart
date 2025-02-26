import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/tool.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/tool.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class MobileToolFormPage extends ConsumerStatefulWidget {
  final Tool tool;
  const MobileToolFormPage({super.key, required this.tool});

  @override
  ConsumerState<MobileToolFormPage> createState() => _MobileToolFormPageState();
}

class _MobileToolFormPageState extends ConsumerState<MobileToolFormPage> {
  final keyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var children = [
      AthenaFormTileLabel.large(title: 'API Key'),
      SizedBox(height: 12),
      AthenaInput(controller: keyController),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var labels = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: column,
    );
    var listViewChildren = [
      labels,
      SizedBox(height: 16),
      _buildTip(),
    ];
    var listView = ListView(
      padding: EdgeInsets.zero,
      children: listViewChildren,
    );
    var columnChildren = [Expanded(child: listView), _buildSubmitButton()];
    return AthenaScaffold(
      appBar: AthenaAppBar(title: Text(widget.tool.name)),
      body: SafeArea(top: false, child: Column(children: columnChildren)),
    );
  }

  @override
  void dispose() {
    keyController.dispose();
    super.dispose();
  }

  void editModel(Model model) {
    AthenaDialog.dismiss();
    MobileModelFormRoute(model: model).push(context);
  }

  @override
  void initState() {
    super.initState();
    keyController.text = widget.tool.key;
  }

  Future<void> updateTool() async {
    var viewModel = ToolViewModel(ref);
    var copiedTool = widget.tool.copyWith(key: keyController.text);
    viewModel.updateKey(copiedTool);
    AthenaDialog.message('Update successfully');
  }

  Widget _buildSubmitButton() {
    var textStyle = TextStyle(
      color: ColorUtil.FF161616,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var button = AthenaPrimaryButton(
      onTap: updateTool,
      child: Center(child: Text('Update', style: textStyle)),
    );
    return Padding(padding: const EdgeInsets.all(16), child: button);
  }

  Widget _buildTip() {
    var textStyle = TextStyle(
      color: ColorUtil.FFE0E0E0,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var text = Text(widget.tool.description, style: textStyle);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: text,
    );
  }
}
