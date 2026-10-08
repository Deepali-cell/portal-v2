import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes a downloaded file into the app's temp folder and returns its path.
///
/// [name] comes from the server, so only its last path segment is used: a
/// name like `../../shared_prefs/x.xml` must not write outside the temp
/// folder. Files are written to a fresh sub-folder per call, so two downloads
/// with the same name never overwrite each other.
Future<String> writeTempFile(String name, List<int> bytes) async {
  var safe = name.split(RegExp(r'[/\\]')).last.trim();
  safe = safe.replaceFirst(RegExp(r'^\.+'), '');
  if (safe.isEmpty) safe = 'download';

  final tmp = await getTemporaryDirectory();
  final dir = await Directory('${tmp.path}/downloads').createTemp();
  final file = File('${dir.path}/$safe');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Deletes every file [writeTempFile] has written. Called on sign-out so a
/// payslip or receipt never outlives the session that opened it.
Future<void> clearTempFiles() async {
  try {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/downloads');
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {/* best effort */}
}
