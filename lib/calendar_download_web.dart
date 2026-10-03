// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

bool get calendarDownloadSupported => true;

void downloadCalendarFile(String contents) {
  final blob = html.Blob([contents], 'text/calendar;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final link = html.AnchorElement(href: url)
    ..download = 'ember-reminder.ics'
    ..style.display = 'none';
  try {
    html.document.body!.append(link);
    link.click();
  } finally {
    link.remove();
    Timer(const Duration(seconds: 60), () => html.Url.revokeObjectUrl(url));
  }
}
