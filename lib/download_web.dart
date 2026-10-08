import 'dart:convert' show Utf8Codec;

import 'package:web/web.dart' as web;

const bool canDownloadFile = true;

/// Makes the browser save [content] as a file named [filename].
void downloadTextFile(String filename, String content) {
  final url = Uri.dataFromString(content,
          mimeType: 'application/json', encoding: const Utf8Codec())
      .toString();
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
}
