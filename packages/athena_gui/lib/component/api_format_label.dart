import 'package:athena_core/entity/api_format.dart';

/// 三种 API 格式在界面上的文案（桌面 provider 详情、移动端表单共用）。
///
/// `ApiFormat.value` 是落库标识（`chat_completions` 等），不直接上界面。
extension ApiFormatLabel on ApiFormat {
  /// 短名：`Chat Completions` / `Responses` / `Messages`。
  String get label => switch (this) {
    ApiFormat.chatCompletions => 'Chat Completions',
    ApiFormat.responses => 'Responses',
    ApiFormat.messages => 'Messages',
  };
}
