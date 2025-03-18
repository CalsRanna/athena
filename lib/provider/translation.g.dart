// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transitionsNotifierHash() =>
    r'ab6e92a260d4bed03046a1aa6a4892edd12d02a9';

/// See also [TransitionsNotifier].
@ProviderFor(TransitionsNotifier)
final transitionsNotifierProvider = AutoDisposeAsyncNotifierProvider<
    TransitionsNotifier, List<Translation>>.internal(
  TransitionsNotifier.new,
  name: r'transitionsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$transitionsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TransitionsNotifier = AutoDisposeAsyncNotifier<List<Translation>>;
String _$translationNotifierHash() =>
    r'770e97b91fb8b2b53f26a529f234bc225cc192fc';

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

abstract class _$TranslationNotifier
    extends BuildlessAutoDisposeAsyncNotifier<Translation> {
  late final int id;

  FutureOr<Translation> build(
    int id,
  );
}

/// See also [TranslationNotifier].
@ProviderFor(TranslationNotifier)
const translationNotifierProvider = TranslationNotifierFamily();

/// See also [TranslationNotifier].
class TranslationNotifierFamily extends Family<AsyncValue<Translation>> {
  /// See also [TranslationNotifier].
  const TranslationNotifierFamily();

  /// See also [TranslationNotifier].
  TranslationNotifierProvider call(
    int id,
  ) {
    return TranslationNotifierProvider(
      id,
    );
  }

  @override
  TranslationNotifierProvider getProviderOverride(
    covariant TranslationNotifierProvider provider,
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
  String? get name => r'translationNotifierProvider';
}

/// See also [TranslationNotifier].
class TranslationNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    TranslationNotifier, Translation> {
  /// See also [TranslationNotifier].
  TranslationNotifierProvider(
    int id,
  ) : this._internal(
          () => TranslationNotifier()..id = id,
          from: translationNotifierProvider,
          name: r'translationNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$translationNotifierHash,
          dependencies: TranslationNotifierFamily._dependencies,
          allTransitiveDependencies:
              TranslationNotifierFamily._allTransitiveDependencies,
          id: id,
        );

  TranslationNotifierProvider._internal(
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
  FutureOr<Translation> runNotifierBuild(
    covariant TranslationNotifier notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(TranslationNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: TranslationNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<TranslationNotifier, Translation>
      createElement() {
    return _TranslationNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TranslationNotifierProvider && other.id == id;
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
mixin TranslationNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<Translation> {
  /// The parameter `id` of this provider.
  int get id;
}

class _TranslationNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TranslationNotifier,
        Translation> with TranslationNotifierRef {
  _TranslationNotifierProviderElement(super.provider);

  @override
  int get id => (origin as TranslationNotifierProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
