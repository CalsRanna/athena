import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/menu.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

@RoutePage()
class DesktopSettingAgentPage extends StatefulWidget {
  const DesktopSettingAgentPage({super.key});

  @override
  State<DesktopSettingAgentPage> createState() =>
      _DesktopSettingAgentPageState();
}

class _DesktopSettingAgentPageState extends State<DesktopSettingAgentPage> {
  final viewModel = GetIt.instance.get<SettingViewModel>();
  late final iterationsController = TextEditingController(
    text: viewModel.maxAgentIterations.value.toString(),
  );
  late final retriesController = TextEditingController(
    text: viewModel.maxRetries.value.toString(),
  );
  late final braveApiKeyController = TextEditingController(
    text: viewModel.braveApiKey.value,
  );

  int index = 0;

  @override
  void dispose() {
    iterationsController.dispose();
    retriesController.dispose();
    braveApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _buildListView(),
      Expanded(child: _buildContentView()),
    ]);
  }

  Widget _buildListView() {
    var items = ['General', 'Tools'];
    var borderSide = BorderSide(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
    );
    Widget child = ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, i) => DesktopMenuTile(
        active: index == i,
        label: items[i],
        onTap: () => setState(() => index = i),
      ),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
    return Container(
      decoration: BoxDecoration(border: Border(right: borderSide)),
      width: 240,
      child: child,
    );
  }

  Widget _buildContentView() {
    return switch (index) {
      0 => _buildGeneralView(),
      1 => _buildToolsView(),
      _ => const SizedBox(),
    };
  }

  Widget _buildGeneralView() {
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var iterationsRow = Row(children: [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Max Iterations')),
      Expanded(
        child: AthenaInput(controller: iterationsController, placeholder: '100'),
      ),
    ]);
    var retriesRow = Row(children: [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Max Retries')),
      Expanded(
        child: AthenaInput(controller: retriesController, placeholder: '10'),
      ),
    ]);
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var saveButton = AthenaPrimaryButton(
      onTap: _saveGeneral,
      child: Padding(padding: edgeInsets, child: const Text('Save')),
    );
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      children: [
        Text('General', style: titleTextStyle),
        const SizedBox(height: 12),
        iterationsRow,
        const SizedBox(height: 12),
        retriesRow,
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [saveButton]),
      ],
    );
  }

  Widget _buildToolsView() {
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var braveApiRow = Row(children: [
      SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Brave API Key')),
      Expanded(
        child: AthenaInput(
          controller: braveApiKeyController,
          placeholder: 'BSA...',
        ),
      ),
    ]);
    var tipTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var saveButton = AthenaPrimaryButton(
      onTap: _saveTools,
      child: Padding(padding: edgeInsets, child: const Text('Save')),
    );
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      children: [
        Text('Tools', style: titleTextStyle),
        const SizedBox(height: 12),
        braveApiRow,
        const SizedBox(height: 12),
        Text(
          'Required for web_search tool. Get a free key at brave.com/search/api/',
          style: tipTextStyle,
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [saveButton]),
      ],
    );
  }

  Future<void> _saveGeneral() async {
    final iterations = int.tryParse(iterationsController.text.trim());
    if (iterations == null || iterations < 1) {
      AthenaDialog.warning('Max Iterations must be a valid number (minimum 1)');
      return;
    }
    final retries = int.tryParse(retriesController.text.trim());
    if (retries == null || retries < 1) {
      AthenaDialog.warning('Max Retries must be a valid number (minimum 1)');
      return;
    }
    await viewModel.updateMaxAgentIterations(iterations);
    await viewModel.updateMaxRetries(retries);
    if (!mounted) return;
    AthenaDialog.success('Settings saved');
  }

  Future<void> _saveTools() async {
    await viewModel.updateBraveApiKey(braveApiKeyController.text.trim());
    if (!mounted) return;
    AthenaDialog.success('API key saved');
  }
}
