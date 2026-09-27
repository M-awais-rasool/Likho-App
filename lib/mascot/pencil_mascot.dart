import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'mascot_controller.dart';
import 'mascot_painter.dart';
import 'rig/part_library.dart';
import 'rig/pencil_rig.dart';

/// The Pencil mascot. Usable on any screen:
///
/// ```dart
/// PencilMascot(controller: controller, size: 240)
/// ```
///
/// [size] is the height of the standing character in logical pixels; the
/// width follows the artboard ratio (500:680). Jumps, raised arms, hats and
/// "zzz" may paint outside this box, so give it some room.
class PencilMascot extends StatefulWidget {
  const PencilMascot({super.key, required this.controller, this.size = 240});

  final MascotController controller;
  final double size;

  static double widthFor(double height) => height * PencilRig.artboard.width / PencilRig.artboard.height;

  @override
  State<PencilMascot> createState() => _PencilMascotState();
}

class _PencilMascotState extends State<PencilMascot> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  MascotParts? _parts;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => widget.controller.advance(elapsed))..start();
    widget.controller.attachView(_globalToArtboard);
    _parts = MascotParts.cached;
    if (_parts == null) {
      MascotParts.load().then((p) {
        if (mounted) setState(() => _parts = p);
      });
    }
  }

  @override
  void didUpdateWidget(PencilMascot old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.detachView(_globalToArtboard);
      widget.controller.attachView(_globalToArtboard);
    }
  }

  Offset _globalToArtboard(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    return box.globalToLocal(global) * (PencilRig.artboard.height / widget.size);
  }

  @override
  void dispose() {
    widget.controller.detachView(_globalToArtboard);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts;
    return SizedBox(
      width: PencilMascot.widthFor(widget.size),
      height: widget.size,
      child: parts == null
          ? null
          : RepaintBoundary(
              child: CustomPaint(
                painter: MascotPainter(controller: widget.controller, parts: parts),
                isComplex: true,
                willChange: true,
              ),
            ),
    );
  }
}
