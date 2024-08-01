import 'package:athena/component/divider.dart';
import 'package:athena/provider/setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileTile extends StatefulWidget {
  const ProfileTile({super.key});

  @override
  State<ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<ProfileTile> {
  bool clicked = false;
  OverlayEntry? entry;
  final link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryContainer = colorScheme.primaryContainer;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context),
      child: CompositedTransformTarget(
        link: link,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: clicked ? primaryContainer : null,
          ),
          padding: const EdgeInsets.all(8),
          child: const Row(children: [
            _Avatar(),
            SizedBox(width: 8),
            Expanded(child: _Name())
          ]),
        ),
      ),
    );
  }

  void handleTap(BuildContext context) {
    setState(() {
      clicked = !clicked;
    });
    entry = OverlayEntry(builder: (context) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: removeEntry,
        child: SizedBox.expand(
          child: UnconstrainedBox(
            child: CompositedTransformFollower(
              followerAnchor: Alignment.bottomLeft,
              link: link,
              offset: const Offset(24, 0),
              targetAnchor: Alignment.bottomRight,
              child: _Dialog(onTap: removeEntry),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(entry!);
  }

  void removeEntry() {
    entry?.remove();
    entry = null;
    setState(() {
      clicked = false;
    });
  }
}

class _Dialog extends StatelessWidget {
  final void Function()? onTap;
  const _Dialog({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer(builder: (context, ref, child) {
            final setting = ref.watch(settingNotifierProvider).value;
            final key = setting?.key ?? '';
            String title = 'Set API Key First';
            if (key.isNotEmpty) {
              title = '${key.substring(0, 1)}***********************';
            }
            if (key.length > 24) {
              final leading = key.substring(0, 6);
              final tailing = key.substring(key.length - 6, key.length);
              title = '$leading************$tailing';
            }
            return _ListTile(enabled: false, title: title);
          }),
          const ADivider(width: 200),
          _ListTile(title: 'Setting', onTap: () => handleTap(context)),
        ],
      ),
    );
  }

  void handleTap(BuildContext context) {
    onTap?.call();
    showDialog(context: context, builder: (context) => const _Setting());
  }
}

class _Setting extends StatelessWidget {
  const _Setting();

  @override
  Widget build(BuildContext context) {
    final backgroundColor = getBackgroundColor(context);
    final borderColor = getBorderColor(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        width: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              child: const Text('Setting'),
            ),
            const SizedBox(height: 8),
            const Text('Account'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: backgroundColor,
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Row(
                    children: [
                      SizedBox(width: 200, child: Text('API Key')),
                      Expanded(child: _Key())
                    ],
                  ),
                  const ADivider(),
                  const Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: Text('API Proxy Url (Optional)'),
                      ),
                      Expanded(child: _Url())
                    ],
                  ),
                  const ADivider(),
                  const Row(
                    children: [
                      SizedBox(width: 200, child: Text('Models')),
                      Expanded(child: _Url())
                    ],
                  ),
                  const ADivider(),
                  Row(
                    children: [
                      SizedBox(width: 200, child: Text('Check Connection')),
                      const Spacer(),
                      OutlinedButton(onPressed: () {}, child: Text('Check'))
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Application'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Theme.of(context).colorScheme.surfaceContainer,
              ),
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 200, child: Text('Dark Mode')),
                      const Spacer(),
                      Consumer(builder: (context, ref, child) {
                        final setting =
                            ref.watch(settingNotifierProvider).value;
                        final darkMode = setting?.darkMode ?? false;
                        return Switch.adaptive(
                            value: darkMode,
                            onChanged: (value) => toggleMode(ref, value));
                      })
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainer;
  }

  Color getBorderColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.2);
  }

  void toggleMode(WidgetRef ref, bool value) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.toggleMode();
  }
}

class _Key extends StatefulWidget {
  const _Key({
    super.key,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

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

  void handleSubmitted(WidgetRef ref, String value) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.updateKey(value);
  }
}

class _Url extends StatefulWidget {
  const _Url({super.key});

  @override
  State<_Url> createState() => _UrlState();
}

class _UrlState extends State<_Url> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

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

  void handleSubmitted(WidgetRef ref, String value) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.updateUrl(value);
  }
}

class _ListTile extends StatelessWidget {
  final bool enabled;
  final void Function()? onTap;
  final String title;
  const _ListTile({this.enabled = true, this.onTap, required this.title});

  @override
  Widget build(BuildContext context) {
    final color = getColor(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: SizedBox(
        height: 24,
        width: 200,
        child: Text(
          title,
          style: TextStyle(
            color: color,
            decoration: TextDecoration.none,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Color getColor(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    if (!enabled) return color.withOpacity(0.2);
    return color;
  }

  void handleTap() {
    if (!enabled) return;
    onTap?.call();
  }
}

class _Name extends StatelessWidget {
  const _Name();

  @override
  Widget build(BuildContext context) {
    final color = getColor(context);
    return Text('Cals Ranna', style: TextStyle(color: color));
  }

  Color getColor(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimary;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    final color = getColor(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      height: 32,
      width: 32,
      child: const Text('CA'),
    );
  }

  Color getColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
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
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration.collapsed(
          hintText: placeholder,
          hintStyle: TextStyle(
            color: color.withOpacity(0.2),
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
