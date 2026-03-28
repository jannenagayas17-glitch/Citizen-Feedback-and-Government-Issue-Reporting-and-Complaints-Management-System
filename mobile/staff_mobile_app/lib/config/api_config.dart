import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConfig {
  static const String _defaultAndroidEmulatorHost = '10.0.2.2';
  static const String _defaultLocalHost = '127.0.0.1';
  static const String _defaultPort = '8000';
  static const String _defaultScheme = 'http';

  static const String _fullBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String _hostOverride = String.fromEnvironment('API_HOST');
  static const String _portOverride = String.fromEnvironment('API_PORT');

  static String get baseUrl {
    final fullOverride = _fullBaseUrlOverride.trim();
    if (_isUsableOverride(fullOverride)) {
      return _normalizeBaseUrl(fullOverride);
    }

    final scheme = _resolvedScheme;
    final host = _resolvedHost;
    final port = _resolvedPort;
    return '$scheme://$host:$port/api';
  }

  static String get _resolvedScheme {
    if (kIsWeb) {
      final scheme = Uri.base.scheme.trim();
      if (scheme == 'http' || scheme == 'https') {
        return scheme;
      }
    }

    return _defaultScheme;
  }

  static String get _resolvedHost {
    final hostOverride = _hostOverride.trim();
    if (_isUsableOverride(hostOverride)) {
      return hostOverride;
    }

    if (kIsWeb) {
      final currentHost = Uri.base.host.trim();
      if (currentHost.isNotEmpty) {
        return currentHost;
      }
    }

    if (Platform.isAndroid) {
      return _defaultAndroidEmulatorHost;
    }

    return _defaultLocalHost;
  }

  static String get _resolvedPort {
    final portOverride = _portOverride.trim();
    if (portOverride.isNotEmpty) {
      return portOverride;
    }

    return _defaultPort;
  }

  static String _normalizeBaseUrl(String url) {
    var normalized = url.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!normalized.endsWith('/api')) {
      normalized = '$normalized/api';
    }
    return normalized;
  }

  static bool _isUsableOverride(String value) {
    if (value.isEmpty) {
      return false;
    }

    final normalized = value.toLowerCase();
    return !normalized.contains('your_current_wifi_ip');
  }
}
