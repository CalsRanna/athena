import 'package:athena/component/divider.dart';
import 'package:athena/component/dropdown.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) {
    final borderColor = getBorderColor(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        width: 600,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              child: const Text('Setting'),
            ),
            const Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    Text('Account'),
                    SizedBox(height: 8),
                    _Account(),
                    SizedBox(height: 8),
                    Text('Application'),
                    SizedBox(height: 8),
                    _DarkMode(),
                    SizedBox(height: 8),
                    Text('Experimental'),
                    SizedBox(height: 8),
                    _Experimental()
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color getBorderColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.2);
  }
}

class _Account extends StatelessWidget {
  const _Account();

  @override
  Widget build(BuildContext context) {
    return _Card(
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
              SizedBox(width: 200, child: Text('API Proxy Url (Optional)')),
              Expanded(child: _Url())
            ],
          ),
          const ADivider(),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 200, child: Text('Models')),
              Expanded(child: _Models())
            ],
          ),
          const ADivider(),
          const Row(
            children: [
              SizedBox(width: 200, child: Text('Default Model')),
              Expanded(child: _Model())
            ],
          ),
          const ADivider(),
          Row(
            children: [
              const SizedBox(width: 200, child: Text('Check Connection')),
              const Spacer(),
              OutlinedButton(onPressed: () {}, child: const Text('Check'))
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: child,
    );
  }
}

class _DarkMode extends StatelessWidget {
  const _DarkMode();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final setting = ref.watch(settingNotifierProvider).value;
      final darkMode = setting?.darkMode ?? false;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => toggleMode(ref, !darkMode),
        child: _Card(child: getTile(darkMode, ref)),
      );
    });
  }

  Row getTile(bool darkMode, WidgetRef ref) {
    return Row(
      children: [
        const SizedBox(width: 200, child: Text('Dark Mode')),
        const Spacer(),
        Switch(value: darkMode, onChanged: (value) => toggleMode(ref, value))
      ],
    );
  }

  void toggleMode(WidgetRef ref, bool value) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.toggleMode();
  }
}

class _Experimental extends StatelessWidget {
  const _Experimental();

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final setting = ref.watch(settingNotifierProvider).value;
      final latex = setting?.latex ?? false;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => toggleLatex(ref, !latex),
        child: _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [getTile(latex, ref), getTip(context)],
          ),
        ),
      );
    });
  }

  Row getTile(bool latex, WidgetRef ref) {
    return Row(
      children: [
        const SizedBox(width: 200, child: Text('LaTex')),
        const Spacer(),
        Switch(value: latex, onChanged: (value) => toggleLatex(ref, value))
      ],
    );
  }

  Text getTip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.onSurface.withOpacity(0.4);
    return Text(
      'May cause render issues.',
      style: TextStyle(color: color, fontSize: 10),
    );
  }

  void toggleLatex(WidgetRef ref, bool value) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.toggleLatex();
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

class _Model extends StatefulWidget {
  const _Model();

  @override
  State<_Model> createState() => _ModelState();
}

class _ModelState extends State<_Model> {
  bool show = false;
  OverlayEntry? entry;
  LayerLink link = LayerLink();
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: CompositedTransformTarget(
        link: link,
        child: SizedBox(
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Consumer(builder: (context, ref, child) {
                  final setting = ref.watch(settingNotifierProvider).value;
                  String model = 'Not Set';
                  if (setting?.model.isNotEmpty == true) {
                    model = setting!.model;
                  }
                  return Text(
                    model,
                    style: TextStyle(color: onSurface.withOpacity(0.4)),
                  );
                }),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: show ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowDown01,
                  color: onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void handleChanged(WidgetRef ref, Model model) {
    final notifier = ref.read(settingNotifierProvider.notifier);
    notifier.updateModel(model.value);
    removeEntry();
  }

  void handleTap() {
    setState(() {
      show = !show;
    });
    entry = OverlayEntry(builder: (context) {
      return Consumer(builder: (context, ref, child) {
        return ModelsDropdown(
          link: link,
          offset: Offset.zero,
          onChanged: (model) => handleChanged(ref, model),
          onClose: removeEntry,
        );
      });
    });
    Overlay.of(context).insert(entry!);
  }

  void removeEntry() {
    entry?.remove();
    entry = null;
    setState(() {
      show = false;
    });
  }
}

class _Models extends StatelessWidget {
  const _Models();

  @override
  Widget build(BuildContext context) {
    final color = getColor(context);
    return Consumer(builder: (context, ref, child) {
      final models = ref.watch(modelsNotifierProvider).value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            width: double.infinity,
            child: Wrap(
              runSpacing: 4,
              spacing: 4,
              children: getChildren(context, models),
            ),
          ),
          const SizedBox(height: 8),
          const _ModelUpdater(),
        ],
      );
    });
  }

  List<Widget> getChildren(BuildContext context, List<Model>? models) {
    if (models == null) return [];
    return models
        .map(
          (model) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(model.name),
          ),
        )
        .toList();
  }

  Color getColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }
}

class _ModelUpdater extends StatefulWidget {
  const _ModelUpdater();

  @override
  State<_ModelUpdater> createState() => _ModelUpdaterState();
}

class _ModelUpdaterState extends State<_ModelUpdater> {
  bool loading = false;
  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (loading)
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 1),
            ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => handleTap(ref),
            child: const Text('Get Models'),
          ),
        ],
      );
    });
  }

  void handleTap(WidgetRef ref) async {
    setState(() {
      loading = true;
    });
    final notifier = ref.read(modelsNotifierProvider.notifier);
    await notifier.getModels();
    setState(() {
      loading = false;
    });
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
