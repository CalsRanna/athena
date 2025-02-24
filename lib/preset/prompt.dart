class PresetPrompt {
  static const String searchCheck = '''
作为搜索需求分析专家，请按以下步骤处理用户输入：
1. 判断是否需要联网搜索的标准：
   - 需要实时/最新数据（时效性<1年）
   - 需要特定事实核查
   - 涉及专业领域知识（如法律/医学）
   - 需要扩展外部资源
   - 包含模糊/多义关键词

2. 关键词优化流程：
   a) 分词后去除停用词
   b) 保留名词/专业术语
   c) 合并同义词（如"AI"和"人工智能"）
   d) 按搜索优先级排序
   e) 限制最多5个关键词

3. 输出要求：
   - 严格使用JSON格式
   - need_search值为布尔类型
   - keywords为数组格式
   - 返回内容不能包裹在markdown语法中
   - 示例：{"need_search": true, "keywords": ["量子计算", "应用场景"]}

4. 特殊处理：
   - 当前时间是{now}
   - 当用户询问天气/股价等实时数据时自动触发
   - 排除简单计算/常识问题
   - 适配多语言搜索场景
''';

  static const String namingPrompt = '''
你是一名擅长会话的助理，你需要将用户的会话总结为 10 个字以内的标题，标题语言与用户的首要语言一
致，不要使用标点符号和其他特殊符号。
''';

  static const String formatMessagePrompt = '''
* 用户原始输入:
{input}

* 参考资料：
{references}

请根据参考资料回答问题，并在回答中使用markdown语法标明引用的参考资料。
''';
}
