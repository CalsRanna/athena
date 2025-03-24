import 'package:openai_dart/openai_dart.dart';

class McpToolCall {
  StringBuffer id = StringBuffer();
  StringBuffer name = StringBuffer();
  StringBuffer arguments = StringBuffer();

  void process(ChatCompletionStreamMessageToolCallChunk chunk) {
    if (chunk.id != null) {
      id.write(chunk.id!);
    }
    if (chunk.function?.name != null) {
      name.write(chunk.function!.name!);
    }
    if (chunk.function?.arguments != null) {
      arguments.write(chunk.function!.arguments!);
    }
  }

  Map<String, String> toJson() {
    return {
      'id': id.toString(),
      'name': name.toString(),
      'arguments': arguments.toString(),
    };
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
