import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create review sheets from existing captures', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = FontLoader('ReviewFont')
      ..addFont(
        File('C:/Windows/Fonts/arial.ttf')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)),
      );
    await font.load();
    const root = String.fromEnvironment(
      'REVIEW_ROOT',
      defaultValue: 'build/responsive',
    );
    const defaultFolders = [
      '320x480',
      '480x320',
      'estados',
      'accesibilidad',
      'matrix/768x1024',
      'matrix/1024x768',
      'matrix/1366x768',
      'matrix/1920x1080',
      'matrix/3840x2160',
      'matrix/280x653',
      'matrix/600x800',
      'matrix/800x600',
      'matrix/2560x1440',
      'matrix/5120x1440',
      'contenido_largo',
      'largo200',
      'errores',
      'vacios',
      'fotos',
      'texto150_recorte',
      'texto200_tablet',
    ];
    final folders = const bool.fromEnvironment('REVIEW_DISCOVER')
        ? Directory(root)
              .listSync()
              .whereType<Directory>()
              .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
              .toList()
        : defaultFolders;
    for (final folder in folders) {
      final directory = Directory('$root/$folder');
      if (!directory.existsSync()) continue;
      final files =
          directory
              .listSync()
              .whereType<File>()
              .where(
                (f) =>
                    RegExp(r'[/\\]\d\d_[^/\\]+\.png$').hasMatch(f.path) &&
                    !f.path.contains('_scroll') &&
                    !f.path.contains('_abajo'),
              )
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (var page = 0; page * 24 < files.length; page++) {
        final batch = files.skip(page * 24).take(24).toList();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final height = ((batch.length + 5) ~/ 6) * 330;
        canvas.drawRect(
          Rect.fromLTWH(0, 0, 1440, height.toDouble()),
          Paint()..color = Colors.white,
        );
        for (var index = 0; index < batch.length; index++) {
          final codec = await ui.instantiateImageCodec(
            await batch[index].readAsBytes(),
          );
          final frame = await codec.getNextFrame();
          final image = frame.image;
          final x = (index % 6) * 240.0;
          final y = (index ~/ 6) * 330.0;
          final fitted = applyBoxFit(
            BoxFit.contain,
            Size(image.width.toDouble(), image.height.toDouble()),
            const Size(228, 294),
          );
          final target = Alignment.center.inscribe(
            fitted.destination,
            Rect.fromLTWH(x + 6, y + 30, 228, 294),
          );
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            target,
            Paint(),
          );
          final painter = TextPainter(
            text: TextSpan(
              text: batch[index].uri.pathSegments.last.replaceAll('.png', ''),
              style: const TextStyle(
                fontFamily: 'ReviewFont',
                fontSize: 11,
                color: Colors.black,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: 228);
          painter.paint(canvas, Offset(x + 6, y + 5));
          image.dispose();
          codec.dispose();
        }
        final picture = recorder.endRecording();
        final mosaic = await picture.toImage(1440, height);
        final bytes = await mosaic.toByteData(format: ui.ImageByteFormat.png);
        await File('${directory.path}/review_$page.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        mosaic.dispose();
        picture.dispose();
      }
    }
  });
}
