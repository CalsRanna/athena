import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/provider.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileProviderNamePage extends ConsumerStatefulWidget {
  const MobileProviderNamePage({super.key});

  @override
  ConsumerState<MobileProviderNamePage> createState() =>
      _MobileProviderNamePageState();
}

class _MobileProviderNamePageState
    extends ConsumerState<MobileProviderNamePage> {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.requestFocus();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = AthenaIconButton(
      icon: HugeIcons.strokeRoundedTick02,
      onTap: handleTap,
    );
    var textField = TextField(
      controller: controller,
      cursorColor: ColorUtil.FFFFFFFF,
      decoration: const InputDecoration.collapsed(hintText: 'Name'),
      focusNode: focusNode,
      maxLines: null,
      style: const TextStyle(color: ColorUtil.FFFFFFFF),
    );
    return AthenaScaffold(
      appBar: AthenaAppBar(action: button, title: const Text('New Provider')),
      body: Padding(padding: const EdgeInsets.all(16), child: textField),
    );
  }

  Future<void> handleTap() async {
    if (controller.text.isEmpty) return;
    var viewModel = ProviderViewModel(ref);
    var provider = schema.Provider()
      ..enabled = true
      ..name = controller.text;
    viewModel.storeProvider(provider);
    AutoRouter.of(context).maybePop();
  }
}
