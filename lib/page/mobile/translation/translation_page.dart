import 'package:athena/component/language_selector.dart';
import 'package:athena/component/translation_list_tile.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/translation.dart';
import 'package:athena/schema/translation.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/translation.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/divider.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileTranslationPage extends ConsumerStatefulWidget {
  const MobileTranslationPage({super.key});

  @override
  ConsumerState<MobileTranslationPage> createState() =>
      _MobileTranslationPageState();
}

class _MobileTranslationPageState extends ConsumerState<MobileTranslationPage> {
  final controller = TextEditingController();
  late final viewModel = TranslationViewModel(ref);

  var id = 0;
  var source = 'Chinese';
  var target = 'English';

  @override
  Widget build(BuildContext context) {
    var exchangeButton = AthenaIconButton(
      icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
      onTap: exchangeSourceTarget,
    );
    var rowChildren = [
      Expanded(child: _buildLanguageButton(source, type: 'source')),
      SizedBox(width: 4),
      exchangeButton,
      SizedBox(width: 4),
      Expanded(child: _buildLanguageButton(target, type: 'target')),
    ];
    var sourceTextInput = AthenaInput(
      controller: controller,
      maxLines: 5,
      minLines: 5,
      placeholder: 'Source Text',
    );
    var listViewChildren = [
      Row(children: rowChildren),
      const SizedBox(height: 16),
      sourceTextInput,
      const SizedBox(height: 12),
      _buildTargetText(),
      const SizedBox(height: 16),
      AthenaDivider(color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2)),
      ..._buildTranslationListView(),
    ];
    var listView = ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: listViewChildren,
    );
    var columnChildren = [
      Expanded(child: listView),
      _buildTranslateButton(),
    ];
    return AthenaScaffold(
      appBar: AthenaAppBar(title: Text('Translation')),
      body: Column(children: columnChildren),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void exchangeSourceTarget() {
    var temp = source;
    source = target;
    target = temp;
    setState(() {});
  }

  void openLanguageSelector(String type) {
    var mobileLanguageSelectDialog = MobileLanguageSelectDialog(
      onTap: type == 'source' ? _updateSource : _updateTarget,
    );
    AthenaDialog.show(mobileLanguageSelectDialog);
  }

  Future<void> translate() async {
    if (controller.text.isEmpty) {
      AthenaDialog.message('Please input source text');
      return;
    }
    var streaming = ref.read(streamingNotifierProvider);
    if (streaming) return;
    var translation = Translation()
      ..source = source
      ..sourceText = controller.text
      ..target = target
      ..targetText = '';
    var translationId = await viewModel.storeTranslation(translation);
    setState(() {
      id = translationId;
    });
    viewModel.translate(translation.copyWith(id: id));
  }

  Widget _buildLanguageButton(String language, {required String type}) {
    var children = [
      Text(language),
      const SizedBox(width: 8),
      Icon(HugeIcons.strokeRoundedArrowDown01, size: 16)
    ];
    var row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
    return AthenaPrimaryButton(
      onTap: () => openLanguageSelector(type),
      showShadow: false,
      child: row,
    );
  }

  Widget _buildTargetText() {
    if (id == 0) return const SizedBox();
    var provider = translationNotifierProvider(id);
    var translation = ref.watch(provider).value;
    if (translation == null) return const SizedBox();
    return TranslationListTile(showSourceText: false, translation: translation);
  }

  Widget _buildTitle() {
    const titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Text('History', style: titleTextStyle),
      const Spacer(),
      AthenaTextButton(onTap: viewModel.destroyAllTranslations, text: 'Clear')
    ];
    return Row(children: children);
  }

  Widget _buildTranslateButton() {
    var streaming = ref.watch(streamingNotifierProvider);
    var indicator = CircularProgressIndicator(strokeWidth: 2);
    var children = [
      if (streaming) SizedBox(width: 16, height: 16, child: indicator),
      if (streaming) SizedBox(width: 8),
      Text('Translate'),
    ];
    var row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
    var padding = Padding(
      padding: const EdgeInsets.all(16),
      child: AthenaPrimaryButton(onTap: translate, child: row),
    );
    return SafeArea(top: false, child: padding);
  }

  List<Widget> _buildTranslationListView() {
    var provider = transitionsNotifierProvider;
    var translations = ref.watch(provider).value;
    if (translations == null) return [];
    var children = <Widget>[];
    children.add(_buildTitle());
    children.add(const SizedBox(height: 12));
    const labelTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    for (var translation in translations) {
      var icon = Icon(
        HugeIcons.strokeRoundedArrowRight02,
        color: ColorUtil.FFFFFFFF,
        size: 16,
      );
      var rowChildren = [
        Text(translation.source, style: labelTextStyle),
        const SizedBox(height: 12),
        icon,
        const SizedBox(height: 12),
        Text(translation.target, style: labelTextStyle),
      ];
      children.add(Row(children: rowChildren));
      children.add(const SizedBox(height: 4));
      children.add(TranslationListTile(translation: translation));
      children.add(const SizedBox(height: 12));
    }
    children.removeLast();
    return children;
  }

  void _updateSource(String source) {
    setState(() {
      this.source = source;
    });
  }

  void _updateTarget(String target) {
    setState(() {
      this.target = target;
    });
  }
}
