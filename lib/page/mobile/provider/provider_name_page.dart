import 'package:athena/entity/provider_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/provider_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileProviderNamePage extends StatefulWidget {
  const MobileProviderNamePage({super.key});

  @override
  State<MobileProviderNamePage> createState() => _MobileProviderNamePageState();
}

class _MobileProviderNamePageState extends State<MobileProviderNamePage> {
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
    var viewModel = GetIt.instance<ProviderViewModel>();
    var provider = ProviderEntity(
      id: 0,
      enabled: true,
      name: controller.text,
      baseUrl: '',
      apiKey: '',
      createdAt: DateTime.now(),
    );
    await viewModel.storeProvider(provider);
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
  }
}
