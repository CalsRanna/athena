import 'dart:io';

import 'package:athena/agent/permission/sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '/';

  group('PathSandbox L0 path denials', () {
    final sandbox = PathSandbox();

    test('denies ~/.ssh', () {
      expect(sandbox.canRead('$home/.ssh/id_rsa'), isFalse);
      expect(sandbox.canRead('~/.ssh/id_rsa'), isFalse);
    });

    test('denies ~/.aws', () {
      expect(sandbox.canRead('$home/.aws/credentials'), isFalse);
    });

    test('denies ~/.athena (self config)', () {
      expect(sandbox.canRead('$home/.athena/permissions.json'), isFalse);
      expect(sandbox.canWrite('$home/.athena/permissions.json'), isFalse);
    });

    test('denies ~/Documents/../.ssh/id_rsa via canonicalize', () {
      expect(sandbox.canRead('$home/Documents/../.ssh/id_rsa'), isFalse);
    });

    test('allows ~/Documents', () {
      expect(sandbox.canRead('$home/Documents/notes.md'), isTrue);
      expect(sandbox.canWrite('$home/Documents/notes.md'), isTrue);
    });

    test('allows /tmp', () {
      expect(sandbox.canWrite('/tmp/scratch.txt'), isTrue);
    });
  }, skip: !(Platform.isMacOS || Platform.isLinux)
      ? 'POSIX-only path layout'
      : null);

  group('PathSandbox injected data directory (S7)', () {
    final sandbox = PathSandbox(dataDirectory: '/tmp/athena_support');

    test('denies athena.db under data directory', () {
      expect(sandbox.canRead('/tmp/athena_support/athena.db'), isFalse);
    });

    test('denies nested write under data directory', () {
      expect(sandbox.canWrite('/tmp/athena_support/sub/x'), isFalse);
    });

    test('denies the data directory itself', () {
      expect(sandbox.canRead('/tmp/athena_support'), isFalse);
    });

    test('allows sibling path not under data directory', () {
      expect(sandbox.canRead('/tmp/other/file'), isTrue);
    });

    test('allows path sharing string prefix but not under data dir', () {
      expect(sandbox.canRead('/tmp/athena_support_evil/x'), isTrue);
    });

    test('when dataDirectory is null, defaults are unchanged', () {
      final plain = PathSandbox();
      expect(plain.canRead('/tmp/scratch.txt'), isTrue);
    });
  }, skip: !(Platform.isMacOS || Platform.isLinux)
      ? 'POSIX-only path layout'
      : null);
}
