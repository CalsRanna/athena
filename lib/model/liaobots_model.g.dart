// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'liaobots_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_LiaobotsModel _$$_LiaobotsModelFromJson(Map<String, dynamic> json) =>
    _$_LiaobotsModel(
      id: json['id'] as String,
      name: json['name'] as String,
      maxLength: json['maxLength'] as int,
      tokenLimit: json['tokenLimit'] as int,
    );

Map<String, dynamic> _$$_LiaobotsModelToJson(_$_LiaobotsModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'maxLength': instance.maxLength,
      'tokenLimit': instance.tokenLimit,
    };
