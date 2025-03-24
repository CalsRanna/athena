enum McpMethod {
  callTool('tools/call'),
  initialize('initialize'),
  listTools('tools/list'),
  notificationsInitialized('notifications/initialized'),
  ping('ping');

  final String value;
  const McpMethod(this.value);
}
