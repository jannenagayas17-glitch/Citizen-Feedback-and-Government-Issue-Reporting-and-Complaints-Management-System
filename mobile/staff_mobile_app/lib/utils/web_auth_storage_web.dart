// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<void> clearWebAuthStorage(Iterable<String> keys) async {
  for (final key in keys) {
    html.window.localStorage.remove(key);
    html.window.sessionStorage.remove(key);
  }
}
