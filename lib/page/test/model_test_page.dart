import 'package:athena/entity/model_entity.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 这是一个展示如何使用新架构的示例页面
/// 展示了 signals + get_it + Watch 的基本用法
class ModelTestPage extends StatefulWidget {
  const ModelTestPage({super.key});

  @override
  State<ModelTestPage> createState() => _ModelTestPageState();
}

class _ModelTestPageState extends State<ModelTestPage> {
  late final ModelViewModel viewModel;

  @override
  void initState() {
    super.initState();
    // 从 GetIt 获取 ViewModel 实例
    viewModel = GetIt.instance<ModelViewModel>();
    // 加载数据
    viewModel.loadModels();
  }

  @override
  void dispose() {
    // 清理 ViewModel 资源
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Models Test (New Architecture)'),
        backgroundColor: Colors.grey[900],
      ),
      body: Watch((context) {
        // Watch 会自动监听 signals 的变化并重建 UI
        if (viewModel.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.error.value != null) {
          return Center(
            child: Text(
              'Error: ${viewModel.error.value}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final models = viewModel.models.value;

        if (models.isEmpty) {
          return const Center(
            child: Text(
              'No models found',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          itemCount: models.length,
          itemBuilder: (context, index) {
            final model = models[index];
            return _buildModelTile(model);
          },
        );
      }),
      floatingActionButton: Watch((context) {
        // 显示已启用模型的数量
        final enabledCount = viewModel.enabledModels.value.length;
        return FloatingActionButton.extended(
          onPressed: () => _showModelStats(context),
          label: Text('Enabled: $enabledCount'),
          icon: const Icon(Icons.check_circle),
        );
      }),
    );
  }

  Widget _buildModelTile(ModelEntity model) {
    return ListTile(
      title: Text(model.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        'Value: ${model.modelId}',
        style: const TextStyle(color: Colors.white60),
      ),
      trailing: Watch((context) {
        // 局部 Watch - 只监听这个 model 的状态变化
        // ModelEntity 没有 enabled 字段，所有 enabled provider 下的 model 都被视为 enabled
        return Chip(
          label: Text('Active'),
          backgroundColor: Colors.green.withValues(alpha: 0.2),
        );
      }),
      leading: Icon(
        model.vision ? Icons.visibility : Icons.text_fields,
        color: Colors.blue,
      ),
    );
  }

  void _showModelStats(BuildContext context) {
    final groupedModels = viewModel.groupedEnabledModels.value;
    final totalEnabled = viewModel.enabledModels.value.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Enabled Models: $totalEnabled'),
            const SizedBox(height: 16),
            const Text('Grouped by Provider:'),
            ...groupedModels.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Text(
                  'Provider ${entry.key}: ${entry.value.length} models',
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// 使用示例:
///
/// ```dart
/// // 在路由中:
/// AutoRoute(
///   path: '/model-test',
///   page: ModelTestRoute.page,
/// ),
///
/// // 导航:
/// context.router.push(const ModelTestRoute());
/// ```
///
/// 关键点:
/// 1. 使用 GetIt.instance<XxxViewModel>() 获取 ViewModel
/// 2. 使用 Watch((context) { }) 监听 signals 变化
/// 3. 在 dispose 中调用 viewModel.dispose() 清理资源
/// 4. signals 的 .value 访问当前值
/// 5. computed signals 自动计算派生状态
