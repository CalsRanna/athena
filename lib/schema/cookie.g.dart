// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cookie.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCookieCollection on Isar {
  IsarCollection<Cookie> get cookies => this.collection();
}

const CookieSchema = CollectionSchema(
  name: r'cookies',
  id: 4639120493137613042,
  properties: {
    r'cookie': PropertySchema(
      id: 0,
      name: r'cookie',
      type: IsarType.string,
    ),
    r'expired_at': PropertySchema(
      id: 1,
      name: r'expired_at',
      type: IsarType.long,
    )
  },
  estimateSize: _cookieEstimateSize,
  serialize: _cookieSerialize,
  deserialize: _cookieDeserialize,
  deserializeProp: _cookieDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _cookieGetId,
  getLinks: _cookieGetLinks,
  attach: _cookieAttach,
  version: '3.1.0+1',
);

int _cookieEstimateSize(
  Cookie object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cookie.length * 3;
  return bytesCount;
}

void _cookieSerialize(
  Cookie object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cookie);
  writer.writeLong(offsets[1], object.expiredAt);
}

Cookie _cookieDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Cookie();
  object.cookie = reader.readString(offsets[0]);
  object.expiredAt = reader.readLong(offsets[1]);
  object.id = id;
  return object;
}

P _cookieDeserializeProp<P>(
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
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _cookieGetId(Cookie object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _cookieGetLinks(Cookie object) {
  return [];
}

void _cookieAttach(IsarCollection<dynamic> col, Id id, Cookie object) {
  object.id = id;
}

extension CookieQueryWhereSort on QueryBuilder<Cookie, Cookie, QWhere> {
  QueryBuilder<Cookie, Cookie, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CookieQueryWhere on QueryBuilder<Cookie, Cookie, QWhereClause> {
  QueryBuilder<Cookie, Cookie, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Cookie, Cookie, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterWhereClause> idBetween(
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

extension CookieQueryFilter on QueryBuilder<Cookie, Cookie, QFilterCondition> {
  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> cookieEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cookie',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> cookieGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cookie',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> cookieLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cookie',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> cookieBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cookie',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> cookieStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cookie',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> cookieEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cookie',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> cookieContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cookie',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> cookieMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cookie',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> cookieIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cookie',
        value: '',
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> cookieIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cookie',
        value: '',
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> expiredAtEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expired_at',
        value: value,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> expiredAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expired_at',
        value: value,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> expiredAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expired_at',
        value: value,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> expiredAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expired_at',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Cookie, Cookie, QAfterFilterCondition> idBetween(
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
}

extension CookieQueryObject on QueryBuilder<Cookie, Cookie, QFilterCondition> {}

extension CookieQueryLinks on QueryBuilder<Cookie, Cookie, QFilterCondition> {}

extension CookieQuerySortBy on QueryBuilder<Cookie, Cookie, QSortBy> {
  QueryBuilder<Cookie, Cookie, QAfterSortBy> sortByCookie() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookie', Sort.asc);
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterSortBy> sortByCookieDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookie', Sort.desc);
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterSortBy> sortByExpiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expired_at', Sort.asc);
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterSortBy> sortByExpiredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expired_at', Sort.desc);
    });
  }
}

extension CookieQuerySortThenBy on QueryBuilder<Cookie, Cookie, QSortThenBy> {
  QueryBuilder<Cookie, Cookie, QAfterSortBy> thenByCookie() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookie', Sort.asc);
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterSortBy> thenByCookieDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cookie', Sort.desc);
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterSortBy> thenByExpiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expired_at', Sort.asc);
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterSortBy> thenByExpiredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expired_at', Sort.desc);
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Cookie, Cookie, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension CookieQueryWhereDistinct on QueryBuilder<Cookie, Cookie, QDistinct> {
  QueryBuilder<Cookie, Cookie, QDistinct> distinctByCookie(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cookie', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Cookie, Cookie, QDistinct> distinctByExpiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expired_at');
    });
  }
}

extension CookieQueryProperty on QueryBuilder<Cookie, Cookie, QQueryProperty> {
  QueryBuilder<Cookie, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Cookie, String, QQueryOperations> cookieProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cookie');
    });
  }

  QueryBuilder<Cookie, int, QQueryOperations> expiredAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expired_at');
    });
  }
}
