import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_core/agent/skill/skill_registry.dart';
import 'package:athena_core/agent/tool/file_read_tool.dart';
import 'package:athena_core/agent/tool/skill_tool.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late Directory skillDir;
  late File guide;
  late SkillRegistry registry;
  late SkillTool tool;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('skill resource test ');
    skillDir = Directory(p.join(temp.path, '.athena', 'skills', 'demo'));
    SkillLoader().saveSkill(
      name: 'demo',
      description: 'Test bundled resources',
      body: 'Read [the guide](references/guide.md) when needed.',
      targetDir: skillDir.path,
    );
    guide = File(p.join(skillDir.path, 'references', 'guide.md'));
    await guide.parent.create();
    await guide.writeAsString('First line\n中文参考资料\nLast line');
    registry = SkillRegistry()..loadAll(homeDir: temp.path);
    tool = SkillTool(registry);
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  Future<String> read(String resource, {int? offset, int? limit}) {
    return tool.execute({
      'name': 'demo',
      'resource': resource,
      if (offset != null) 'offset': offset,
      if (limit != null) 'limit': limit,
    });
  }

  test(
    'loading exposes the skill directory without loading referenced files',
    () async {
      final result = await tool.execute({'name': 'demo'});
      expect(
        result,
        contains('Directory: ${p.normalize(p.absolute(skillDir.path))}'),
      );
      expect(
        result,
        contains('Read [the guide](references/guide.md) when needed.'),
      );
      expect(result, contains('resource path'));
      expect(result, contains('absolute script path'));
      expect(result, isNot(contains('中文参考资料')));
    },
  );

  test(
    'resource reads work under .athena without opening generic file access',
    () async {
      final result = await read('references/guide.md');
      expect(result, contains('Resource: references/guide.md'));
      expect(result, contains('Path: ${await guide.resolveSymbolicLinks()}'));
      expect(result, contains('[lines 1-3 / 3 total]'));
      expect(result, contains('2\t中文参考资料'));
      expect(registry.currentContext, isNull);
      expect(
        await FileReadTool().execute({'path': guide.path}),
        startsWith('Error: Blocked:'),
      );
    },
  );

  test(
    'resources resolve by explicit skill name across successive loads',
    () async {
      final other = Directory(p.join(temp.path, '.athena', 'skills', 'other'));
      SkillLoader().saveSkill(
        name: 'other',
        description: 'Other',
        body: 'Other body',
        targetDir: other.path,
      );
      final otherGuide = File(p.join(other.path, 'references', 'guide.md'));
      await otherGuide.parent.create();
      await otherGuide.writeAsString('Other resource');
      registry.reload();
      await tool.execute({'name': 'other'});
      expect(await read('references/guide.md'), contains('中文参考资料'));
      final result = await tool.execute({
        'name': 'other',
        'resource': 'references/guide.md',
      });
      expect(result, contains('Other resource'));
      expect(result, isNot(contains('中文参考资料')));
      expect(registry.currentContext?.name, 'other');
    },
  );

  test(
    'normalizes relative segments and accepts either separator style',
    () async {
      expect(
        await read('./references/../references/guide.md'),
        contains('中文参考资料'),
      );
      expect(await read(r'references\guide.md'), contains('中文参考资料'));
    },
  );

  test('defaults to 200 lines and advertises the next page', () async {
    await guide.writeAsString(List.generate(205, (i) => 'line $i').join('\n'));
    final first = await read('references/guide.md');
    expect(first, contains('[lines 1-200 / 205 total]'));
    expect(first, contains('200\tline 199'));
    expect(first, isNot(contains('201\tline 200')));
    expect(first, contains('Use offset=200 to continue.'));
    final next = await read('references/guide.md', offset: 200, limit: 5);
    expect(next, contains('[lines 201-205 / 205 total]'));
    expect(next, contains('205\tline 204'));
    expect(next, isNot(contains('to continue')));
  });

  test('maximum page size and an offset beyond EOF remain bounded', () async {
    await guide.writeAsString(List.generate(2001, (i) => 'line $i').join('\n'));
    final result = await read('references/guide.md', limit: 2000);
    expect(result, contains('[lines 1-2000 / 2001 total]'));
    expect(result, isNot(contains('2001\tline 2000')));
    final empty = await read('references/guide.md', offset: 3000);
    expect(empty, isNot(contains('\tline')));
  });

  test('large UTF-8 resources use the shared streaming pagination', () async {
    final body = StringBuffer();
    for (var i = 0; i < 4000; i++) {
      body.writeln('line $i ${'资料' * 250}');
    }
    await guide.writeAsString(body.toString());
    expect(await guide.length(), greaterThan(5 * 1024 * 1024));
    final result = await read('references/guide.md', offset: 2100, limit: 2);
    expect(result, contains('[lines 2101-2102 / 4000 total]'));
    expect(result, contains('2101\tline 2100 资料'));
    expect(result, contains('(streamed)'));
    expect(result, contains('Use offset=2102 to continue.'));
    expect(result, isNot(contains('2103\t')));
  });

  for (final resource in [
    '',
    '/etc/passwd',
    r'C:\outside.txt',
    r'C:outside.txt',
    r'\rooted.txt',
    r'\\server\share\outside.txt',
    'bad\u0000file',
  ]) {
    test(
      'rejects non-relative resource ${resource.replaceAll('\u0000', '<NUL>')}',
      () async {
        expect(await read(resource), contains('non-empty relative file path'));
      },
    );
  }

  for (final resource in [
    '../secret.txt',
    '../../permissions.json',
    '../demo-other/guide.md',
    r'..\secret.txt',
    '.',
    'references/../../secret.txt',
  ]) {
    test('rejects traversal $resource', () async {
      expect(await read(resource), contains('inside the skill directory'));
    });
  }

  for (final page in [(-1, 1), (0, 0), (0, -1), (0, 2001)]) {
    test('rejects invalid pagination $page', () async {
      expect(
        await read('references/guide.md', offset: page.$1, limit: page.$2),
        startsWith('Error:'),
      );
    });
  }

  test('pagination requires an explicit resource', () async {
    expect(
      await tool.execute({'name': 'demo', 'offset': 1}),
      contains('require a resource path'),
    );
  });

  test(
    'missing skill, file, and directory resources return useful errors',
    () async {
      expect(
        await tool.execute({'name': 'unknown', 'resource': 'guide.md'}),
        contains('not found'),
      );
      expect(await read('missing.md'), contains('Cannot read resource'));
      expect(await read('references'), contains('must be a text file'));
    },
  );

  test('non-text data reports a decoding error', () async {
    await guide.writeAsBytes([0xff, 0xfe, 0xff]);
    final result = await read('references/guide.md');
    expect(result, startsWith('Error:'));
    expect(result.toLowerCase(), contains('utf-8'));
  });

  test('script source is read without executing it', () async {
    final script = File(p.join(skillDir.path, 'scripts', 'run.sh'));
    final marker = File(p.join(temp.path, 'executed-marker'));
    await script.parent.create();
    await script.writeAsString('touch "${marker.path}"');
    final result = await read('scripts/run.sh');
    expect(result, contains('1\ttouch "${marker.path}"'));
    expect(await marker.exists(), isFalse);
  });

  test(
    'built-in skills load without exposing a fictional resource directory',
    () async {
      registry.registerBuiltin(
        const Skill(
          name: 'builtin',
          description: 'Built in',
          body: 'Built-in instructions',
          sourcePath: '(builtin)',
        ),
      );
      final result = await tool.execute({'name': 'builtin'});
      expect(result, contains('Built-in instructions'));
      expect(result, isNot(contains('Directory:')));
      expect(
        await tool.execute({
          'name': 'builtin',
          'resource': 'references/guide.md',
        }),
        contains('has no resource directory'),
      );
    },
  );

  group(
    'symbolic links',
    () {
      test(
        'allows a resource link whose real target stays inside the skill',
        () async {
          await Link(p.join(skillDir.path, 'guide-link.md')).create(guide.path);
          expect(await read('guide-link.md'), contains('中文参考资料'));
        },
      );

      test('rejects a file link to another skill or Athena settings', () async {
        final outside = File(p.join(temp.path, '.athena', 'permissions.json'));
        await outside.writeAsString('private outside resource');
        await Link(p.join(skillDir.path, 'outside.md')).create(outside.path);
        final result = await read('outside.md');
        expect(result, contains('outside the skill directory'));
        expect(result, isNot(contains('private outside resource')));
      });

      test('rejects a directory link leading outside the skill', () async {
        await Link(p.join(skillDir.path, 'outside')).create(temp.path);
        final secret = File(p.join(temp.path, 'secret.md'));
        await secret.writeAsString('outside secret');
        final result = await read('outside/secret.md');
        expect(result, contains('outside the skill directory'));
        expect(result, isNot(contains('outside secret')));
      });

      test(
        'resolves a linked skill root before checking its resources',
        () async {
          final alias = Link(p.join(temp.path, 'skill-alias'));
          await alias.create(skillDir.path);
          registry.reloadSkill('demo', alias.path);
          expect(await read('references/guide.md'), contains('中文参考资料'));
        },
      );

      test('broken links and cycles return errors', () async {
        await Link(
          p.join(skillDir.path, 'missing-link'),
        ).create(p.join(temp.path, 'absent'));
        await Link(
          p.join(skillDir.path, 'cycle-a'),
        ).create(p.join(skillDir.path, 'cycle-b'));
        await Link(
          p.join(skillDir.path, 'cycle-b'),
        ).create(p.join(skillDir.path, 'cycle-a'));
        expect(await read('missing-link'), startsWith('Error:'));
        expect(await read('cycle-a'), startsWith('Error:'));
      });
    },
    skip: Platform.isWindows
        ? 'Creating symbolic links requires Windows privileges.'
        : false,
  );
}
