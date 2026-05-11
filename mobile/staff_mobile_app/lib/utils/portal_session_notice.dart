class PortalSessionNotice {
  static String? _pendingMessage;

  static void store(String message) {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return;
    }

    _pendingMessage = normalized;
  }

  static String? consume() {
    final message = _pendingMessage;
    _pendingMessage = null;
    return message;
  }
}
