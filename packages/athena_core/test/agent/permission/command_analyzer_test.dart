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
        r'echo $PATH',
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
