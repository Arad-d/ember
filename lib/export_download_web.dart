// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

bool get exportDownloadSupported => true;
Future<void> downloadExportFile(
  Uint8List bytes,
  String mime,
  String filename,
) async {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final link = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  try {
    html.document.body!.append(link);
    link.click();
  } finally {
    link.remove();
    Timer(const Duration(seconds: 60), () => html.Url.revokeObjectUrl(url));
  }
}
