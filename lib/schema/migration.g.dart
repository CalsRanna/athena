// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'migration.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMigrationCollection on Isar {
  IsarCollection<Migration> get migrations => this.collection();
}

const MigrationSchema = CollectionSchema(
  name: r'migrations',
  id: -5335705344918714178,
  properties: {
    r'migration': PropertySchema(
      id: 0,
      name: r'migration',
      type: IsarType.string,
    )
  },
  estimateSize: _migrationEstimateSize,
  serialize: _migrationSerialize,
  deserialize: _migrationDeserialize,
  deserializeProp: _migrationDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _migrationGetId,
  getLinks: _migrationGetLinks,
  attach: _migrationAttach,
  version: '3.1.8',
);

int _migrationEstimateSize(
  Migration object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.migration.length * 3;
  return bytesCount;
}

void _migrationSerialize(
  Migration object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.migration);
}

Migration _migrationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Migration();
  object.id = id;
  object.migration = reader.readString(offsets[0]);
  return object;
}

P _migrationDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _migrationGetId(Migration object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _migrationGetLinks(Migration object) {
  return [];
}

void _migrationAttach(IsarCollection<dynamic> col, Id id, Migration object) {
  object.id = id;
}

extension MigrationQueryWhereSort
    on QueryBuilder<Migration, Migration, QWhere> {
  QueryBuilder<Migration, Migration, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MigrationQueryWhere
    on QueryBuilder<Migration, Migration, QWhereClause> {
  QueryBuilder<Migration, Migration, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Migration, Migration, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Migration, Migration, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Migration, Migration, QAfterWhereClause> idBetween(
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

extension MigrationQueryFilter
    on QueryBuilder<Migration, Migration, QFilterCondition> {
  QueryBuilder<Migration, Migration, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Migration, Migration, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Migration, Migration, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Migration, Migration, QAfterFilterCondition> migrationEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'migration',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterFilterCondition>
      migrationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'migration',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterFilterCondition> migrationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'migration',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterFilterCondition> migrationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'migration',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterFilterCondition> migrationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'migration',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterFilterCondition> migrationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'migration',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterFilterCondition> migrationContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'migration',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterFilterCondition> migrationMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'migration',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterFilterCondition> migrationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'migration',
        value: '',
      ));
    });
  }

  QueryBuilder<Migration, Migration, QAfterFilterCondition>
      migrationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'migration',
        value: '',
      ));
    });
  }
}

extension MigrationQueryObject
    on QueryBuilder<Migration, Migration, QFilterCondition> {}

extension MigrationQueryLinks
    on QueryBuilder<Migration, Migration, QFilterCondition> {}

extension MigrationQuerySortBy on QueryBuilder<Migration, Migration, QSortBy> {
  QueryBuilder<Migration, Migration, QAfterSortBy> sortByMigration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'migration', Sort.asc);
    });
  }

  QueryBuilder<Migration, Migration, QAfterSortBy> sortByMigrationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'migration', Sort.desc);
    });
  }
}

extension MigrationQuerySortThenBy
    on QueryBuilder<Migration, Migration, QSortThenBy> {
  QueryBuilder<Migration, Migration, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Migration, Migration, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Migration, Migration, QAfterSortBy> thenByMigration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'migration', Sort.asc);
    });
  }

  QueryBuilder<Migration, Migration, QAfterSortBy> thenByMigrationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'migration', Sort.desc);
    });
  }
}

extension MigrationQueryWhereDistinct
    on QueryBuilder<Migration, Migration, QDistinct> {
  QueryBuilder<Migration, Migration, QDistinct> distinctByMigration(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'migration', caseSensitive: caseSensitive);
    });
  }
}

extension MigrationQueryProperty
    on QueryBuilder<Migration, Migration, QQueryProperty> {
  QueryBuilder<Migration, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Migration, String, QQueryOperations> migrationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'migration');
    });
  }
}
