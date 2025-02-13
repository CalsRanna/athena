// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSettingCollection on Isar {
  IsarCollection<Setting> get settings => this.collection();
}

const SettingSchema = CollectionSchema(
  name: r'settings',
  id: -5221820136678325216,
  properties: {
    r'chatModelId': PropertySchema(
      id: 0,
      name: r'chatModelId',
      type: IsarType.long,
    ),
    r'chatNamingModelId': PropertySchema(
      id: 1,
      name: r'chatNamingModelId',
      type: IsarType.long,
    ),
    r'dark_mode': PropertySchema(
      id: 2,
      name: r'dark_mode',
      type: IsarType.bool,
    ),
    r'height': PropertySchema(
      id: 3,
      name: r'height',
      type: IsarType.double,
    ),
    r'latex': PropertySchema(
      id: 4,
      name: r'latex',
      type: IsarType.bool,
    ),
    r'sentinelMetadataGenerationModelId': PropertySchema(
      id: 5,
      name: r'sentinelMetadataGenerationModelId',
      type: IsarType.long,
    ),
    r'width': PropertySchema(
      id: 6,
      name: r'width',
      type: IsarType.double,
    )
  },
  estimateSize: _settingEstimateSize,
  serialize: _settingSerialize,
  deserialize: _settingDeserialize,
  deserializeProp: _settingDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _settingGetId,
  getLinks: _settingGetLinks,
  attach: _settingAttach,
  version: '3.1.8',
);

int _settingEstimateSize(
  Setting object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _settingSerialize(
  Setting object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.chatModelId);
  writer.writeLong(offsets[1], object.chatNamingModelId);
  writer.writeBool(offsets[2], object.darkMode);
  writer.writeDouble(offsets[3], object.height);
  writer.writeBool(offsets[4], object.latex);
  writer.writeLong(offsets[5], object.sentinelMetadataGenerationModelId);
  writer.writeDouble(offsets[6], object.width);
}

Setting _settingDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Setting();
  object.chatModelId = reader.readLong(offsets[0]);
  object.chatNamingModelId = reader.readLong(offsets[1]);
  object.darkMode = reader.readBool(offsets[2]);
  object.height = reader.readDouble(offsets[3]);
  object.id = id;
  object.latex = reader.readBool(offsets[4]);
  object.sentinelMetadataGenerationModelId = reader.readLong(offsets[5]);
  object.width = reader.readDouble(offsets[6]);
  return object;
}

P _settingDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readDouble(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _settingGetId(Setting object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _settingGetLinks(Setting object) {
  return [];
}

void _settingAttach(IsarCollection<dynamic> col, Id id, Setting object) {
  object.id = id;
}

extension SettingQueryWhereSort on QueryBuilder<Setting, Setting, QWhere> {
  QueryBuilder<Setting, Setting, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SettingQueryWhere on QueryBuilder<Setting, Setting, QWhereClause> {
  QueryBuilder<Setting, Setting, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Setting, Setting, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Setting, Setting, QAfterWhereClause> idBetween(
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

extension SettingQueryFilter
    on QueryBuilder<Setting, Setting, QFilterCondition> {
  QueryBuilder<Setting, Setting, QAfterFilterCondition> chatModelIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chatModelId',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> chatModelIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chatModelId',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> chatModelIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chatModelId',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> chatModelIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chatModelId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
      chatNamingModelIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chatNamingModelId',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
      chatNamingModelIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chatNamingModelId',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
      chatNamingModelIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chatNamingModelId',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
      chatNamingModelIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chatNamingModelId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> darkModeEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dark_mode',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> heightEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'height',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> heightGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'height',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> heightLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'height',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> heightBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'height',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Setting, Setting, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Setting, Setting, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Setting, Setting, QAfterFilterCondition> latexEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'latex',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
      sentinelMetadataGenerationModelIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sentinelMetadataGenerationModelId',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
      sentinelMetadataGenerationModelIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sentinelMetadataGenerationModelId',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
      sentinelMetadataGenerationModelIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sentinelMetadataGenerationModelId',
        value: value,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition>
      sentinelMetadataGenerationModelIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sentinelMetadataGenerationModelId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> widthEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'width',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> widthGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'width',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> widthLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'width',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Setting, Setting, QAfterFilterCondition> widthBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'width',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }
}

extension SettingQueryObject
    on QueryBuilder<Setting, Setting, QFilterCondition> {}

extension SettingQueryLinks
    on QueryBuilder<Setting, Setting, QFilterCondition> {}

extension SettingQuerySortBy on QueryBuilder<Setting, Setting, QSortBy> {
  QueryBuilder<Setting, Setting, QAfterSortBy> sortByChatModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatModelId', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByChatModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatModelId', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByChatNamingModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatNamingModelId', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByChatNamingModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatNamingModelId', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByDarkMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dark_mode', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByDarkModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dark_mode', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByLatex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latex', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByLatexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latex', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy>
      sortBySentinelMetadataGenerationModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentinelMetadataGenerationModelId', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy>
      sortBySentinelMetadataGenerationModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentinelMetadataGenerationModelId', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> sortByWidthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.desc);
    });
  }
}

extension SettingQuerySortThenBy
    on QueryBuilder<Setting, Setting, QSortThenBy> {
  QueryBuilder<Setting, Setting, QAfterSortBy> thenByChatModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatModelId', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByChatModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatModelId', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByChatNamingModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatNamingModelId', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByChatNamingModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatNamingModelId', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByDarkMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dark_mode', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByDarkModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dark_mode', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByLatex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latex', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByLatexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latex', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy>
      thenBySentinelMetadataGenerationModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentinelMetadataGenerationModelId', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy>
      thenBySentinelMetadataGenerationModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentinelMetadataGenerationModelId', Sort.desc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.asc);
    });
  }

  QueryBuilder<Setting, Setting, QAfterSortBy> thenByWidthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.desc);
    });
  }
}

extension SettingQueryWhereDistinct
    on QueryBuilder<Setting, Setting, QDistinct> {
  QueryBuilder<Setting, Setting, QDistinct> distinctByChatModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chatModelId');
    });
  }

  QueryBuilder<Setting, Setting, QDistinct> distinctByChatNamingModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chatNamingModelId');
    });
  }

  QueryBuilder<Setting, Setting, QDistinct> distinctByDarkMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dark_mode');
    });
  }

  QueryBuilder<Setting, Setting, QDistinct> distinctByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'height');
    });
  }

  QueryBuilder<Setting, Setting, QDistinct> distinctByLatex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'latex');
    });
  }

  QueryBuilder<Setting, Setting, QDistinct>
      distinctBySentinelMetadataGenerationModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sentinelMetadataGenerationModelId');
    });
  }

  QueryBuilder<Setting, Setting, QDistinct> distinctByWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'width');
    });
  }
}

extension SettingQueryProperty
    on QueryBuilder<Setting, Setting, QQueryProperty> {
  QueryBuilder<Setting, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Setting, int, QQueryOperations> chatModelIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chatModelId');
    });
  }

  QueryBuilder<Setting, int, QQueryOperations> chatNamingModelIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chatNamingModelId');
    });
  }

  QueryBuilder<Setting, bool, QQueryOperations> darkModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dark_mode');
    });
  }

  QueryBuilder<Setting, double, QQueryOperations> heightProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'height');
    });
  }

  QueryBuilder<Setting, bool, QQueryOperations> latexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'latex');
    });
  }

  QueryBuilder<Setting, int, QQueryOperations>
      sentinelMetadataGenerationModelIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sentinelMetadataGenerationModelId');
    });
  }

  QueryBuilder<Setting, double, QQueryOperations> widthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'width');
    });
  }
}
