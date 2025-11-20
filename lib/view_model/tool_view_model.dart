import 'package:athena/entity/tool_entity.dart';
import 'package:athena/repository/tool_repository.dart';
import 'package:signals/signals.dart';

class ToolViewModel {
  // ViewModel 内部直接持有 Repository
  final ToolRepository _toolRepository = ToolRepository();

  // Signals 状态
  final tools = listSignal<ToolEntity>([]);
  final isLoading = signal(false);
  final error = signal<String?>(null);

  // 业务方法
  Future<void> loadTools() async {
    isLoading.value = true;
    error.value = null;
    try {
      tools.value = await _toolRepository.getAllTools();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<ToolEntity?> getToolById(int id) async {
    try {
      return await _toolRepository.getToolById(id);
    } catch (e) {
      error.value = e.toString();
      return null;
    }
  }

  Future<void> createTool(ToolEntity tool) async {
    isLoading.value = true;
    error.value = null;
    try {
      var id = await _toolRepository.createTool(tool);
      var created = tool.copyWith(id: id);
      tools.value = [...tools.value, created];
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateTool(ToolEntity tool) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _toolRepository.updateTool(tool);
      var index = tools.value.indexWhere((t) => t.id == tool.id);
      if (index >= 0) {
        var updated = List<ToolEntity>.from(tools.value);
        updated[index] = tool;
        tools.value = updated;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateKey(ToolEntity tool) async {
    await updateTool(tool);
  }

  Future<void> deleteTool(ToolEntity tool) async {
    isLoading.value = true;
    error.value = null;
    try {
      await _toolRepository.deleteTool(tool.id!);
      tools.value = tools.value.where((t) => t.id != tool.id).toList();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
