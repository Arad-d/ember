import 'dart:typed_data';

bool get exportDownloadSupported => false;
Future<void> downloadExportFile(
  Uint8List bytes,
  String mime,
  String filename,
) async {
  throw UnsupportedError('Open Ember in your browser to export files.');
}
