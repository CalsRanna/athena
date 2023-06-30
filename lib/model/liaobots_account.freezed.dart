// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'liaobots_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

LiaobotsAccount _$LiaobotsAccountFromJson(Map<String, dynamic> json) {
  return _LiaobotsAccount.fromJson(json);
}

/// @nodoc
mixin _$LiaobotsAccount {
  double get amount => throw _privateConstructorUsedError;
  double get balance => throw _privateConstructorUsedError;
  @JsonKey(name: 'gpt4FreeRemain')
  int get gpt4 => throw _privateConstructorUsedError;
  @JsonKey(name: 'unlimitedAdvancedEndTime')
  int get expireDate => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $LiaobotsAccountCopyWith<LiaobotsAccount> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiaobotsAccountCopyWith<$Res> {
  factory $LiaobotsAccountCopyWith(
          LiaobotsAccount value, $Res Function(LiaobotsAccount) then) =
      _$LiaobotsAccountCopyWithImpl<$Res, LiaobotsAccount>;
  @useResult
  $Res call(
      {double amount,
      double balance,
      @JsonKey(name: 'gpt4FreeRemain') int gpt4,
      @JsonKey(name: 'unlimitedAdvancedEndTime') int expireDate});
}

/// @nodoc
class _$LiaobotsAccountCopyWithImpl<$Res, $Val extends LiaobotsAccount>
    implements $LiaobotsAccountCopyWith<$Res> {
  _$LiaobotsAccountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? balance = null,
    Object? gpt4 = null,
    Object? expireDate = null,
  }) {
    return _then(_value.copyWith(
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as double,
      gpt4: null == gpt4
          ? _value.gpt4
          : gpt4 // ignore: cast_nullable_to_non_nullable
              as int,
      expireDate: null == expireDate
          ? _value.expireDate
          : expireDate // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_LiaobotsAccountCopyWith<$Res>
    implements $LiaobotsAccountCopyWith<$Res> {
  factory _$$_LiaobotsAccountCopyWith(
          _$_LiaobotsAccount value, $Res Function(_$_LiaobotsAccount) then) =
      __$$_LiaobotsAccountCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double amount,
      double balance,
      @JsonKey(name: 'gpt4FreeRemain') int gpt4,
      @JsonKey(name: 'unlimitedAdvancedEndTime') int expireDate});
}

/// @nodoc
class __$$_LiaobotsAccountCopyWithImpl<$Res>
    extends _$LiaobotsAccountCopyWithImpl<$Res, _$_LiaobotsAccount>
    implements _$$_LiaobotsAccountCopyWith<$Res> {
  __$$_LiaobotsAccountCopyWithImpl(
      _$_LiaobotsAccount _value, $Res Function(_$_LiaobotsAccount) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? balance = null,
    Object? gpt4 = null,
    Object? expireDate = null,
  }) {
    return _then(_$_LiaobotsAccount(
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as double,
      gpt4: null == gpt4
          ? _value.gpt4
          : gpt4 // ignore: cast_nullable_to_non_nullable
              as int,
      expireDate: null == expireDate
          ? _value.expireDate
          : expireDate // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_LiaobotsAccount implements _LiaobotsAccount {
  const _$_LiaobotsAccount(
      {required this.amount,
      required this.balance,
      @JsonKey(name: 'gpt4FreeRemain') required this.gpt4,
      @JsonKey(name: 'unlimitedAdvancedEndTime') required this.expireDate});

  factory _$_LiaobotsAccount.fromJson(Map<String, dynamic> json) =>
      _$$_LiaobotsAccountFromJson(json);

  @override
  final double amount;
  @override
  final double balance;
  @override
  @JsonKey(name: 'gpt4FreeRemain')
  final int gpt4;
  @override
  @JsonKey(name: 'unlimitedAdvancedEndTime')
  final int expireDate;

  @override
  String toString() {
    return 'LiaobotsAccount(amount: $amount, balance: $balance, gpt4: $gpt4, expireDate: $expireDate)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_LiaobotsAccount &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.gpt4, gpt4) || other.gpt4 == gpt4) &&
            (identical(other.expireDate, expireDate) ||
                other.expireDate == expireDate));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, amount, balance, gpt4, expireDate);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_LiaobotsAccountCopyWith<_$_LiaobotsAccount> get copyWith =>
      __$$_LiaobotsAccountCopyWithImpl<_$_LiaobotsAccount>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_LiaobotsAccountToJson(
      this,
    );
  }
}

abstract class _LiaobotsAccount implements LiaobotsAccount {
  const factory _LiaobotsAccount(
      {required final double amount,
      required final double balance,
      @JsonKey(name: 'gpt4FreeRemain')
          required final int gpt4,
      @JsonKey(name: 'unlimitedAdvancedEndTime')
          required final int expireDate}) = _$_LiaobotsAccount;

  factory _LiaobotsAccount.fromJson(Map<String, dynamic> json) =
      _$_LiaobotsAccount.fromJson;

  @override
  double get amount;
  @override
  double get balance;
  @override
  @JsonKey(name: 'gpt4FreeRemain')
  int get gpt4;
  @override
  @JsonKey(name: 'unlimitedAdvancedEndTime')
  int get expireDate;
  @override
  @JsonKey(ignore: true)
  _$$_LiaobotsAccountCopyWith<_$_LiaobotsAccount> get copyWith =>
      throw _privateConstructorUsedError;
}
