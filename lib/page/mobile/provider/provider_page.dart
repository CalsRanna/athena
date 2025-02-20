import 'package:athena/provider/model.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/view_model/provider.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileProvidePage extends ConsumerStatefulWidget {
  final schema.Provider provider;
  const MobileProvidePage({super.key, required this.provider});

  @override
  ConsumerState<MobileProvidePage> createState() => _MobileProvidePageState();
}

class _MobileProvidePageState extends ConsumerState<MobileProvidePage> {
  final keyController = TextEditingController();
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    keyController.text = widget.provider.key;
    urlController.text = widget.provider.url;
  }

  @override
  void dispose() {
    keyController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AScaffold(
      appBar: AAppBar(
        action: AIconButton(onTap: () {}, icon: HugeIcons.strokeRoundedAdd01),
        title: Text(widget.provider.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AFormTileLabel.large(title: 'API Key'),
                      SizedBox(height: 12),
                      AInput(controller: keyController),
                      SizedBox(height: 16),
                      AFormTileLabel.large(title: 'API Url'),
                      SizedBox(height: 12),
                      AInput(controller: urlController),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AFormTileLabel.large(title: 'Models'),
                ),
                SizedBox(height: 12),
                _buildModelHorizontalList(),
              ],
            ),
          ),
          _buildSubmitButton()
        ],
      ),
    );
  }

  Future<void> updateProvider() async {
    var viewModel = ProviderViewModel(ref);
    var provider = widget.provider.copyWith(
      key: keyController.text,
      url: urlController.text,
    );
    viewModel.updateProvider(provider);
  }

  Widget _buildSubmitButton() {
    var textStyle = TextStyle(
      color: Color(0xFF161616),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var button = APrimaryButton(
      onTap: updateProvider,
      child: Center(child: Text('Submit', style: textStyle)),
    );
    var padding = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: button,
    );
    return SafeArea(child: padding);
  }

  Widget _buildModelHorizontalList() {
    if (widget.provider == null) return const SizedBox();
    var providerId = widget.provider!.id;
    var models = ref.watch(modelsForNotifierProvider(providerId)).valueOrNull;
    if (models == null) return const SizedBox();
    if (models.isEmpty) return const SizedBox();

    List<Widget> children1 = [];
    List<Widget> children2 = [];
    List<Widget> children3 = [];
    for (var i = 0; i < models.length; i++) {
      var tile = ATag(text: models[i].name);
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
}
