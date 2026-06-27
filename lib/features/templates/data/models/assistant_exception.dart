class AssistantException implements Exception {
  final String message;
  final bool isKeyNotConfigured;

  const AssistantException(this.message, {this.isKeyNotConfigured = false});
}
