import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_field.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/scaffold.dart';
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
  late final retriesController = TextEditingController(
    text: viewModel.maxRetries.value.toString(),
  );
  late final braveApiKeyController = TextEditingController(
    text: viewModel.braveApiKey.value,
  );

  @override
  void dispose() {
    retriesController.dispose();
    braveApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AthenaScaffold(
      appBar: const AthenaAppBar(title: Text('Agent Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildGeneralSection(context),
            const SizedBox(height: 32),
            _buildToolsSection(context),
            const SafeArea(top: false, child: SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AthenaFormField(
          label: 'Max Retries',
          control: AthenaInput(
            controller: retriesController,
            placeholder: '10',
          ),
          description:
              'Maximum network retry attempts for LLM API calls (default: 10)',
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

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AthenaFormField(
          label: 'Brave API Key',
          control: AthenaInput(
            controller: braveApiKeyController,
            obscureText: true,
            placeholder: 'BSA...',
          ),
          description:
              'Required for web_search. Get a free key at brave.com/search/api/',
          descriptionGap: 8,
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
    final retries = int.tryParse(retriesController.text.trim());
    if (retries == null || retries < 1) {
      AthenaDialog.warning('Max Retries must be a valid number (minimum 1)');
      return;
    }
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
