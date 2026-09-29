import 'dart:io';

import 'package:athena_core/agent/tool/file_update_tool.dart';
import 'package:athena_core/util/path_normalizer.dart';
import 'package:test/test.dart';

void main() {
  // 临时目录在 macOS 上位于符号链接之下（/var → /private/var）。工具在
  // 执行前用 realPathChangedSinceApproval 复核路径，传入未解析的路径会被
  // 判为「审批后链接被替换」而拒绝执行，所以基准一律取真实路径。
  late String root;
  late FileUpdateTool tool;

  setUp(() {
    root = normalizePathForMatch(
      Directory.systemTemp
          .createTempSync('athena_file_update_')
          .resolveSymbolicLinksSync(),
    );
    tool = FileUpdateTool();
  });

  tearDown(() => Directory(root).deleteSync(recursive: true));

  File writeFile(String name, String content) {
    final file = File('$root/$name');
    file.writeAsStringSync(content);
    return file;
  }

  Future<String> update(
    File file, {
    required String oldString,
    required String newString,
    bool replaceAll = false,
  }) {
    return tool.execute({
      'path': file.path,
      'old_string': oldString,
      'new_string': newString,
      if (replaceAll) 'replace_all': true,
    });
  }

  group('替换只落在那一段，文件其余部分逐字符保留', () {
    // 匹配是在 _normalizeQuotes(content) 上做的（模型可能拿直引号去匹配
    // 弯引号文件），但归一化串只用于定位，替换必须切回原文——否则改一行
    // 会把整份文件的弯引号拉直。这是本条约束的回归测试。
    test('替换不含引号的一行：文件里其余的弯引号原样保留', () async {
      final file = writeFile('prose.md', '第一行\n他说“你好”\n第三行\n');

      final result = await update(file, oldString: '第三行', newString: '第三行（已改）');

      expect(result, startsWith('Successfully updated'));
      expect(file.readAsStringSync(), '第一行\n他说“你好”\n第三行（已改）\n');
    });

    test('单引号与书名号形态同样原样保留', () async {
      final file = writeFile('prose2.md', '他说‘好’，书名《X》\n目标是这行\n');

      await update(file, oldString: '目标是这行', newString: '目标已改');

      expect(file.readAsStringSync(), '他说‘好’，书名《X》\n目标已改\n');
    });

    test('直引号文件不受影响', () async {
      final file = writeFile('plain.md', 'plain "text" here\n');

      await update(file, oldString: 'here', newString: 'there');

      expect(file.readAsStringSync(), 'plain "text" there\n');
    });

    test('replace_all：每处替换都生效，未匹配处的弯引号保留', () async {
      final file = writeFile('many.md', '甲“一”\n目标\n乙“二”\n目标\n');

      await update(file, oldString: '目标', newString: '完成', replaceAll: true);

      expect(file.readAsStringSync(), '甲“一”\n完成\n乙“二”\n完成\n');
    });
  });

  group('既有的宽松匹配能力要保住', () {
    // 模型从 file_read 拿到的是原文（弯引号），但它可能写成直引号来匹配。
    // _preprocess 把 old_string 归一化就是为了这个。被替换段内的文本取自
    // 模型的 new_string，不保证还原成弯引号。
    test('直引号 old_string 能匹配到弯引号内容', () async {
      final file = writeFile('lenient.md', 'A“x”B\n尾部\n');

      final result = await update(file, oldString: '"x"', newString: '"y"');

      expect(result, startsWith('Successfully updated'));
      expect(file.readAsStringSync(), 'A"y"B\n尾部\n');
    });

    test('old_string 里的行号前缀被剥掉', () async {
      final file = writeFile('numbered.md', 'alpha\nbeta\n');

      final result = await update(
        file,
        oldString: '1\tbeta',
        newString: 'gamma',
      );

      expect(result, startsWith('Successfully updated'));
      expect(file.readAsStringSync(), 'alpha\ngamma\n');
    });
  });

  group('删除与失败路径', () {
    test('删除整行时吃掉它留下的换行（沿用既有行为）', () async {
      final file = writeFile('del.md', 'keep\nremove\nlast\n');

      await update(file, oldString: 'remove', newString: '');

      expect(file.readAsStringSync(), 'keep\nlast\n');
    });

    test('未找到时返回 Error 且文件一字未改', () async {
      const original = '他说“你好”\n';
      final file = writeFile('missing.md', original);

      final result = await update(file, oldString: '不存在的内容', newString: 'x');

      expect(result, startsWith('Error: old_string not found'));
      expect(file.readAsStringSync(), original);
    });

    test('old_string 多次出现且未开 replace_all 时拒绝执行', () async {
      const original = 'dup\ndup\n';
      final file = writeFile('dup.md', original);

      final result = await update(file, oldString: 'dup', newString: 'x');

      expect(result, startsWith('Error: old_string appears 2 times'));
      expect(file.readAsStringSync(), original);
    });
  });

  group('不丢文件权限', () {
    // 写入改走「临时文件 + rename」后，临时文件是新 inode、默认 0644，
    // 不把原 mode 套回去就会把可执行脚本改成不可执行——静默的功能损失。
    test('编辑可执行脚本后 0755 仍在', () async {
      final file = writeFile('run.sh', '#!/bin/sh\necho old\n');
      await Process.run('chmod', ['755', file.path]);
      expect(file.statSync().mode & 0xFFF, 0x1ED, reason: '前置条件：0755');

      final result = await update(
        file,
        oldString: 'echo old',
        newString: 'echo new',
      );

      expect(result, startsWith('Successfully updated'));
      expect(file.statSync().mode & 0xFFF, 0x1ED);
      expect(file.readAsStringSync(), '#!/bin/sh\necho new\n');
    });
  });
}
