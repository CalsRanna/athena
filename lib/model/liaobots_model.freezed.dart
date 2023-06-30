// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'liaobots_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

LiaobotsModel _$LiaobotsModelFromJson(Map<String, dynamic> json) {
  return _LiaobotsModel.fromJson(json);
}

/// @nodoc
mixin _$LiaobotsModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get maxLength => throw _privateConstructorUsedError;
  int get tokenLimit => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $LiaobotsModelCopyWith<LiaobotsModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiaobotsModelCopyWith<$Res> {
  factory $LiaobotsModelCopyWith(
          LiaobotsModel value, $Res Function(LiaobotsModel) then) =
      _$LiaobotsModelCopyWithImpl<$Res, LiaobotsModel>;
  @useResult
  $Res call({String id, String name, int maxLength, int tokenLimit});
}

/// @nodoc
class _$LiaobotsModelCopyWithImpl<$Res, $Val extends LiaobotsModel>
    implements $LiaobotsModelCopyWith<$Res> {
  _$LiaobotsModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? maxLength = null,
    Object? tokenLimit = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      maxLength: null == maxLength
          ? _value.maxLength
          : maxLength // ignore: cast_nullable_to_non_nullable
              as int,
      tokenLimit: null == tokenLimit
          ? _value.tokenLimit
          : tokenLimit // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_LiaobotsModelCopyWith<$Res>
    implements $LiaobotsModelCopyWith<$Res> {
  factory _$$_LiaobotsModelCopyWith(
          _$_LiaobotsModel value, $Res Function(_$_LiaobotsModel) then) =
      __$$_LiaobotsModelCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String name, int maxLength, int tokenLimit});
}

/// @nodoc
class __$$_LiaobotsModelCopyWithImpl<$Res>
    extends _$LiaobotsModelCopyWithImpl<$Res, _$_LiaobotsModel>
    implements _$$_LiaobotsModelCopyWith<$Res> {
  __$$_LiaobotsModelCopyWithImpl(
      _$_LiaobotsModel _value, $Res Function(_$_LiaobotsModel) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? maxLength = null,
    Object? tokenLimit = null,
  }) {
    return _then(_$_LiaobotsModel(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      maxLength: null == maxLength
          ? _value.maxLength
          : maxLength // ignore: cast_nullable_to_non_nullable
              as int,
      tokenLimit: null == tokenLimit
          ? _value.tokenLimit
          : tokenLimit // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_LiaobotsModel implements _LiaobotsModel {
  const _$_LiaobotsModel(
      {required this.id,
      required this.name,
      required this.maxLength,
      required this.tokenLimit});

  factory _$_LiaobotsModel.fromJson(Map<String, dynamic> json) =>
      _$$_LiaobotsModelFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final int maxLength;
  @override
  final int tokenLimit;

  @override
  String toString() {
    return 'LiaobotsModel(id: $id, name: $name, maxLength: $maxLength, tokenLimit: $tokenLimit)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_LiaobotsModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.maxLength, maxLength) ||
                other.maxLength == maxLength) &&
            (identical(other.tokenLimit, tokenLimit) ||
                other.tokenLimit == tokenLimit));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, maxLength, tokenLimit);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_LiaobotsModelCopyWith<_$_LiaobotsModel> get copyWith =>
      __$$_LiaobotsModelCopyWithImpl<_$_LiaobotsModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_LiaobotsModelToJson(
      this,
    );
  }
}

abstract class _LiaobotsModel implements LiaobotsModel {
  const factory _LiaobotsModel(
      {required final String id,
      required final String name,
      required final int maxLength,
      required final int tokenLimit}) = _$_LiaobotsModel;

  factory _LiaobotsModel.fromJson(Map<String, dynamic> json) =
      _$_LiaobotsModel.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  int get maxLength;
  @override
  int get tokenLimit;
  @override
  @JsonKey(ignore: true)
  _$$_LiaobotsModelCopyWith<_$_LiaobotsModel> get copyWith =>
      throw _privateConstructorUsedError;
}
