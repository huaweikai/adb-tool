import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../i18n.dart';

class WatermarkOpts {
  final bool addTimestamp;
  final int? stepNumber;
  final bool skipEdit;
  const WatermarkOpts({
    required this.addTimestamp,
    this.stepNumber,
    this.skipEdit = false,
  });
}

Future<WatermarkOpts?> showWatermarkDialog(BuildContext context) {
  var addTimestamp = true;
  var addStep = false;
  final stepCtrl = TextEditingController();

  return showDialog<WatermarkOpts>(
    context: context,
    builder: (ctx) {
      return _SafeDialog(
        controllers: [stepCtrl],
        builder: (_) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            scrollable: true,
            title: Text(tr('watermarkOptions')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: addTimestamp,
                  onChanged: (v) =>
                      setDialogState(() => addTimestamp = v ?? true),
                  title: Text(tr('addTimestamp'),
                      style: const TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                CheckboxListTile(
                  value: addStep,
                  onChanged: (v) => setDialogState(() => addStep = v ?? true),
                  title: Text(tr('addStepNumber'),
                      style: const TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                if (addStep)
                  Padding(
                    padding: const EdgeInsets.only(left: 48, right: 16),
                    child: TextField(
                      controller: stepCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: tr('stepNumberHint'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final step = int.tryParse(stepCtrl.text.trim());
                  Navigator.pop(
                      ctx,
                      WatermarkOpts(
                        addTimestamp: addTimestamp,
                        stepNumber: addStep && step != null ? step.abs() : null,
                      ));
                },
                child: Text(tr('edit')),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  final step = int.tryParse(stepCtrl.text.trim());
                  Navigator.pop(
                      ctx,
                      WatermarkOpts(
                        addTimestamp: addTimestamp,
                        stepNumber: addStep && step != null ? step.abs() : null,
                        skipEdit: true,
                      ));
                },
                icon: const Icon(Icons.save, size: 16),
                label: Text(tr('quickSave')),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SafeDialog extends StatefulWidget {
  final List<TextEditingController> controllers;
  final Widget Function(List<TextEditingController> ctrls) builder;

  const _SafeDialog({required this.controllers, required this.builder});

  @override
  State<_SafeDialog> createState() => _SafeDialogState();
}

class _SafeDialogState extends State<_SafeDialog> {
  @override
  void dispose() {
    for (final c in widget.controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(widget.controllers);
}

Future<Uint8List> addTimestampWatermark(Uint8List imageBytes) async {
  final now = DateTime.now();
  final text =
      '${now.year}-${_pad(now.month)}-${_pad(now.day)} ${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
  return _drawOverlay(imageBytes, text, Alignment.bottomRight, null);
}

Future<Uint8List> addStepNumber(Uint8List imageBytes, int step) async {
  return _drawOverlay(imageBytes, '$step', Alignment.topRight, step);
}

String _pad(int n) => n.toString().padLeft(2, '0');

Future<Uint8List> _drawOverlay(
  Uint8List imageBytes,
  String text,
  Alignment alignment,
  int? stepNumber,
) async {
  final original = await decodeImageFromList(imageBytes);
  final width = original.width.toDouble();
  final height = original.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
  canvas.drawImage(original, Offset.zero, Paint());

  final padding = width * 0.03;
  final fontSize = width * 0.035;

  double x, y;
  if (alignment == Alignment.bottomRight) {
    x = width - padding;
    y = height - padding;
  } else {
    x = padding;
    y = padding + fontSize + padding;
  }

  if (stepNumber != null) {
    final radius = fontSize * 1.2;
    const bgColor = Color(0xCCFF4444);
    final circlePaint = Paint()..color = bgColor;
    canvas.drawCircle(Offset(x + radius, y - radius), radius, circlePaint);

    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: fontSize,
      textDirection: ui.TextDirection.ltr,
    ))
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFFFFFFFF),
        fontWeight: ui.FontWeight.w700,
        fontSize: fontSize,
      ))
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: radius * 2));
    canvas.drawParagraph(
      paragraph,
      Offset(
          x + radius - paragraph.width / 2, y - radius - paragraph.height / 2),
    );
  } else {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: 'Menlo',
          background: Paint()..color = const Color(0x88000000),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout(maxWidth: width * 0.6);
    textPainter.paint(
        canvas, Offset(x - textPainter.width, y - textPainter.height));
  }

  final picture = recorder.endRecording();
  final img = await picture.toImage(original.width, original.height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  original.dispose();
  img.dispose();
  return byteData!.buffer.asUint8List();
}
