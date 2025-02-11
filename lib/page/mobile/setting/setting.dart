import 'package:athena/page/mobile/setting/key.dart';
import 'package:athena/page/mobile/setting/url.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const children = [
      _GroupLabel('Account'),
      _Key(),
      _Url(),
      _Model(),
      _Connect(),
      _GroupLabel('Experimental'),
      _Latex(),
    ];
    const column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return const AScaffold(
      appBar: AAppBar(title: Text('Setting')),
      body: SingleChildScrollView(child: column),
    );
  }
}

class _Connect extends StatelessWidget {
  const _Connect();

  @override
  Widget build(BuildContext context) {
    const hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedLink01,
      color: Color(0xffffffff),
    );
    return ListTile(
      onTap: () => connect(context),
      title: Text('Connect'),
      titleTextStyle: TextStyle(fontSize: 16, color: Color(0xffffffff)),
      trailing: hugeIcon,
    );
  }

  Future<void> connect(BuildContext context) async {
    // ADialog.loading();
    // var container = ProviderScope.containerOf(context);
    // var provider = settingNotifierProvider;
    // var notifier = container.read(provider.notifier);
    // var message = await notifier.connect();
    // ADialog.dismiss();
    // ADialog.success(message);
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: const Color(0xffffffff).withValues(alpha: 0.2),
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(text, style: textStyle),
    );
  }
}

class _Key extends ConsumerWidget {
  const _Key();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingNotifierProvider).valueOrNull;
    if (setting == null) return const _SettingTile(title: 'API Key');
    final key = setting.key.isNotEmpty ? setting.key : 'API Key Not Set Yet';
    return _SettingTile(
      title: 'API Key',
      trailing: key,
      onTap: () => handleTap(context),
    );
  }

  void handleTap(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return const APIKeyPage();
    }));
  }
}

class _Latex extends ConsumerWidget {
  const _Latex();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingNotifierProvider).valueOrNull;
    const textStyle = TextStyle(fontSize: 16, color: Color(0xffffffff));
    return SwitchListTile.adaptive(
      subtitle: const Text('May cause render issues.'),
      title: const Text('Latex', style: textStyle),
      value: setting?.latex ?? false,
      onChanged: (value) => toggleLatex(ref, value),
    );
  }

  void toggleLatex(WidgetRef ref, bool value) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.toggleLatex();
  }
}

class _Model extends ConsumerWidget {
  const _Model();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingNotifierProvider).valueOrNull;
    return _SettingTile(
      onTap: () => handleTap(context),
      title: 'Default Model',
      trailing: setting?.model ?? '',
    );
  }

  void handleTap(BuildContext context) {
    MobileModelListRoute().push(context);
  }
}

class _SettingTile extends StatelessWidget {
  final void Function()? onTap;
  final String title;
  final String? trailing;
  const _SettingTile({this.onTap, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xffffffff);
    const hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedArrowRight01,
      color: color,
    );
    final text = Text(
      trailing ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color.withValues(alpha: 0.2)),
      textAlign: TextAlign.end,
    );
    final children = [
      Text(title, style: const TextStyle(fontSize: 16, color: color)),
      const SizedBox(width: 16),
      Expanded(child: text),
      hugeIcon,
    ];
    return ListTile(title: Row(children: children), onTap: onTap);
  }
}

class _Url extends ConsumerWidget {
  const _Url();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingNotifierProvider).valueOrNull;
    if (setting == null) {
      return const _SettingTile(title: 'API Proxy Url (Optional)');
    }
    return _SettingTile(
      title: 'API Proxy Url (Optional)',
      trailing: setting.url,
      onTap: () => handleTap(context),
    );
  }

  void handleTap(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return const APIUrlPage();
    }));
  }
}
