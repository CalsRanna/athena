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
    r'max_length': PropertySchema(
      id: 0,
      name: r'max_length',
      type: IsarType.long,
    ),
    r'model_id': PropertySchema(
      id: 1,
      name: r'model_id',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 2,
      name: r'name',
      type: IsarType.string,
    ),
    r'token_limit': PropertySchema(
      id: 3,
      name: r'token_limit',
      type: IsarType.long,
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
  version: '3.1.0+1',
);

int _modelEstimateSize(
  Model object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.modelId.length * 3;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _modelSerialize(
  Model object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.maxLength);
  writer.writeString(offsets[1], object.modelId);
  writer.writeString(offsets[2], object.name);
  writer.writeLong(offsets[3], object.tokenLimit);
}

Model _modelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Model();
  object.id = id;
  object.maxLength = reader.readLong(offsets[0]);
  object.modelId = reader.readString(offsets[1]);
  object.name = reader.readString(offsets[2]);
  object.tokenLimit = reader.readLong(offsets[3]);
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
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
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

  QueryBuilder<Model, Model, QAfterFilterCondition> maxLengthEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'max_length',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> maxLengthGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'max_length',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> maxLengthLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'max_length',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> maxLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'max_length',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> modelIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'model_id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> modelIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'model_id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> modelIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'model_id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> modelIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'model_id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> modelIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'model_id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> modelIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'model_id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> modelIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'model_id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> modelIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'model_id',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> modelIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'model_id',
        value: '',
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> modelIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'model_id',
        value: '',
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

  QueryBuilder<Model, Model, QAfterFilterCondition> tokenLimitEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'token_limit',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> tokenLimitGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'token_limit',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> tokenLimitLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'token_limit',
        value: value,
      ));
    });
  }

  QueryBuilder<Model, Model, QAfterFilterCondition> tokenLimitBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'token_limit',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ModelQueryObject on QueryBuilder<Model, Model, QFilterCondition> {}

extension ModelQueryLinks on QueryBuilder<Model, Model, QFilterCondition> {}

extension ModelQuerySortBy on QueryBuilder<Model, Model, QSortBy> {
  QueryBuilder<Model, Model, QAfterSortBy> sortByMaxLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'max_length', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByMaxLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'max_length', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'model_id', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'model_id', Sort.desc);
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

  QueryBuilder<Model, Model, QAfterSortBy> sortByTokenLimit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'token_limit', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> sortByTokenLimitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'token_limit', Sort.desc);
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

  QueryBuilder<Model, Model, QAfterSortBy> thenByMaxLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'max_length', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByMaxLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'max_length', Sort.desc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'model_id', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'model_id', Sort.desc);
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

  QueryBuilder<Model, Model, QAfterSortBy> thenByTokenLimit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'token_limit', Sort.asc);
    });
  }

  QueryBuilder<Model, Model, QAfterSortBy> thenByTokenLimitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'token_limit', Sort.desc);
    });
  }
}

extension ModelQueryWhereDistinct on QueryBuilder<Model, Model, QDistinct> {
  QueryBuilder<Model, Model, QDistinct> distinctByMaxLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'max_length');
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctByModelId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'model_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Model, Model, QDistinct> distinctByTokenLimit() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'token_limit');
    });
  }
}

extension ModelQueryProperty on QueryBuilder<Model, Model, QQueryProperty> {
  QueryBuilder<Model, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Model, int, QQueryOperations> maxLengthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'max_length');
    });
  }

  QueryBuilder<Model, String, QQueryOperations> modelIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'model_id');
    });
  }

  QueryBuilder<Model, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Model, int, QQueryOperations> tokenLimitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'token_limit');
    });
  }
}
