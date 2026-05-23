// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void downloadFileOnWeb(String url, String fileName) {
  final xhr = html.HttpRequest();
  xhr.open('GET', url);
  xhr.responseType = 'blob';
  xhr.onLoad.listen((_) {
    final blob = xhr.response as html.Blob;
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: blobUrl)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(blobUrl);
  });
  xhr.send();
}
