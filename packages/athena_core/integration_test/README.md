# 真实模型经验评测

`experience_model_eval_test.dart` 使用真实 provider 和生产提示词、工具 schema、反思解析器及工具执行路径，比较主动记录与自动反思的写入决策。10 个固定人工场景，每个场景分别请求两条路径，共 20 次模型请求。

覆盖临时端口、任务进度、未验证归因、已有项目规范、普通拼写修复、明确长期偏好、经过验证的稳定机制、重复经验、纠正旧经验、仅当次有效的偏好。预期标签只用于评分，不发送给模型。

在 `packages/athena_core` 下执行：

```sh
ATHENA_EVAL_PROVIDER_FILE="$HOME/.athena/providers/<provider-id>.yaml" \
ATHENA_EVAL_MODEL='<该 provider 中的 modelId>' \
ATHENA_EVAL_REPORT='/tmp/athena-experience-eval.json' \
dart test integration_test/experience_model_eval_test.dart --reporter expanded
```

- 显式配置两个模型环境变量才调用远端；不配置时跳过，普通 `dart test` 不包含本目录。
- 只读取 provider 文件中的现有配置，不修改设置，不读取真实会话。密钥只用于已配置 provider 的鉴权，不写入报告。
- 每个场景使用独立临时经验库，结束即删除，不写入用户的经验目录。
- 每次请求最多等待 90 秒，不自动重试；请求失败会停止并保存已完成结果，错误不计为正确拒绝或漏记。
- JSON 报告包含模型、协议、样例摘要哈希、各场景输出、工具结果、最终经验、token 用量（provider 提供时）、耗时和分路径指标。默认报告位置为系统临时目录的 `athena-experience-eval.json`。

`decision_pass` 要求有效提案的动作与预期一致，修订还要选对原条目；`persistence_pass` 检查实际落库动作、作用域及关键事实词。写入被拦截不代表模型判断正确，因此还分别统计不应写入时的提案数、无效提案数、误记率和漏记率。重复场景若仍提议新增，即使工具去重成功，决策也判失败。

这是小样本的固定轨迹决策评测：主动路径以真实工具调用输出，反思路径以生产 JSON 提案输出；两者都只执行一次决策，不跑任务工具或自动反思触发策略。关键事实词只能发现明显遗漏，原始输出仍需人工复核；一次全通过不能代表真实任务正确率或后续任务收益。失败时保留报告，不通过反复重跑或放宽标签掩盖结果。
