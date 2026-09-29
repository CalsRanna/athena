import 'dart:async';
import 'dart:io';

import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:test/test.dart';

void main() {
  late String root;
  late String skillsPath;
  late SkillLoader loader;

  setUp(() {
    root = Directory.systemTemp.createTempSync('athena_skill_loader_').path;
    skillsPath = '$root/skills';
    Directory(skillsPath).createSync(recursive: true);
    loader = SkillLoader();
  });

  tearDown(() => Directory(root).deleteSync(recursive: true));

  void writeSkill(String dirName, String content) {
    final dir = Directory('$skillsPath/$dirName')..createSync(recursive: true);
    File('${dir.path}/SKILL.md').writeAsStringSync(content);
  }

  /// 捕获 LoggerUtil 的输出：Logger 的 ConsoleOutput 最终走 print，
  /// 用 Zone 拦 print 即可，不必给 LoggerUtil 加测试专用出口。
  List<String> captureLogs(void Function() body) {
    final lines = <String>[];
    runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    return lines;
  }

  group('parseSkillFile 与 saveSkill 互为逆操作', () {
    test('写入后读回，name / description / body 一致', () {
      loader.saveSkill(
        name: 'demo',
        description: 'a demo skill',
        body: 'step one\nstep two',
        targetDir: '$skillsPath/demo',
      );

      final skill = loader.parseSkillFile(File('$skillsPath/demo/SKILL.md'));

      expect(skill, isNotNull);
      expect(skill!.name, 'demo');
      expect(skill.description, 'a demo skill');
      expect(skill.body, 'step one\nstep two');
      expect(skill.sourcePath, '$skillsPath/demo');
      expect(skill.isBuiltin, isFalse);
    });

    test('description 含冒号、引号与换行时不被 YAML 破坏', () {
      const description = 'needs: "quotes" and\nnewline';
      loader.saveSkill(
        name: 'tricky',
        description: description,
        body: 'body',
        targetDir: '$skillsPath/tricky',
      );

      final skill = loader.parseSkillFile(File('$skillsPath/tricky/SKILL.md'));

      expect(skill?.description, description);
    });
  });

  group('非法内容被跳过：不中断扫描，且留下原因', () {
    test('缺 description 的那条被跳过，同目录下合法的照常加载', () {
      writeSkill('good', '---\nname: good\ndescription: fine\n---\nbody');
      writeSkill('nobody', '---\nname: nobody\n---\nbody');

      late List<Skill> loaded;
      final logs = captureLogs(
        () => loaded = loader.loadFromDirectory(skillsPath),
      );

      expect(loaded.map((s) => s.name), ['good']);
      expect(
        logs.any(
          (line) =>
              line.contains('Skill skipped') &&
              line.contains('nobody') &&
              line.contains('description'),
        ),
        isTrue,
        reason: '跳过必须留下可查的原因，实际日志: $logs',
      );
    });

    test('name 不是字符串时不抛 TypeError，只跳过这一条', () {
      // `as String?` 会让这条抛 TypeError，而 TypeError 不在 FormatException
      // 的捕获范围里，一条坏技能足以炸掉整个目录扫描。
      writeSkill('numeric', '---\nname: 123\ndescription: d\n---\nbody');
      writeSkill('good', '---\nname: good\ndescription: fine\n---\nbody');

      late List<Skill> loaded;
      expect(
        () => captureLogs(() => loaded = loader.loadFromDirectory(skillsPath)),
        returnsNormally,
      );
      expect(loaded.map((s) => s.name), ['good']);
    });

    test('各种畸形 front matter 都只是被跳过', () {
      writeSkill('good', '---\nname: good\ndescription: fine\n---\nbody');
      writeSkill('noopen', 'name: noopen\ndescription: d\n---\nbody');
      writeSkill('unclosed', '---\nname: unclosed\ndescription: d\nbody');
      writeSkill('badYaml', '---\nname: [unclosed\ndescription: d\n---\nbody');
      writeSkill('badName', '---\nname: a/b\ndescription: d\n---\nbody');
      writeSkill('emptyName', '---\nname: ""\ndescription: d\n---\nbody');

      late List<Skill> loaded;
      final logs = captureLogs(
        () => loaded = loader.loadFromDirectory(skillsPath),
      );

      expect(loaded.map((s) => s.name), ['good']);
      expect(logs.where((l) => l.contains('Skill skipped')).length, 5);
    });

    test('非 UTF-8 内容不炸掉扫描', () {
      writeSkill('good', '---\nname: good\ndescription: fine\n---\nbody');
      final dir = Directory('$skillsPath/binary')..createSync(recursive: true);
      File('${dir.path}/SKILL.md').writeAsBytesSync([0xff, 0xfe, 0x00, 0x80]);

      late List<Skill> loaded;
      expect(
        () => captureLogs(() => loaded = loader.loadFromDirectory(skillsPath)),
        returnsNormally,
      );
      expect(loaded.map((s) => s.name), ['good']);
    });

    test('没有 SKILL.md 的子目录安静跳过，不算异常', () {
      Directory('$skillsPath/notaskill').createSync(recursive: true);
      writeSkill('good', '---\nname: good\ndescription: fine\n---\nbody');

      late List<Skill> loaded;
      final logs = captureLogs(
        () => loaded = loader.loadFromDirectory(skillsPath),
      );

      expect(loaded.map((s) => s.name), ['good']);
      expect(logs, isEmpty);
    });

    test('目录不存在时返回空列表', () {
      expect(loader.loadFromDirectory('$root/nope'), isEmpty);
    });
  });

  group('读不出来的文件不吞成 null', () {
    test('parseSkillFile 对不存在的文件抛 I/O 异常', () {
      // 与「内容不合法」区分开：内容问题返回 null + 日志，I/O 问题交给调用方
      // 按工具错误处理，否则一次权限错误会被静默当成「技能不存在」。
      expect(
        () => loader.parseSkillFile(File('$root/nope/SKILL.md')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('isValidSkillName', () {
    test('放行常规名，拦住路径分隔符与保留名', () {
      expect(SkillLoader.isValidSkillName('my-skill_1'), isTrue);
      expect(SkillLoader.isValidSkillName(''), isFalse);
      expect(SkillLoader.isValidSkillName('a/b'), isFalse);
      expect(SkillLoader.isValidSkillName(r'a\b'), isFalse);
      expect(SkillLoader.isValidSkillName('.'), isFalse);
      expect(SkillLoader.isValidSkillName('..'), isFalse);
      expect(SkillLoader.isValidSkillName('a' * 65), isFalse);
      expect(SkillLoader.isValidSkillName('a\nb'), isFalse);
    });
  });
}
