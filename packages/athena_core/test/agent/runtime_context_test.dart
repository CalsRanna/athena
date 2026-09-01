import 'package:athena_core/agent/runtime_context.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:test/test.dart';

void main() {
  test('gui 环境提示包含 GUI 客户端与当前平台', () {
    final prompt = runtimeContextPrompt(RuntimeEnvironment.gui);
    expect(prompt, contains('Athena GUI application'));
    expect(prompt, contains(_platformName()));
  });

  test('tui 环境提示包含终端客户端与当前平台', () {
    final prompt = runtimeContextPrompt(RuntimeEnvironment.tui);
    expect(prompt, contains('Athena TUI (terminal)'));
    expect(prompt, contains(_platformName()));
  });

  test('提示声明应用数据由工具管理', () {
    final prompt = runtimeContextPrompt(RuntimeEnvironment.gui);
    expect(prompt, contains('managed through your tools'));
  });
}

/// 当前测试平台的期望名（测试在 macOS/Linux/Windows CI 上都应通过）。
String _platformName() {
  if (PlatformUtil.isMacOS) return 'macOS';
  if (PlatformUtil.isWindows) return 'Windows';
  if (PlatformUtil.isLinux) return 'Linux';
  if (PlatformUtil.isIOS) return 'iOS';
  if (PlatformUtil.isAndroid) return 'Android';
  return 'an unknown platform';
}
