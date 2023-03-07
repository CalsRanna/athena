import 'package:athena/creator/global.dart';
import 'package:athena/model/setting.dart';
import 'package:creator/creator.dart';
import 'package:creator_watcher/creator_watcher.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

class SettingWidget extends StatelessWidget {
  const SettingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        EmitterWatcher<String>(
          builder: (context, secretKey) => ListTile(
            leading: Icon(
              Icons.key_outlined,
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
            onTap: () => updateSecretKey(context, secretKey),
          ),
          emitter: secretKeyEmitter,
        )
      ],
    );
  }

  void updateSecretKey(BuildContext context, String? secretKey) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SecretKeyBottomsheet(secretKey: secretKey),
    );
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
    // controller.value = TextEditingValue(text: widget.secretKey ?? '');
    controller.text = widget.secretKey ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    final isar = ref.read(isarEmitter.asyncData).data;
    await isar?.writeTxn(() async {
      var setting = await isar.settings.where().findFirst() ?? Setting();
      setting.secretKey = value;
      isar.settings.put(setting);
      ref.emit(secretKeyEmitter, value);
      focusScope.unfocus();
    });
  }
}
