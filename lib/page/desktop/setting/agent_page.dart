import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/dialog.dart';
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
  late final braveApiKeyController = TextEditingController(
    text: viewModel.braveApiKey.value,
  );

  @override
  void dispose() {
    iterationsController.dispose();
    braveApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    final labelTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 14,
      height: 1.75,
    );
    final iterationsTitle = Text('Max Iterations', style: titleTextStyle);
    final braveApiTitle = Text('Brave Search API Key', style: titleTextStyle);
    final iterationsLabel = Text(
      'Maximum number of agent loop iterations (default: 100)',
      style: labelTextStyle,
    );
    final braveApiLabel = Text(
      'Required for web_search tool. Get a free key at brave.com/search/api/',
      style: labelTextStyle,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          iterationsTitle,
          iterationsLabel,
          Row(
            spacing: 16,
            children: [
              SizedBox(
                width: 120,
                child: AthenaInput(
                  controller: iterationsController,
                  placeholder: '100',
                  radius: 8,
                ),
              ),
              AthenaSecondaryButton.small(
                onTap: _saveIterations,
                child: Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          braveApiTitle,
          braveApiLabel,
          Row(
            spacing: 16,
            children: [
              SizedBox(
                width: 360,
                child: AthenaInput(
                  controller: braveApiKeyController,
                  placeholder: 'BSA...',
                  radius: 8,
                ),
              ),
              AthenaSecondaryButton.small(
                onTap: _saveBraveApiKey,
                child: Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveIterations() async {
    final value = int.tryParse(iterationsController.text.trim());
    if (value == null || value < 1) {
      if (!mounted) return;
      AthenaDialog.info('Please enter a valid number (minimum 1)');
      return;
    }
    await viewModel.updateMaxAgentIterations(value);
    if (!mounted) return;
    AthenaDialog.success('Max iterations updated');
  }

  Future<void> _saveBraveApiKey() async {
    await viewModel.updateBraveApiKey(braveApiKeyController.text.trim());
    if (!mounted) return;
    AthenaDialog.success('Brave API key updated');
  }
}
