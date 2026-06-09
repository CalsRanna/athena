import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

@RoutePage()
class MobileAgentPage extends StatefulWidget {
  const MobileAgentPage({super.key});

  @override
  State<MobileAgentPage> createState() => _MobileAgentPageState();
}

class _MobileAgentPageState extends State<MobileAgentPage> {
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

  @override
  void dispose() {
    iterationsController.dispose();
    retriesController.dispose();
    braveApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AthenaScaffold(
      appBar: AthenaAppBar(title: const Text('Agent Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildGeneralSection(),
            const SizedBox(height: 32),
            _buildToolsSection(),
            SafeArea(top: false, child: const SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSection() {
    const tipTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AthenaFormTileLabel.large(title: 'Max Iterations'),
        const SizedBox(height: 12),
        AthenaInput(
          controller: iterationsController,
          placeholder: '100',
        ),
        const SizedBox(height: 4),
        Text(
          'Maximum number of agent loop iterations (default: 100)',
          style: tipTextStyle,
        ),
        const SizedBox(height: 16),
        AthenaFormTileLabel.large(title: 'Max Retries'),
        const SizedBox(height: 12),
        AthenaInput(
          controller: retriesController,
          placeholder: '10',
        ),
        const SizedBox(height: 4),
        Text(
          'Maximum network retry attempts for LLM API calls (default: 10)',
          style: tipTextStyle,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: AthenaPrimaryButton(
            onTap: _saveGeneral,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Save'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolsSection() {
    const tipTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AthenaFormTileLabel.large(title: 'Brave API Key'),
        const SizedBox(height: 12),
        AthenaInput(
          controller: braveApiKeyController,
          placeholder: 'BSA...',
        ),
        const SizedBox(height: 8),
        Text(
          'Required for web_search. Get a free key at brave.com/search/api/',
          style: tipTextStyle,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: AthenaPrimaryButton(
            onTap: _saveTools,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Save'),
            ),
          ),
        ),
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
