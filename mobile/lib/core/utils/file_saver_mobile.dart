import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndShareFile(List<int> bytes, String filename) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      text: 'Exported $filename',
    ),
  );
}

void printPage() {
  // Print not supported directly on mobile without printing packages.
}
