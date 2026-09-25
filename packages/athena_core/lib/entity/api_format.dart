/// Provider 的 API 格式：`LlmClient` 按它分派请求实现
/// （Chat Completions / Responses / Messages 三条路径都已接入）。
enum ApiFormat {
  chatCompletions('chat_completions'),
  responses('responses'),
  messages('messages');

  const ApiFormat(this.value);

  final String value;

  static ApiFormat? tryParse(Object? value) {
    for (final format in values) {
      if (format.value == value) return format;
    }
    return null;
  }
}
