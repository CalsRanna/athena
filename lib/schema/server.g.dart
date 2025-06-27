// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetServerCollection on Isar {
  IsarCollection<Server> get servers => this.collection();
}

const ServerSchema = CollectionSchema(
  name: r'servers',
  id: -1968215853883215406,
  properties: {
    r'arguments': PropertySchema(
      id: 0,
      name: r'arguments',
      type: IsarType.string,
    ),
    r'command': PropertySchema(
      id: 1,
      name: r'command',
      type: IsarType.string,
    ),
    r'description': PropertySchema(
      id: 2,
      name: r'description',
      type: IsarType.string,
    ),
    r'enabled': PropertySchema(
      id: 3,
      name: r'enabled',
      type: IsarType.bool,
    ),
    r'environments': PropertySchema(
      id: 4,
      name: r'environments',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 5,
      name: r'name',
      type: IsarType.string,
    ),
    r'tools': PropertySchema(
      id: 6,
      name: r'tools',
      type: IsarType.string,
    )
  },
  estimateSize: _serverEstimateSize,
  serialize: _serverSerialize,
  deserialize: _serverDeserialize,
  deserializeProp: _serverDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _serverGetId,
  getLinks: _serverGetLinks,
  attach: _serverAttach,
  version: '3.1.8',
);

int _serverEstimateSize(
  Server object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.arguments.length * 3;
  bytesCount += 3 + object.command.length * 3;
  bytesCount += 3 + object.description.length * 3;
  bytesCount += 3 + object.environments.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.tools.length * 3;
  return bytesCount;
}

void _serverSerialize(
  Server object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.arguments);
  writer.writeString(offsets[1], object.command);
  writer.writeString(offsets[2], object.description);
  writer.writeBool(offsets[3], object.enabled);
  writer.writeString(offsets[4], object.environments);
  writer.writeString(offsets[5], object.name);
  writer.writeString(offsets[6], object.tools);
}

Server _serverDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Server();
  object.arguments = reader.readString(offsets[0]);
  object.command = reader.readString(offsets[1]);
  object.description = reader.readString(offsets[2]);
  object.enabled = reader.readBool(offsets[3]);
  object.environments = reader.readString(offsets[4]);
  object.id = id;
  object.name = reader.readString(offsets[5]);
  object.tools = reader.readString(offsets[6]);
  return object;
}

P _serverDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _serverGetId(Server object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _serverGetLinks(Server object) {
  return [];
}

void _serverAttach(IsarCollection<dynamic> col, Id id, Server object) {
  object.id = id;
}

extension ServerQueryWhereSort on QueryBuilder<Server, Server, QWhere> {
  QueryBuilder<Server, Server, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ServerQueryWhere on QueryBuilder<Server, Server, QWhereClause> {
  QueryBuilder<Server, Server, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Server, Server, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Server, Server, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Server, Server, QAfterWhereClause> idBetween(
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

extension ServerQueryFilter on QueryBuilder<Server, Server, QFilterCondition> {
  QueryBuilder<Server, Server, QAfterFilterCondition> argumentsEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'arguments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> argumentsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'arguments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> argumentsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'arguments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> argumentsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'arguments',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> argumentsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'arguments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> argumentsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'arguments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> argumentsContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'arguments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> argumentsMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'arguments',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> argumentsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'arguments',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> argumentsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'arguments',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> commandEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'command',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> commandGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'command',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> commandLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'command',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> commandBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'command',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> commandStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'command',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> commandEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'command',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> commandContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'command',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> commandMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'command',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> commandIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'command',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> commandIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'command',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> descriptionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> descriptionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> descriptionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> descriptionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'description',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> descriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> descriptionContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> descriptionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> enabledEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'enabled',
        value: value,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> environmentsEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'environments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> environmentsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'environments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> environmentsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'environments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> environmentsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'environments',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> environmentsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'environments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> environmentsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'environments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> environmentsContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'environments',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> environmentsMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'environments',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> environmentsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'environments',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> environmentsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'environments',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Server, Server, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Server, Server, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Server, Server, QAfterFilterCondition> nameEqualTo(
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

  QueryBuilder<Server, Server, QAfterFilterCondition> nameGreaterThan(
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

  QueryBuilder<Server, Server, QAfterFilterCondition> nameLessThan(
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

  QueryBuilder<Server, Server, QAfterFilterCondition> nameBetween(
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

  QueryBuilder<Server, Server, QAfterFilterCondition> nameStartsWith(
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

  QueryBuilder<Server, Server, QAfterFilterCondition> nameEndsWith(
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

  QueryBuilder<Server, Server, QAfterFilterCondition> nameContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> nameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> toolsEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tools',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> toolsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tools',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> toolsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tools',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> toolsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tools',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> toolsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tools',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> toolsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tools',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> toolsContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tools',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> toolsMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tools',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> toolsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tools',
        value: '',
      ));
    });
  }

  QueryBuilder<Server, Server, QAfterFilterCondition> toolsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tools',
        value: '',
      ));
    });
  }
}

extension ServerQueryObject on QueryBuilder<Server, Server, QFilterCondition> {}

extension ServerQueryLinks on QueryBuilder<Server, Server, QFilterCondition> {}

extension ServerQuerySortBy on QueryBuilder<Server, Server, QSortBy> {
  QueryBuilder<Server, Server, QAfterSortBy> sortByArguments() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'arguments', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByArgumentsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'arguments', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByCommand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'command', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByCommandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'command', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enabled', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enabled', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByEnvironments() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'environments', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByEnvironmentsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'environments', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByTools() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tools', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> sortByToolsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tools', Sort.desc);
    });
  }
}

extension ServerQuerySortThenBy on QueryBuilder<Server, Server, QSortThenBy> {
  QueryBuilder<Server, Server, QAfterSortBy> thenByArguments() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'arguments', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByArgumentsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'arguments', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByCommand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'command', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByCommandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'command', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enabled', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enabled', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByEnvironments() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'environments', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByEnvironmentsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'environments', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByTools() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tools', Sort.asc);
    });
  }

  QueryBuilder<Server, Server, QAfterSortBy> thenByToolsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tools', Sort.desc);
    });
  }
}

extension ServerQueryWhereDistinct on QueryBuilder<Server, Server, QDistinct> {
  QueryBuilder<Server, Server, QDistinct> distinctByArguments(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'arguments', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Server, Server, QDistinct> distinctByCommand(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'command', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Server, Server, QDistinct> distinctByDescription(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Server, Server, QDistinct> distinctByEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'enabled');
    });
  }

  QueryBuilder<Server, Server, QDistinct> distinctByEnvironments(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'environments', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Server, Server, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Server, Server, QDistinct> distinctByTools(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tools', caseSensitive: caseSensitive);
    });
  }
}

extension ServerQueryProperty on QueryBuilder<Server, Server, QQueryProperty> {
  QueryBuilder<Server, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Server, String, QQueryOperations> argumentsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'arguments');
    });
  }

  QueryBuilder<Server, String, QQueryOperations> commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'command');
    });
  }

  QueryBuilder<Server, String, QQueryOperations> descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<Server, bool, QQueryOperations> enabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'enabled');
    });
  }

  QueryBuilder<Server, String, QQueryOperations> environmentsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'environments');
    });
  }

  QueryBuilder<Server, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Server, String, QQueryOperations> toolsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tools');
    });
  }
}
