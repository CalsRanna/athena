// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$summaryNotifierHash() => r'5624747b7f726bc21041826cfa9d2cc32c235cec';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$SummaryNotifier
    extends BuildlessAutoDisposeAsyncNotifier<Summary> {
  late final int id;

  FutureOr<Summary> build(
    int id,
  );
}

/// See also [SummaryNotifier].
@ProviderFor(SummaryNotifier)
const summaryNotifierProvider = SummaryNotifierFamily();

/// See also [SummaryNotifier].
class SummaryNotifierFamily extends Family<AsyncValue<Summary>> {
  /// See also [SummaryNotifier].
  const SummaryNotifierFamily();

  /// See also [SummaryNotifier].
  SummaryNotifierProvider call(
    int id,
  ) {
    return SummaryNotifierProvider(
      id,
    );
  }

  @override
  SummaryNotifierProvider getProviderOverride(
    covariant SummaryNotifierProvider provider,
  ) {
    return call(
      provider.id,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'summaryNotifierProvider';
}

/// See also [SummaryNotifier].
class SummaryNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<SummaryNotifier, Summary> {
  /// See also [SummaryNotifier].
  SummaryNotifierProvider(
    int id,
  ) : this._internal(
          () => SummaryNotifier()..id = id,
          from: summaryNotifierProvider,
          name: r'summaryNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$summaryNotifierHash,
          dependencies: SummaryNotifierFamily._dependencies,
          allTransitiveDependencies:
              SummaryNotifierFamily._allTransitiveDependencies,
          id: id,
        );

  SummaryNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final int id;

  @override
  FutureOr<Summary> runNotifierBuild(
    covariant SummaryNotifier notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(SummaryNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: SummaryNotifierProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<SummaryNotifier, Summary>
      createElement() {
    return _SummaryNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SummaryNotifierProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SummaryNotifierRef on AutoDisposeAsyncNotifierProviderRef<Summary> {
  /// The parameter `id` of this provider.
  int get id;
}

class _SummaryNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<SummaryNotifier, Summary>
    with SummaryNotifierRef {
  _SummaryNotifierProviderElement(super.provider);

  @override
  int get id => (origin as SummaryNotifierProvider).id;
}

String _$summariesNotifierHash() => r'289f940116833e239afe0f311aefe7d0609e69d5';

/// See also [SummariesNotifier].
@ProviderFor(SummariesNotifier)
final summariesNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SummariesNotifier, List<Summary>>.internal(
  SummariesNotifier.new,
  name: r'summariesNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$summariesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SummariesNotifier = AutoDisposeAsyncNotifier<List<Summary>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
