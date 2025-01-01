import 'package:athena/page/desktop/setting/component/tile.dart';
import 'package:athena/provider/setting.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopSettingAccountPage extends StatelessWidget {
  const DesktopSettingAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    var surface = colorScheme.surface;
    const children = [
      SettingTile(label: 'API Key', child: _Key()),
      SettingTile(label: 'API Proxy Url (Optional)', child: _Url()),
      SettingTile(label: 'Connection', child: _Connection()),
    ];
    return Container(
      color: surface,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: const Column(children: children),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key();

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final setting = ref.watch(settingNotifierProvider).value;
      final key = setting?.key ?? '';
      return _Input(
        controller: controller..text = key,
        onSubmitted: (value) => handleSubmitted(ref, value),
        placeholder: 'API Key',
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void handleSubmitted(WidgetRef ref, String value) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.updateKey(value);
  }
}

class _Url extends StatefulWidget {
  const _Url();

  @override
  State<_Url> createState() => _UrlState();
}

class _UrlState extends State<_Url> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final setting = ref.watch(settingNotifierProvider).value;
      final url = setting?.url ?? '';
      return _Input(
        controller: controller..text = url,
        onSubmitted: (value) => handleSubmitted(ref, value),
        placeholder: 'https://api.openai.com/v1',
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void handleSubmitted(WidgetRef ref, String value) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.updateUrl(value);
  }
}

class _Connection extends StatelessWidget {
  const _Connection();

  @override
  Widget build(BuildContext context) {
    var button = OutlinedButton(
      onPressed: () {},
      child: const Text('Check'),
    );
    return Align(alignment: Alignment.centerRight, child: button);
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String)? onSubmitted;
  final String placeholder;

  const _Input({
    required this.controller,
    this.onSubmitted,
    this.placeholder = '',
  });

  @override
  Widget build(BuildContext context) {
    final color = getColor(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration.collapsed(
          hintText: placeholder,
          hintStyle: TextStyle(
            color: color.withValues(alpha: 0.2),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 16 / 14,
          ),
        ),
        onSubmitted: onSubmitted,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 16 / 14,
        ),
      ),
    );
  }

  Color getColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }
}
