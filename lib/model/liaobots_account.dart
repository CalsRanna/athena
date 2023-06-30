import 'package:freezed_annotation/freezed_annotation.dart';

part 'liaobots_account.freezed.dart';
part 'liaobots_account.g.dart';

@freezed
class LiaobotsAccount with _$LiaobotsAccount {
  const factory LiaobotsAccount({
    required double amount,
    required double balance,
    @JsonKey(name: 'gpt4FreeRemain') required int gpt4,
    @JsonKey(name: 'unlimitedAdvancedEndTime') required int expireDate,
  }) = _LiaobotsAccount;

  factory LiaobotsAccount.fromJson(Map<String, Object?> json) =>
      _$LiaobotsAccountFromJson(json);
}
