import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Max Iterations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              'Maximum number of agent loop iterations (default: 100)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: iterationsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '100',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AthenaSecondaryButton.small(
              onTap: _saveIterations,
              child: const Text('Save'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Max Retries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              'Maximum network retry attempts for LLM API calls (default: 10)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: retriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '10',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AthenaSecondaryButton.small(
              onTap: _saveRetries,
              child: const Text('Save'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Brave Search API Key',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              'Required for web_search. Get a free key at brave.com/search/api/',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: braveApiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'BSA...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AthenaSecondaryButton.small(
              onTap: _saveBraveApiKey,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveIterations() async {
    final value = int.tryParse(iterationsController.text.trim());
    if (value == null || value < 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number (minimum 1)'),
        ),
      );
      return;
    }
    await viewModel.updateMaxAgentIterations(value);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Max iterations updated')));
  }

  Future<void> _saveRetries() async {
    final value = int.tryParse(retriesController.text.trim());
    if (value == null || value < 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number (minimum 1)'),
        ),
      );
      return;
    }
    await viewModel.updateMaxRetries(value);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Max retries updated')));
  }

  Future<void> _saveBraveApiKey() async {
    await viewModel.updateBraveApiKey(braveApiKeyController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Brave API key updated')));
  }
}
