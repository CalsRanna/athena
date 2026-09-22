import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/provider_form_dialog.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/context_window_util.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/checkbox.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// 新建 / 编辑模型的对话框。
///
/// 纵向表单：必填的 id 与名称在上，元数据（发布日期、上下文、价格）两两
/// 并排，能力勾选在最后。价格只填每百万 token 的数字（`0.15`），展示时
/// 由界面补 `$…/M`。
class DesktopModelFormDialog extends StatefulWidget {
  final ModelEntity? model;
  final ProviderEntity provider;
  const DesktopModelFormDialog({super.key, required this.provider, this.model});

  @override
  State<DesktopModelFormDialog> createState() => _DesktopModelFormDialogState();
}

class _DesktopModelFormDialogState extends State<DesktopModelFormDialog> {
  final valueController = TextEditingController();
  final nameController = TextEditingController();
  final releasedAtController = TextEditingController();
  final contextController = TextEditingController();
  final inputController = TextEditingController();
  final outputController = TextEditingController();
  var supportReasoning = false;
  var supportVisual = false;
  String? idError;
  String? nameError;

  late final viewModel = GetIt.instance<ModelViewModel>();

  @override
  void initState() {
    super.initState();
    valueController.text = widget.model?.modelId ?? '';
    nameController.text = widget.model?.name ?? '';
    releasedAtController.text = _stripReleased(widget.model?.releasedAt ?? '');
    var cw = widget.model?.contextWindow ?? 0;
    contextController.text = cw > 0 ? formatContextWindow(cw) : '';
    inputController.text = _stripPrice(widget.model?.inputPrice ?? '');
    outputController.text = _stripPrice(widget.model?.outputPrice ?? '');
    supportReasoning = widget.model?.reasoning ?? false;
    supportVisual = widget.model?.vision ?? false;
  }

  @override
  void dispose() {
    valueController.dispose();
    nameController.dispose();
    releasedAtController.dispose();
    contextController.dispose();
    inputController.dispose();
    outputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopSettingFormField(
        label: 'Model ID',
        hint: 'The id sent to the API, e.g. deepseek-v4-flash.',
        error: idError,
        child: AthenaSettingsTextField(
          controller: valueController,
          autofocus: widget.model == null,
          mono: true,
          placeholder: 'model-id',
        ),
      ),
      const SizedBox(height: AthenaSpace.lg),
      DesktopSettingFormField(
        label: 'Display name',
        error: nameError,
        child: AthenaSettingsTextField(
          controller: nameController,
          placeholder: 'e.g. DeepSeek V4 Flash',
        ),
      ),
      const SizedBox(height: AthenaSpace.lg),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DesktopSettingFormField(
              label: 'Released',
              child: AthenaSettingsTextField(
                controller: releasedAtController,
                placeholder: 'YYYY-MM-DD',
              ),
            ),
          ),
          const SizedBox(width: AthenaSpace.md),
          Expanded(
            child: DesktopSettingFormField(
              label: 'Context window',
              child: AthenaSettingsTextField(
                controller: contextController,
                placeholder: '128K',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AthenaSpace.lg),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DesktopSettingFormField(
              label: 'Input price',
              hint: 'USD per million tokens.',
              child: AthenaSettingsTextField(
                controller: inputController,
                placeholder: '0.15',
              ),
            ),
          ),
          const SizedBox(width: AthenaSpace.md),
          Expanded(
            child: DesktopSettingFormField(
              label: 'Output price',
              hint: 'USD per million tokens.',
              child: AthenaSettingsTextField(
                controller: outputController,
                placeholder: '0.60',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AthenaSpace.lg),
      _buildCapabilities(context),
      const SizedBox(height: AthenaSpace.xxl),
      DesktopSettingFormActions(
        onCancel: cancelDialog,
        onConfirm: storeModel,
        confirmLabel: widget.model == null ? 'Add' : 'Save',
      ),
    ];
    return AthenaDesktopDialog(
      title: widget.model == null
          ? 'Add model to ${widget.provider.name}'
          : 'Edit model',
      onClose: cancelDialog,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildCapabilities(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var labelStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: AthenaSettings.rowFontSize,
      height: 1.4,
    );
    var reasoning = AthenaCheckboxGroup(
      checkbox: AthenaCheckbox(
        value: supportReasoning,
        onChanged: (value) => setState(() => supportReasoning = value),
      ),
      onTap: () => setState(() => supportReasoning = !supportReasoning),
      trailing: Text('Reasoning', style: labelStyle),
    );
    var vision = AthenaCheckboxGroup(
      checkbox: AthenaCheckbox(
        value: supportVisual,
        onChanged: (value) => setState(() => supportVisual = value),
      ),
      onTap: () => setState(() => supportVisual = !supportVisual),
      trailing: Text('Vision', style: labelStyle),
    );
    return DesktopSettingFormField(
      label: 'Capabilities',
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(spacing: 20, runSpacing: 8, children: [reasoning, vision]),
      ),
    );
  }

  void cancelDialog() {
    AthenaDialog.dismiss();
  }

  Future<void> storeModel() async {
    final modelId = valueController.text.trim();
    final name = nameController.text.trim();
    setState(() {
      idError = modelId.isEmpty ? 'Model ID is required.' : null;
      nameError = name.isEmpty ? 'Display name is required.' : null;
    });
    if (idError != null || nameError != null) return;
    final released = releasedAtController.text.trim();
    final releasedAt = released.isEmpty ? '' : 'Released $released';
    if (widget.model == null) {
      var now = DateTime.now();
      var newModel = ModelEntity(
        id: 0,
        modelId: modelId,
        name: name,
        providerId: widget.provider.id!,
        contextWindow: parseContextWindow(contextController.text),
        inputPrice: _formatPrice(inputController.text),
        outputPrice: _formatPrice(outputController.text),
        releasedAt: releasedAt,
        reasoning: supportReasoning,
        vision: supportVisual,
        createdAt: now,
        updatedAt: now,
      );
      await viewModel.createModel(newModel);
    } else {
      var copiedModel = widget.model!.copyWith(
        modelId: modelId,
        name: name,
        contextWindow: parseContextWindow(contextController.text),
        inputPrice: _formatPrice(inputController.text),
        outputPrice: _formatPrice(outputController.text),
        releasedAt: releasedAt,
        reasoning: supportReasoning,
        vision: supportVisual,
      );
      await viewModel.updateModel(copiedModel);
    }
    if (mounted) AthenaDialog.dismiss();
  }

  /// `Released 2026-09-10` → `2026-09-10`（编辑框里只放日期）。
  static String _stripReleased(String raw) {
    return raw.replaceFirst(RegExp(r'^Released\s+'), '').trim();
  }

  /// `$0.15/M input tokens` / `$0.15/M` → `0.15`；自由文本原样保留。
  static String _stripPrice(String raw) {
    final match = RegExp(r'^\$?(\d+(?:\.\d+)?)/M').firstMatch(raw.trim());
    return match?.group(1) ?? raw.trim();
  }

  /// `0.15` → `$0.15/M`；空串留空；非数字原样保存（用户自己的写法）。
  static String _formatPrice(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final value = double.tryParse(text.replaceFirst(r'$', ''));
    if (value == null) return text;
    var s = value.toStringAsFixed(4);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return '\$$s/M';
  }
}
