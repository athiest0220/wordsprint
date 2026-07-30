import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Captures the widget behind [boundaryKey] to a PNG and opens the share sheet.
///
/// Writes to a UNIQUE filename each call: reusing one fixed path made Android
/// messaging apps cache the attachment by its (unchanging) URI and re-serve a
/// stale card from a previous share. A fresh name = fresh URI. Old result
/// images are swept first so temp doesn't accumulate. Falls back to
/// [fallbackText] if the image capture fails.
Future<void> shareCapturedCard({
  required GlobalKey boundaryKey,
  Rect? origin,
  required String fallbackText,
}) async {
  try {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    try {
      for (final f in dir.listSync()) {
        if (f is File && f.path.contains('word_sprint_result')) {
          f.deleteSync();
        }
      }
    } catch (_) {}
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = await File('${dir.path}/word_sprint_result_$stamp.png')
        .writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  } catch (_) {
    await Share.share(fallbackText, sharePositionOrigin: origin);
  }
}
