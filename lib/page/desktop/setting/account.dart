import 'package:athena/provider/setting.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopSettingAccountPage extends ConsumerStatefulWidget {
  const DesktopSettingAccountPage({super.key});

  @override
  ConsumerState<DesktopSettingAccountPage> createState() =>
      _DesktopSettingAccountPageState();
}

class _DesktopSettingAccountPageState
    extends ConsumerState<DesktopSettingAccountPage> {
  final keyController = TextEditingController();
  final urlController = TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> _initState() async {
    var provider = settingNotifierProvider;
    var setting = await ref.read(provider.future);
    keyController.text = setting.key;
    urlController.text = setting.url;
  }

  @override
  void dispose() {
    keyController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildKeyInput(),
      const SizedBox(height: 12),
      _buildUrlInput(),
      const SizedBox(height: 12),
      _buildButtons(),
    ];
    var body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Column(children: children),
    );
    return AScaffold(body: body);
  }

  Widget _buildKeyInput() {
    const label = SizedBox(width: 320, child: AFormTileLabel(title: 'API Key'));
    var children = [label, Expanded(child: AInput(controller: keyController))];
    return Row(children: children);
  }

  Widget _buildUrlInput() {
    const label = SizedBox(
      width: 320,
      child: AFormTileLabel(title: 'API Proxy Url (Optional)'),
    );
    var children = [label, Expanded(child: AInput(controller: urlController))];
    return Row(children: children);
  }

  Widget _buildButtons() {
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var storeButton = APrimaryButton(
      onTap: storeSetting,
      child: Padding(padding: edgeInsets, child: const Text('Store')),
    );
    var children = [
      if (loading) CircularProgressIndicator(color: Colors.white),
      ATextButton(text: 'Connect', onTap: connect),
      const SizedBox(width: 12),
      storeButton,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: children,
    );
  }

  Future<void> connect() async {
    setState(() {
      loading = true;
    });
    var container = ProviderScope.containerOf(context);
    var provider = settingNotifierProvider;
    var notifier = container.read(provider.notifier);
    // var message = await notifier.connect();
    setState(() {
      loading = false;
    });
    // ADialog.message(message);
  }

  void storeSetting() {
    var container = ProviderScope.containerOf(context);
    var provider = settingNotifierProvider;
    var notifier = container.read(provider.notifier);
    notifier.store(
      key: keyController.text,
      url: urlController.text,
    );
    ADialog.message('Setting stored successfully');
  }
}
