// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'liaobots_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_LiaobotsAccount _$$_LiaobotsAccountFromJson(Map<String, dynamic> json) =>
    _$_LiaobotsAccount(
      amount: (json['amount'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      gpt4: json['gpt4FreeRemain'] as int,
      expireDate: json['unlimitedAdvancedEndTime'] as int,
    );

Map<String, dynamic> _$$_LiaobotsAccountToJson(_$_LiaobotsAccount instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'balance': instance.balance,
      'gpt4FreeRemain': instance.gpt4,
      'unlimitedAdvancedEndTime': instance.expireDate,
    };
