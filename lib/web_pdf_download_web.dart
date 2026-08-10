import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

Future<void> savePdfBytes(Uint8List bytes, String fileName) async {
  final encoded = base64Encode(bytes);
  final anchor =
      html.AnchorElement(href: 'data:application/pdf;base64,$encoded')
        ..style.display = 'none'
        ..download = fileName;

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}
