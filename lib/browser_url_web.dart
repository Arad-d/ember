// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Uri currentBrowserUri() => Uri.base;

void clearBrowserFragment() {
  final clean = Uri.base.replace(fragment: '').toString();
  html.window.history.replaceState(null, '', clean);
}
