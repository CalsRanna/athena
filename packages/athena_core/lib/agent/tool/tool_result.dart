import 'package:openai_dart/openai_dart.dart';

/// Execution status is independent of model-visible text.
class ToolExecutionResult {
  final String text;

  /// 需要模型看到的图片（如 `file_read` 读到的图片文件）。
  final List<ToolResultImage> images;

  final ToolResultStatus status;

  final int? exitCode;

  const ToolExecutionResult.error(this.text, {this.exitCode})
    : status = ToolResultStatus.executionError,
      images = const [];
  const ToolExecutionResult.success(
    this.text, {
    this.images = const [],
    this.exitCode,
  }) : status = ToolResultStatus.success;
}

/// 可供 Reflection 使用的工具失败证据。
class ToolFailure {
  final String toolName;
  final ToolResultStatus status;
  final String message;

  const ToolFailure({
    required this.toolName,
    required this.status,
    required this.message,
  });
}

/// 工具返回的图片，随工具结果一起进入模型上下文。
///
/// 图片在协议层不能放进工具消息：Chat Completions 的 tool 消息 content
/// 只能是字符串；Messages/Responses 虽原生支持，但内部消息模型复用
/// openai_dart 的 sealed `ChatMessage`，无法扩展 `ToolMessage`。所以图片统一
/// 由 [ToolResultImages.toolResultImagesMessage] 转成一条 user 消息，追加在整批工具消息之后。
class ToolResultImage {
  /// Base64 编码的图片字节，不含 `data:` 前缀。
  final String data;
  final String mediaType;

  const ToolResultImage({required this.data, required this.mediaType});

  /// 持久化到 `tool_results` 的记录形态；与同记录里的 camelCase 键一致。
  Map<String, dynamic> toJson() => {'mediaType': mediaType, 'data': data};

  /// 读取持久化记录；旧记录没有图片或字段损坏时返回 null。
  static ToolResultImage? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final mediaType = json['mediaType'];
    final data = json['data'];
    if (mediaType is! String || mediaType.isEmpty) return null;
    if (data is! String || data.isEmpty) return null;
    return ToolResultImage(data: data, mediaType: mediaType);
  }
}

abstract final class ToolResultImages {
  /// 合成图片消息的正文标记，用于把它和真实用户输入区分开。
  static const toolResultImagesMarker =
      'Images returned by the tool calls above, in the same order.';

  /// 承载工具结果图片的 user 消息；没有图片时返回 null。
  ///
  /// 调用方必须等整批工具消息都写入后再追加：Chat Completions 要求所有
  /// tool 消息紧跟在带 tool_calls 的 assistant 之后，中间插入 user 消息会被
  /// 兼容端判为非法请求。
  static ChatMessage? toolResultImagesMessage(List<ToolResultImage> images) {
    if (images.isEmpty) return null;
    return ChatMessage.user([
      ContentPart.text(ToolResultImages.toolResultImagesMarker),
      for (final image in images)
        ContentPart.imageBase64(data: image.data, mediaType: image.mediaType),
    ]);
  }
}

/// 单次工具调用的结构化结果。
enum ToolResultStatus {
  success,
  invalidArguments,
  blocked,
  executionError,
  modelTruncated,
}
