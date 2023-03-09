import 'package:athena/creator/global.dart';
import 'package:athena/creator/setting.dart';
import 'package:athena/model/setting.dart';
import 'package:creator/creator.dart';
import 'package:creator_watcher/creator_watcher.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';

class SettingWidget extends StatelessWidget {
  const SettingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return EmitterWatcher<Setting>(
      emitter: settingEmitter,
      builder: (context, setting) => ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.generating_tokens_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            subtitle: Text(
              'In order to protect the security of your account, OpenAI may also automatically rotate any API key that we\'ve found has leaked publicly.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
            title: const Text('SECRET KEY'),
            trailing: const Icon(Icons.chevron_right_outlined),
            onTap: () => updateSecretKey(context, setting.secretKey),
          ),
          SwitchListTile.adaptive(
            secondary: Icon(
              setting.proxyEnabled
                  ? Icons.key_outlined
                  : Icons.key_off_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            subtitle: Text(
              setting.proxy,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
            title: const Text('PROXY'),
            value: setting.proxyEnabled,
            onChanged: (value) => changeProxyEnabled(context, value),
          ),
        ],
      ),
    );
  }

  void updateSecretKey(BuildContext context, String? secretKey) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SecretKeyBottomsheet(secretKey: secretKey),
    );
  }

  void changeProxyEnabled(BuildContext context, bool value) async {
    try {
      final ref = context.ref;
      final isar = await ref.read(isarEmitter);
      final setting = await isar.settings.where().findFirst();
      setting!.proxyEnabled = value;
      setting.proxy = Setting().proxy;
      await isar.writeTxn(() async {
        isar.settings.put(setting);
      });
      ref.emit(settingEmitter, setting);
    } catch (error) {
      Logger().e(error);
    }
  }
}

class _SecretKeyBottomsheet extends StatefulWidget {
  const _SecretKeyBottomsheet({this.secretKey});

  final String? secretKey;

  @override
  State<_SecretKeyBottomsheet> createState() => __SecretKeyBottomsheetState();
}

class __SecretKeyBottomsheetState extends State<_SecretKeyBottomsheet> {
  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.text = widget.secretKey ?? '';
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: controller,
          decoration: const InputDecoration(
              hintText: 'PLEASE ENTER YOUR SECRET KEY HERE'),
          onSubmitted: handleSubmitted,
          onTapOutside: (event) => FocusScope.of(context).unfocus(),
        ),
        const SizedBox(height: 8),
        Text(
          'Do not share your API key with others, or expose it in the browser or other client-side code.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.secondary),
        )
      ],
    );
  }

  void handleSubmitted(String value) async {
    final ref = context.ref;
    final focusScope = FocusScope.of(context);
    final isar = await ref.read(isarEmitter);
    await isar.writeTxn(() async {
      var setting = await isar.settings.where().findFirst() ?? Setting();
      setting.secretKey = value;
      isar.settings.put(setting);
      ref.emit(settingEmitter, setting);
      focusScope.unfocus();
    });
  }
}
