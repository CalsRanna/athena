import 'package:athena/entity/model_entity.dart';
import 'package:athena/page/desktop/home/component/model_selector.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/memory_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class DesktopSettingMemoryPage extends StatefulWidget {
  const DesktopSettingMemoryPage({super.key});

  @override
  State<DesktopSettingMemoryPage> createState() =>
      _DesktopSettingMemoryPageState();
}

class _DesktopSettingMemoryPageState extends State<DesktopSettingMemoryPage> {
  final viewModel = GetIt.instance<MemoryViewModel>();

  @override
  void initState() {
    super.initState();
    if (!viewModel.isGenerating.value) {
      viewModel.loadMemory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var isGenerating = viewModel.isGenerating.value;
      var memory = viewModel.memory.value;
      var error = viewModel.error.value;
      var progress = viewModel.progress.value;

      var children = <Widget>[];

      if (error != null) {
        children.add(_buildError(error));
        children.add(const SizedBox(height: 16));
      }

      if (isGenerating) {
        children.add(_buildProgress(progress));
      } else if (memory != null && memory.content.isNotEmpty) {
        children.add(_buildHeader());
        children.add(const SizedBox(height: 16));
        children.add(Expanded(child: _buildContent(memory.content)));
      } else {
        children.add(Expanded(child: _buildEmptyState()));
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    var textStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('还没有生成记忆', style: textStyle),
          const SizedBox(height: 16),
          Text('分析历史聊天记录，让 Athena 记住关于你的一切', style: textStyle),
          const SizedBox(height: 24),
          AthenaPrimaryButton(
            onTap: _handleGenerate,
            child: Text('生成记忆'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    var memory = viewModel.memory.value;
    var updatedAt = memory?.updatedAt;
    var timeText = updatedAt != null
        ? '最后更新: ${updatedAt.year}-${updatedAt.month.toString().padLeft(2, '0')}-${updatedAt.day.toString().padLeft(2, '0')} ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}'
        : '';
    var timeStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 12,
      fontWeight: FontWeight.w400,
    );
    return Row(
      children: [
        Text(timeText, style: timeStyle),
        const Spacer(),
        AthenaSecondaryButton.small(
          onTap: _handleGenerate,
          child: Text('更新记忆'),
        ),
        const SizedBox(width: 12),
        AthenaSecondaryButton.small(
          onTap: _handleDelete,
          child: Text('删除'),
        ),
      ],
    );
  }

  Widget _buildContent(String content) {
    var borderSide = BorderSide(color: ColorUtil.FFC2C2C2, width: 1);
    var markdownStyleSheet = MarkdownStyleSheet(
      p: TextStyle(color: ColorUtil.FFFFFFFF, fontSize: 14, height: 1.6),
      h2: TextStyle(
        color: ColorUtil.FFFFFFFF,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      h3: TextStyle(
        color: ColorUtil.FFFFFFFF,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      listBullet: TextStyle(color: ColorUtil.FFFFFFFF),
      blockquoteDecoration: BoxDecoration(border: Border(left: borderSide)),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: borderSide),
      ),
    );
    return SingleChildScrollView(
      child: MarkdownBody(
        data: content,
        styleSheet: markdownStyleSheet,
        selectable: true,
      ),
    );
  }

  Widget _buildProgress(String progress) {
    var progressStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: ColorUtil.FFFFFFFF),
            const SizedBox(height: 16),
            Text(progress, style: progressStyle),
            const SizedBox(height: 24),
            AthenaSecondaryButton.small(
              onTap: _handleCancel,
              child: Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    var errorStyle = TextStyle(
      color: Colors.redAccent,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    return Text(error, style: errorStyle);
  }

  void _handleGenerate() {
    final modelViewModel = GetIt.instance<ModelViewModel>();
    var hasModel = modelViewModel.enabledModels.value.isNotEmpty;
    if (!hasModel) {
      AthenaDialog.message('请先启用一个提供商');
      return;
    }
    AthenaDialog.show(
      DesktopModelSelectDialog(
        onTap: (model) {
          AthenaDialog.dismiss();
          _startGeneration(model);
        },
      ),
      barrierDismissible: true,
    );
  }

  Future<void> _startGeneration(ModelEntity model) async {
    await viewModel.generateMemory(model);
    if (!mounted) return;
    var error = viewModel.error.value;
    if (error != null) {
      AthenaDialog.message(error);
    } else {
      AthenaDialog.message('记忆已更新');
    }
  }

  void _handleCancel() {
    viewModel.cancelGeneration();
  }

  Future<void> _handleDelete() async {
    var confirmed = await AthenaDialog.confirm('确定删除所有记忆？');
    if (confirmed != true) return;
    viewModel.deleteMemory();
  }
}
