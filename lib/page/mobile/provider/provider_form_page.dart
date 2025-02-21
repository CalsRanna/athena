import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/view_model/model.dart';
import 'package:athena/view_model/provider.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      AFormTileLabel.large(title: 'API Key'),
      SizedBox(height: 12),
      AInput(controller: keyController),
      SizedBox(height: 16),
      AFormTileLabel.large(title: 'API Url'),
      SizedBox(height: 12),
      AInput(controller: urlController),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AScaffold(
      appBar: AAppBar(title: Text(widget.provider.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: column,
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AFormTileLabel.large(
                    title: 'Models',
                    trailing: ATextButton(onTap: () {}, text: 'New'),
                  ),
                ),
                SizedBox(height: 12),
                _buildModelHorizontalList(),
                SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Tap a model to check connection',
                    style: TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          _buildSubmitButton()
        ],
      ),
    );
  }

  Future<void> checkConnection(Model model) async {
    var viewModel = ModelViewModel(ref);
    var message = await viewModel.checkConnection(model);
    ADialog.message(message);
  }

  @override
  void dispose() {
    keyController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    keyController.text = widget.provider.key;
    urlController.text = widget.provider.url;
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

  Widget _buildModelHorizontalList() {
    var providerId = widget.provider.id;
    var models = ref.watch(modelsForNotifierProvider(providerId)).valueOrNull;
    if (models == null) return const SizedBox();
    if (models.isEmpty) return const SizedBox();

    List<Widget> children1 = [];
    List<Widget> children2 = [];
    List<Widget> children3 = [];
    for (var i = 0; i < models.length; i++) {
      var tile = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => checkConnection(models[i]),
        child: ATag(text: models[i].name),
      );
      if (i % 3 == 0) children1.add(tile);
      if (i % 3 == 1) children2.add(tile);
      if (i % 3 == 2) children3.add(tile);
    }
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Row(spacing: 12, children: children1),
        Row(spacing: 12, children: children2),
        Row(spacing: 12, children: children3),
      ],
    );
    return SizedBox(
      height: 164,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        child: column,
      ),
    );
  }

  Widget _buildSubmitButton() {
    var textStyle = TextStyle(
      color: Color(0xFF161616),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var button = APrimaryButton(
      onTap: updateProvider,
      child: Center(child: Text('Update', style: textStyle)),
    );
    var padding = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: button,
    );
    return SafeArea(child: padding);
  }
}
