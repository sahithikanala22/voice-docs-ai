import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Run with: flutter test scripts/render_store_artwork.dart
/// Produces opaque, RGB PNGs at the exact Play listing dimensions.
void main() {
  testWidgets('render Play listing artwork', (tester) async {
    await tester.runAsync(() async {
      final configFile = File('.dart_tool/package_config.json');
      final config = jsonDecode(await configFile.readAsString()) as Map;
      final flutterPackage = (config['packages'] as List)
          .cast<Map>()
          .firstWhere((package) => package['name'] == 'flutter');
      final flutterRoot =
          Platform.environment['FLUTTER_ROOT'] ??
          Directory.fromUri(
            configFile.absolute.uri.resolve(
              flutterPackage['rootUri'] as String,
            ),
          ).parent.parent.path;
      final font = FontLoader('StoreSans');
      font.addFont(
        File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
      await font.load();
      final codec = await ui.instantiateImageCodec(
        await File('assets/icon/icon.png').readAsBytes(),
      );
      final logo = (await codec.getNextFrame()).image;
      try {
        final output = Directory('release/generated');
        await output.create(recursive: true);
        await _render('${output.path}/play-icon-512.png', 512, 512, (canvas) {
          canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
          canvas.drawImageRect(
            logo,
            ui.Rect.fromLTWH(
              0,
              0,
              logo.width.toDouble(),
              logo.height.toDouble(),
            ),
            const ui.Rect.fromLTWH(0, 0, 512, 512),
            ui.Paint()..filterQuality = ui.FilterQuality.high,
          );
        });
        await _render(
          '${output.path}/feature-graphic-1024x500.png',
          1024,
          500,
          (canvas) {
            canvas.drawRect(
              const ui.Rect.fromLTWH(0, 0, 1024, 500),
              ui.Paint()
                ..shader = ui.Gradient.linear(
                  ui.Offset.zero,
                  const ui.Offset(1024, 500),
                  [const ui.Color(0xff10172d), const ui.Color(0xff30234f)],
                ),
            );
            canvas.drawCircle(
              const ui.Offset(935, 52),
              220,
              ui.Paint()..color = const ui.Color(0x224fdaed),
            );
            canvas.drawCircle(
              const ui.Offset(800, 440),
              230,
              ui.Paint()..color = const ui.Color(0x226f64e7),
            );
            canvas.drawRRect(
              ui.RRect.fromRectAndRadius(
                const ui.Rect.fromLTWH(58, 52, 64, 64),
                const ui.Radius.circular(16),
              ),
              ui.Paint()..color = const ui.Color(0xffffffff),
            );
            canvas.drawImageRect(
              logo,
              ui.Rect.fromLTWH(
                0,
                0,
                logo.width.toDouble(),
                logo.height.toDouble(),
              ),
              const ui.Rect.fromLTWH(62, 56, 56, 56),
              ui.Paint()..filterQuality = ui.FilterQuality.high,
            );
            _text(
              canvas,
              'Voice Docs AI',
              const ui.Offset(140, 69),
              28,
              const ui.Color(0xfff6f5ff),
            );
            _text(
              canvas,
              'Your thoughts,\nbeautifully kept.',
              const ui.Offset(58, 169),
              53,
              const ui.Color(0xfff6f5ff),
              width: 600,
            );
            _text(
              canvas,
              'Voice notes · Diary · Calendar · Tasks',
              const ui.Offset(60, 363),
              23,
              const ui.Color(0xffc1c7e0),
              width: 620,
            );
            canvas.drawRRect(
              ui.RRect.fromRectAndRadius(
                const ui.Rect.fromLTWH(716, 139, 230, 240),
                const ui.Radius.circular(32),
              ),
              ui.Paint()..color = const ui.Color(0xfff4f1ff),
            );
            for (var i = 0; i < 13; i++) {
              final heights = <double>[
                18.0,
                32,
                51,
                76,
                103,
                66,
                128,
                80,
                111,
                66,
                47,
                29,
                17,
              ];
              final h = heights[i];
              canvas.drawRRect(
                ui.RRect.fromRectAndRadius(
                  ui.Rect.fromLTWH(748 + i * 13, 251 - h / 2, 7, h),
                  const ui.Radius.circular(4),
                ),
                ui.Paint()
                  ..color = i.isEven
                      ? const ui.Color(0xff6d5cbd)
                      : const ui.Color(0xff2a99b0),
              );
            }
            _text(
              canvas,
              'A moment, saved.',
              const ui.Offset(750, 332),
              20,
              const ui.Color(0xff37314c),
            );
          },
        );
      } finally {
        logo.dispose();
        codec.dispose();
      }
    });
  });
}

void _text(
  ui.Canvas canvas,
  String text,
  ui.Offset offset,
  double size,
  ui.Color color, {
  double width = 800,
}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'StoreSans',
            fontSize: size,
            height: 1.12,
          ),
        )
        ..pushStyle(ui.TextStyle(color: color))
        ..addText(text);
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: width));
  canvas.drawParagraph(paragraph, offset);
  paragraph.dispose();
}

Future<void> _render(
  String path,
  int width,
  int height,
  void Function(ui.Canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    await File(
      path,
    ).writeAsBytes(_rgbPng(rgba!.buffer.asUint8List(), width, height));
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Uint8List _rgbPng(Uint8List rgba, int width, int height) {
  final scanlines = BytesBuilder();
  for (var y = 0; y < height; y++) {
    scanlines.addByte(0);
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      scanlines.add([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  final output = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> payload) {
    final data = Uint8List.fromList([...type.codeUnits, ...payload]);
    final header = ByteData(4)..setUint32(0, payload.length);
    var crc = 0xffffffff;
    for (final byte in data) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
      }
    }
    final tail = ByteData(4)..setUint32(0, (crc ^ 0xffffffff) & 0xffffffff);
    output
      ..add(header.buffer.asUint8List())
      ..add(data)
      ..add(tail.buffer.asUint8List());
  }

  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', ZLibCodec().encode(scanlines.takeBytes()));
  chunk('IEND', []);
  return output.takeBytes();
}
