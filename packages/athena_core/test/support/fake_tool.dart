import 'package:athena_core/agent/tool/tool_interface.dart';

/// 只有名字与固定结果的测试工具：工具过滤测试只关心集合口径。
class FakeTool extends Tool {
  FakeTool(this.name, {this.result = 'ok'});

  @override
  final String name;

  final String result;

  @override
  String get description => 'Fake tool $name.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  @override
  Future<ToolExecutionResult> executeResult(
    Map<String, dynamic> args, {
    void Function(String partialResult)? onUpdate,
  }) async => ToolExecutionResult.success(result);
}
