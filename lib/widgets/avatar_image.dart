import 'dart:convert';
import 'package:flutter/material.dart';

class AvatarImage extends StatelessWidget {
  final String? photoUrl;
  final double width;
  final double height;
  final BoxFit fit;

  const AvatarImage({
    super.key,
    required this.photoUrl,
    this.width = 40,
    this.height = 40,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return SizedBox(width: width, height: height);
    }

    // Since we migrated to Cloudinary, all valid URLs should be HTTP
    return Image.network(
      photoUrl!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => SizedBox(width: width, height: height),
    );
  }
}
