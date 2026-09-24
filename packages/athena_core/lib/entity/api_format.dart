/// Provider 的 API 格式元数据；原生协议适配完成前不参与请求路由。
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
