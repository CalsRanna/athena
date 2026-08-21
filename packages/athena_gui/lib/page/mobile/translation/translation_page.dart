import 'package:athena_gui/component/language_selector.dart';
import 'package:athena_gui/component/translation_list_tile.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/entity/translation_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/translation_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/divider.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileTranslationPage extends StatefulWidget {
  /// 从 Shortcut 进入时绑定的专属 Sentinel（能力配置）。
  final SentinelEntity? sentinel;
  const MobileTranslationPage({super.key, this.sentinel});

  @override
  State<MobileTranslationPage> createState() => _MobileTranslationPageState();
}

class _MobileTranslationPageState extends State<MobileTranslationPage> {
  final controller = TextEditingController();
  late final viewModel = GetIt.instance<TranslationViewModel>();

  final _translationId = signal('');
  final _source = signal('Chinese');
  final _target = signal('English');

  @override
  void initState() {
    super.initState();
    // Shortcut 入口：注入绑定的专属 Sentinel 作为翻译能力配置
    viewModel.setBoundSentinel(widget.sentinel);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var exchangeButton = AthenaIconButton(
      icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
      onTap: exchangeSourceTarget,
    );
    var rowChildren = [
      Expanded(child: _buildLanguageButton(_source.value, type: 'source')),
      SizedBox(width: 4),
      exchangeButton,
      SizedBox(width: 4),
      Expanded(child: _buildLanguageButton(_target.value, type: 'target')),
    ];
    var sourceTextInput = AthenaInput(
      controller: controller,
      maxLines: 5,
      minLines: 5,
      placeholder: 'Source Text',
    );
    var listViewChildren = [
      Row(children: rowChildren),
      SizedBox(height: 16),
      sourceTextInput,
      SizedBox(height: 4),
      _buildTargetText(),
      SizedBox(height: 16),
      AthenaDivider(color: colors.borderFaint.withValues(alpha: 0.2)),
      ..._buildTranslationListView(),
    ];
    var listView = ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: listViewChildren,
    );
    var columnChildren = [Expanded(child: listView), _buildTranslateButton()];
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
    var temp = _source.value;
    _source.value = _target.value;
    _target.value = temp;
  }

  void openLanguageSelector(String type) {
    var mobileLanguageSelectDialog = MobileLanguageSelectDialog(
      onTap: type == 'source' ? _updateSource : _updateTarget,
    );
    AthenaDialog.show(mobileLanguageSelectDialog);
  }

  Future<void> translate() async {
    if (controller.text.isEmpty) {
      AthenaDialog.warning('Please input source text');
      return;
    }
    var streaming = viewModel.streaming.value;
    if (streaming) return;

    var translationId = await viewModel.createTranslation(
      _source.value,
      controller.text,
      _target.value,
    );
    _translationId.value = translationId;

    // 执行翻译
    var translation = TranslationEntity(
      id: translationId,
      source: _source.value,
      sourceText: controller.text,
      target: _target.value,
      targetText: '',
      createdAt: DateTime.now(),
    );
    await viewModel.performTranslation(translation);
  }

  Widget _buildLanguageButton(String language, {required String type}) {
    var children = [
      Text(language),
      const SizedBox(width: 8),
      Icon(HugeIcons.strokeRoundedArrowDown01, size: 16),
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
    if (_translationId.value.isEmpty) return const SizedBox();
    return Watch((context) {
      var translation = viewModel.translations.value
          .where((t) => t.id == _translationId.value)
          .firstOrNull;
      return TranslationListTile(
        showSourceText: false,
        translation:
            translation ??
            TranslationEntity(
              id: '',
              source: '',
              sourceText: '',
              target: '',
              targetText: '',
              createdAt: DateTime.now(),
            ),
      );
    });
  }

  Widget _buildTitle(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final titleTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Text('History', style: titleTextStyle),
      const Spacer(),
      AthenaTextButton(onTap: viewModel.deleteAllTranslations, text: 'Clear'),
    ];
    return Row(children: children);
  }

  Widget _buildTranslateButton() {
    return Watch((context) {
      var streaming = viewModel.streaming.value;
      var indicator = CircularProgressIndicator(strokeWidth: 2);
      var children = [
        Text('Translate'),
        if (streaming) SizedBox(width: 8),
        if (streaming) SizedBox(width: 16, height: 16, child: indicator),
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
    });
  }

  List<Widget> _buildTranslationListView() {
    return [
      Watch((context) {
        var translations = viewModel.translations.value;
        if (translations.isEmpty) return const SizedBox();
        final colors = Theme.of(context).extension<AthenaColors>()!;
        var children = <Widget>[];
        children.add(_buildTitle(context));
        children.add(const SizedBox(height: 12));
        final labelTextStyle = TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        );
        for (var translation in translations) {
          var icon = Icon(
            HugeIcons.strokeRoundedArrowRight02,
            color: colors.textPrimary,
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
        return Column(children: children);
      }),
    ];
  }

  void _updateSource(String source) {
    _source.value = source;
  }

  void _updateTarget(String target) {
    _target.value = target;
  }
}
