import 'package:flutter/material.dart';

class CrowdDensityBadge extends StatelessWidget {
  const CrowdDensityBadge({required this.level, super.key});

  final String level;

  static const _levelGreen = Color(0xFF3CAE6A);
  static const _levelAmber = Color(0xFFE3A72E);
  static const _levelRed = Color(0xFFE0483C);

  Color get _color {
    switch (level) {
      case 'Low':
        return _levelGreen;
      case 'Moderate':
        return _levelAmber;
      default:
        return _levelRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt, color: Colors.white, size: 11),
          const SizedBox(width: 4),
          Text(
            level,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}