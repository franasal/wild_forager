import 'dart:io';
import 'dart:typed_data';

Future<void> writeBytes(String path, Uint8List bytes) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
  await file.writeAsBytes(bytes, flush: true);
}

