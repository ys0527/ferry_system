import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';

class TicketQrCard extends StatefulWidget {
  const TicketQrCard({
    required this.route,
    required this.subtitle,
    required this.reference,
    required this.fare,
    this.completed = false,
    super.key,
  });

  final String route;
  final String subtitle;
  final String reference;
  final double fare;
  final bool completed;

  @override
  State<TicketQrCard> createState() => _TicketQrCardState();
}

class _TicketQrCardState extends State<TicketQrCard> {
  static const _navy = Color(0xFF3472CA);
  static const _teal = Color(0xFF1E93B8);

  final _passKey = GlobalKey();

  bool _sharing = false;

  Future<void> _applyBrightness(double? value) async {
    try {
      if (value == null) {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      } else {
        await ScreenBrightness.instance.setApplicationScreenBrightness(value);
      }
    } catch (e) {
      return;
    }
  }

  Future<void> _openEnlarged() async {
    await _applyBrightness(1.0);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _EnlargedQr(
        route: widget.route,
        subtitle: widget.subtitle,
        reference: widget.reference,
        moduleColor: widget.completed ? Colors.blueGrey.shade600 : _navy,
      ),
    );
    await _applyBrightness(null);
  }

  Future<void> _shareTicket() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _passKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('the pass has not been laid out yet');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png == null) {
        throw StateError('the pass could not be encoded');
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
              mimeType: 'image/png',
            ),
          ],
          fileNameOverrides: ['ticket_${widget.reference}.png'],
          subject: 'Penang Ferry ticket ${widget.reference}',
          text:
              'Penang Ferry ticket ${widget.reference} — '
              '${widget.route}, ${widget.subtitle}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share this ticket.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.completed ? Colors.blueGrey.shade300 : _teal;
    final codeColor = widget.completed ? Colors.blueGrey.shade600 : _navy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(key: _passKey, child: _buildPass(accent, codeColor)),
        TextButton.icon(
          onPressed: _sharing ? null : _shareTicket,
          icon: _sharing
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: codeColor,
                  ),
                )
              : Icon(Icons.share, size: 16, color: codeColor),
          label: Text(
            _sharing ? 'Preparing…' : 'Share ticket',
            style: TextStyle(
              fontSize: 12,
              color: codeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPass(Color accent, Color codeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            widget.route,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _openEnlarged,
            child: Container(
              width: 160,
              height: 160,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: QrImageView(
                data: widget.reference,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: codeColor,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: codeColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap the code to enlarge',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(
            widget.reference,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'RM ${widget.fare.toStringAsFixed(2)} · ${widget.completed ? 'Trip completed' : 'Paid'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnlargedQr extends StatelessWidget {
  const _EnlargedQr({
    required this.route,
    required this.subtitle,
    required this.reference,
    required this.moduleColor,
  });

  static const _navy = Color(0xFF3472CA);

  final String route;
  final String subtitle;
  final String reference;
  final Color moduleColor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final side = min(media.width - 96, media.height * 0.5);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                route,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: side,
                height: side,
                child: QrImageView(
                  data: reference,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: moduleColor,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: moduleColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                reference,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tap anywhere to close',
                style: TextStyle(color: Colors.black38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
