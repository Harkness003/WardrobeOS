import 'dart:io';
import 'package:flutter/material.dart';

class GarmentImage extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  const GarmentImage({super.key, this.imagePath, this.width, this.height, this.borderRadius = const BorderRadius.all(Radius.circular(18))});

  @override
  Widget build(BuildContext context) {
    final exists = imagePath != null && imagePath!.isNotEmpty && File(imagePath!).existsSync();
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFFE7E1D7),
        child: exists
          ? Image.file(File(imagePath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _Fallback())
          : const _Fallback(),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback();
  @override
  Widget build(BuildContext context) => const Center(child: Icon(Icons.checkroom, size: 58, color: Color(0xFF8D7B65)));
}
