// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetModelCollection on Isar {
  IsarCollection<Model> get models => this.collection();
}

const ModelSchema = CollectionSchema(
  name: r'models',
  id: 6728634196192131898,
  properties: {
    r'input_price': PropertySchema(
      id: 0,
      name: r'input_price',
      type: IsarType.string,
    ),
    r'max_token': PropertySchema(
      id: 1,
      name: r'max_token',
      type: IsarType.long,
    ),
    r'name': PropertySchema(
      id: 2,
      name: r'name',
      type: IsarType.string,
    ),
    r'output_price': PropertySchema(
      id: 3,
      name: r'output_price',
      type: IsarType.string,
    ),
    r'provider_id': PropertySchema(
      id: 4,
      name: r'provider_id',
      type: IsarType.long,
    ),
    r'released_at': PropertySchema(
      id: 5,
      name: r'released_at',
      type: IsarType.string,
    ),
    r'support_function_call': PropertySchema(
      id: 6,
      name: r'support_function_call',
      type: IsarType.bool,
    ),
    r'support_thinking': PropertySchema(
      id: 7,
      name: r'support_thinking',
      type: IsarType.bool,
    ),
    r'support_visual_recognition': PropertySchema(
      id: 8,
      name: r'support_visual_recognition',
      type: IsarType.bool,
    ),
    r'value': PropertySchema(
      id: 9,
      name: r'value',
      type: IsarType.string,
    )
  },
  estimateSize: _modelEstimateSize,
  serialize: _modelSerialize,
  deserialize: _modelDeserialize,
  deserializeProp: _modelDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _modelGetId,
  getLinks: _modelGetLinks,
  attach: _modelAttach,
  version: '3.1.8',
);

int _modelEstimateSize(
  Model object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.inputPrice.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.outputPrice.length * 3;
  bytesCount += 3 + object.releasedAt.length * 3;
  bytesCount += 3 + object.value.length * 3;
  return bytesCount;
}

void _modelSerialize(
  Model object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.inputPrice);
  writer.writeLong(offsets[1], object.maxToken);
  writer.writeString(offsets[2], object.name);
  writer.writeString(offsets[3], object.outputPrice);
  writer.writeLong(offsets[4], object.providerId);
  writer.writeString(offsets[5], object.releasedAt);
  writer.writeBool(offsets[6], object.supportFunctionCall);
  writer.writeBool(offsets[7], object.supportThinking);
  writer.writeBool(offsets[8], object.supportVisualRecognition);
  writer.writeString(offsets[9], object.value);
}

Model _modelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Model();
  object.id = id;
  object.inputPrice = reader.readString(offsets[0]);
  object.maxToken = reader.readLong(offsets[1]);
  object.name = reader.readString(offsets[2]);
  object.outputPrice = reader.readString(offsets[3]);
  object.providerId = reader.readLong(offsets[4]);
  object.releasedAt = reader.readString(offsets[5]);
  object.supportFunctionCall = reader.readBool(offsets[6]);
  object.supportThinking = reader.readBool(offsets[7]);
  object.supportVisualRecognition = reader.readBool(offsets[8]);
  object.value = reader.readString(offsets[9]);
  return object;
}

P _modelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _modelGetId(Model object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _modelGetLinks(Model object) {
  return [];
}

void _modelAttach(IsarCollection<dynamic> col, Id id, Model object) {
  object.id = id;
}

extension ModelQueryWhereSort on QueryBuilder<Model, Model, QWhere> {
  QueryBuilder<Model, Model, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ModelQueryWhere on QueryBuilder<Model, Model, QWhereClause> {
  QueryBuilder<Model, Model, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Model, Model, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Model, Model, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Model, Model, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ModelQueryFilter on QueryBuilder<Model, Model, QFilterCondition> {
  QueryBuilder<Model, Model, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> inputPriceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'input_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> inputPriceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'input_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> inputPriceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'input_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> inputPriceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'input_price',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> inputPriceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'input_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> inputPriceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'input_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> inputPriceContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'input_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> inputPriceMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'input_price',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> inputPriceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'input_price',
        value: '',
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> inputPriceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'input_price',
        value: '',
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> maxTokenEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'max_token',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> maxTokenGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'max_token',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> maxTokenLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'max_token',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> maxTokenBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'max_token',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> nameContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> nameMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> outputPriceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'output_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> outputPriceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'output_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> outputPriceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'output_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> outputPriceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'output_price',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> outputPriceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'output_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> outputPriceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'output_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> outputPriceContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'output_price',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> outputPriceMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'output_price',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> outputPriceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'output_price',
        value: '',
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> outputPriceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'output_price',
        value: '',
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> providerIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provider_id',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> providerIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'provider_id',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> providerIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'provider_id',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> providerIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'provider_id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> releasedAtEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'released_at',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> releasedAtGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'released_at',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> releasedAtLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'released_at',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> releasedAtBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'released_at',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> releasedAtStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'released_at',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> releasedAtEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'released_at',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> releasedAtContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'released_at',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> releasedAtMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'released_at',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> releasedAtIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'released_at',
        value: '',
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> releasedAtIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'released_at',
        value: '',
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> supportFunctionCallEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'support_function_call',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> supportThinkingEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'support_thinking',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition>
      supportVisualRecognitionEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'support_visual_recognition',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> valueEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'value',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> valueGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'value',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> valueLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'value',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> valueBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'value',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> valueStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'value',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> valueEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'value',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> valueContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'value',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> valueMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'value',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> valueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'value',
        value: '',
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> valueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'value',
        value: '',
      ));
    });
  }
}

extension ModelQueryObject on QueryBuilder<Model, Model, QFilterCondition> {}

extension ModelQueryLinks on QueryBuilder<Model, Model, QFilterCondition> {}

extension ModelQuerySortBy on QueryBuilder<Model, Model, QSortBy> {
  QueryBuilder<Model, Model, QAfterSortBy> sortByInputPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'input_price', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByInputPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'input_price', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByMaxToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'max_token', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByMaxTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'max_token', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByOutputPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'output_price', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByOutputPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'output_price', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByProviderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provider_id', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByProviderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provider_id', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByReleasedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'released_at', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByReleasedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'released_at', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortBySupportFunctionCall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_function_call', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortBySupportFunctionCallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_function_call', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortBySupportThinking() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_thinking', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortBySupportThinkingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_thinking', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortBySupportVisualRecognition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_visual_recognition', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy>
      sortBySupportVisualRecognitionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_visual_recognition', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension ModelQuerySortThenBy on QueryBuilder<Model, Model, QSortThenBy> {
  QueryBuilder<Model, Model, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByInputPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'input_price', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByInputPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'input_price', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByMaxToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'max_token', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByMaxTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'max_token', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByOutputPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'output_price', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByOutputPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'output_price', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByProviderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provider_id', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByProviderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provider_id', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByReleasedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'released_at', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByReleasedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'released_at', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenBySupportFunctionCall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_function_call', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenBySupportFunctionCallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_function_call', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenBySupportThinking() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_thinking', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenBySupportThinkingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_thinking', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenBySupportVisualRecognition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_visual_recognition', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy>
      thenBySupportVisualRecognitionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'support_visual_recognition', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension ModelQueryWhereDistinct on QueryBuilder<Model, Model, QDistinct> {
  QueryBuilder<Model, Model, QDistinct> distinctByInputPrice(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'input_price', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctByMaxToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'max_token');
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctByOutputPrice(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'output_price', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctByProviderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'provider_id');
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctByReleasedAt(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'released_at', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctBySupportFunctionCall() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'support_function_call');
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctBySupportThinking() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'support_thinking');
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctBySupportVisualRecognition() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'support_visual_recognition');
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctByValue(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'value', caseSensitive: caseSensitive);
    });
  }
}

extension ModelQueryProperty on QueryBuilder<Model, Model, QQueryProperty> {
  QueryBuilder<Model, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Model, String, QQueryOperations> inputPriceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'input_price');
    });
  }

  QueryBuilder<Model, int, QQueryOperations> maxTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'max_token');
    });
  }

  QueryBuilder<Model, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Model, String, QQueryOperations> outputPriceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'output_price');
    });
  }

  QueryBuilder<Model, int, QQueryOperations> providerIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'provider_id');
    });
  }

  QueryBuilder<Model, String, QQueryOperations> releasedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'released_at');
    });
  }

  QueryBuilder<Model, bool, QQueryOperations> supportFunctionCallProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'support_function_call');
    });
  }

  QueryBuilder<Model, bool, QQueryOperations> supportThinkingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'support_thinking');
    });
  }

  QueryBuilder<Model, bool, QQueryOperations>
      supportVisualRecognitionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'support_visual_recognition');
    });
  }

  QueryBuilder<Model, String, QQueryOperations> valueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'value');
    });
  }
}
