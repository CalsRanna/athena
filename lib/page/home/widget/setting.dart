import 'package:athena/creator/setting.dart';
import 'package:athena/main.dart';
import 'package:athena/model/setting.dart';
import 'package:creator/creator.dart';
import 'package:creator_watcher/creator_watcher.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';

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
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            title: const Text('SECRET KEY'),
            trailing: const Icon(Icons.chevron_right_outlined),
            onTap: () => updateSecretKey(context, setting.secretKey),
          ),
          ListTile(
            leading: Icon(
              Icons.history_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('ATTACHED MESSAGES COUNT'),
            trailing: const Icon(Icons.chevron_right_outlined),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(
              Icons.tune_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('ADVANCED'),
            trailing: const Icon(Icons.chevron_right_outlined),
            onTap: () => navigate(context),
          )
        ],
      ),
    );
  }

  void updateSecretKey(BuildContext context, String? secretKey) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SecretKeyBottomSheet(secretKey: secretKey),
    );
  }

  void navigate(BuildContext context) {
    context.push('/setting/advanced');
  }
}

class _SecretKeyBottomSheet extends StatefulWidget {
  const _SecretKeyBottomSheet({this.secretKey});

  final String? secretKey;

  @override
  State<_SecretKeyBottomSheet> createState() => _SecretKeyBottomSheetState();
}

class _SecretKeyBottomSheetState extends State<_SecretKeyBottomSheet> {
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
            hintText: 'PLEASE ENTER YOUR SECRET KEY HERE',
          ),
          onSubmitted: handleSubmitted,
          onTapOutside: (event) => handleSubmitted(controller.text),
        ),
        const SizedBox(height: 8),
        Text(
          'Do not share your API key with others, or expose it in the browser or other client-side code.',
          style: Theme.of(context).textTheme.bodyMedium,
        )
      ],
    );
  }

  void handleSubmitted(String value) async {
    final ref = context.ref;
    final focusScope = FocusScope.of(context);
    await isar.writeTxn(() async {
      var setting = await isar.settings.where().findFirst() ?? Setting();
      setting.secretKey = value;
      isar.settings.put(setting);
      ref.emit(settingEmitter, setting);
      focusScope.unfocus();
    });
  }
}
