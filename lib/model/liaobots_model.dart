import 'package:freezed_annotation/freezed_annotation.dart';

part 'liaobots_model.freezed.dart';
part 'liaobots_model.g.dart';

@freezed
class LiaobotsModel with _$LiaobotsModel {
  const factory LiaobotsModel({
    required String id,
    required String name,
    required int maxLength,
    required int tokenLimit,
  }) = _LiaobotsModel;

  factory LiaobotsModel.fromJson(Map<String, Object?> json) =>
      _$LiaobotsModelFromJson(json);
}
