import 'package:athena/page/mobile/provider/component/model_list_view.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model.dart';
import 'package:athena/view_model/provider.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileProviderFormPage extends ConsumerStatefulWidget {
  final schema.Provider provider;
  const MobileProviderFormPage({super.key, required this.provider});

  @override
  ConsumerState<MobileProviderFormPage> createState() =>
      _MobileProviderFormPageState();
}

class _MobileProviderFormPageState
    extends ConsumerState<MobileProviderFormPage> {
  final keyController = TextEditingController();
  final urlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var children = [
      AthenaFormTileLabel.large(title: 'API Key'),
      SizedBox(height: 12),
      AthenaInput(controller: keyController),
      SizedBox(height: 16),
      AthenaFormTileLabel.large(title: 'API Url'),
      SizedBox(height: 12),
      AthenaInput(controller: urlController),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var labels = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: column,
    );
    var modelListView = MobileModelListView(
      onLongPress: openBottomSheet,
      onTap: editModel,
      provider: widget.provider,
    );
    var listViewChildren = [
      labels,
      SizedBox(height: 16),
      _buildModelFormLabel(context),
      SizedBox(height: 12),
      modelListView,
      if (widget.provider.isPreset) SizedBox(height: 16),
      if (widget.provider.isPreset) _buildTip(),
    ];
    var listView = ListView(
      padding: EdgeInsets.zero,
      children: listViewChildren,
    );
    var columnChildren = [Expanded(child: listView), _buildSubmitButton()];
    return AthenaScaffold(
      appBar: AthenaAppBar(title: Text(widget.provider.name)),
      body: SafeArea(top: false, child: Column(children: columnChildren)),
    );
  }

  Future<void> checkConnection(Model model) async {
    AthenaDialog.dismiss();
    var viewModel = ModelViewModel(ref);
    var message = await viewModel.checkConnection(model);
    AthenaDialog.message(message);
  }

  void createModel(BuildContext context) {
    MobileModelFormRoute(provider: widget.provider).push(context);
  }

  void destroyModel(Model model) {
    AthenaDialog.dismiss();
    ModelViewModel(ref).destroyModel(model);
  }

  @override
  void dispose() {
    keyController.dispose();
    urlController.dispose();
    super.dispose();
  }

  void editModel(Model model) {
    MobileModelFormRoute(model: model).push(context);
  }

  @override
  void initState() {
    super.initState();
    keyController.text = widget.provider.key;
    urlController.text = widget.provider.url;
  }

  void openBottomSheet(Model model) {
    HapticFeedback.heavyImpact();
    var editTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedPencilEdit02),
      title: 'Connect',
      onTap: () => checkConnection(model),
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () => destroyModel(model),
    );
    var children = [editTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }

  Future<void> updateProvider() async {
    var viewModel = ProviderViewModel(ref);
    var provider = widget.provider.copyWith(
      enabled: true,
      key: keyController.text,
      url: urlController.text,
    );
    viewModel.updateProvider(provider);
  }

  Widget _buildModelFormLabel(BuildContext context) {
    var newModelButton = AthenaTextButton(
      onTap: () => createModel(context),
      text: 'New',
    );
    var label = AthenaFormTileLabel.large(
      title: 'Models',
      trailing: newModelButton,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: label,
    );
  }

  Widget _buildSubmitButton() {
    var textStyle = TextStyle(
      color: ColorUtil.FF161616,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var button = AthenaPrimaryButton(
      onTap: updateProvider,
      child: Center(child: Text('Update', style: textStyle)),
    );
    return Padding(padding: const EdgeInsets.all(16), child: button);
  }

  Widget _buildTip() {
    var tipTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var tipText = Text(
      '查看${widget.provider.name}文档和模型获取更多详情',
      style: tipTextStyle,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: tipText,
    );
  }
}
